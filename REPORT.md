# Lab 04 - CityBike report

Setup: MacBook (arm64), Docker 29.9.2, Node 24 on the host.

## Mission 0 - Baseline

- `node_modules` after `npm ci`: 143M
- devDependencies: @babel/core, eslint, jest, nodemon, prettier, sass, ts-node, typescript, webpack, webpack-cli

```
$ curl localhost:4173/health
{"ok":true,"environment":"development","hasBuildManifest":true,"secureKeyConfigured":false}
```

After adding `structuredClone(stations)`, `/api/stations` still returns the 4 stations on my machine. Committed as `v1: station snapshot`.

## Mission 1 - The crash

Ran the clean clone from `remote.git` in two containers.

node:16:
```
/app/server.js:21
const stationsSnapshot = structuredClone(stations);
                         ^

ReferenceError: structuredClone is not defined
    at Object.<anonymous> (/app/server.js:21:26)
```

node:20:
```
CityBike service listening on http://0.0.0.0:4173 [env=development]
```

I also noticed `hasBuildManifest` was false on the QA clone, because `dist/` is in `.gitignore` and nobody built it there.

**A)** The code depends on the Node version of whoever runs it. `structuredClone` only exists from Node 17, and nothing in the repo says which version is required.

**B)** Other things that differ between machines: OS/CPU architecture (native modules built on a Mac won't run on Linux), environment variables and secrets, and local state like an old `node_modules` or untracked build files.

**C)** The Build stage, or Staging at the latest. Build in a container with a fixed runtime (`FROM node:20`) and run a quick smoke test on it before promoting anything.

## Mission 2 - Naive Dockerfile

`FROM node:20`, `COPY . .`, `npm ci`, `npm run build`, no `.dockerignore`.

| First build | Rebuild after 1-line change in public/ | Image size |
|---|---|---|
| 16.3 s | 10.9 s (npm ci ran again) | 2.02 GB |

**A)** `COPY . .` copies everything, so changing any file breaks the cache for that layer and every layer after it, including `npm ci`.

**B)** The `node:20` base image (~1.6 GB, full Debian with build tools), the `npm ci` layer with all the devDependencies (205 MB), and the `COPY . .` layer (157 MB), which includes my local `node_modules` even though `npm ci` replaces it.

**C)** `node_modules` (built on macOS), `.git`, `dist`, `REPORT.md`, `README.md` and the `Dockerfile`. A `.env` file would have been copied too if I had one.

## Mission 3 - Cache fix and multi-stage

**Step 1.** Copy `package.json` + `package-lock.json`, run `npm ci`, then copy the rest. Also added a `.dockerignore` (node_modules, dist, .git, .env, docs...). Now the rebuild after a CSS change takes 0.6 s because `npm ci` comes from the cache.

**Step 2.** With `npm ci --omit=dev`:
```
BUILD ERROR: Necessary devDependencies missing. Run npm run build in the builder stage.
ERROR: failed to build: failed to solve: process "/bin/sh -c npm run build" did not complete successfully: exit code: 1
```
`npm run build` requires `typescript` (a devDependency) to generate `dist/build-manifest.json`. It's only needed at build time; the server itself only uses Node built-ins. So the devDependencies have to be there during the build but not in the final image.

**Step 3.** Build stage on `node:20`, run stage on `node:20-alpine` with only `server.js`, `public/` and `dist/build-manifest.json`, running as user `node`.

```
$ docker run --rm citybike:v1 ls node_modules
ls: node_modules: No such file or directory

$ curl localhost:4173/health
{"ok":true,"environment":"development","hasBuildManifest":true,"secureKeyConfigured":false}
```

| Version | Image size | Rebuild after 1-line change |
|---|---|---|
| Naive | 2.02 GB | 10.9 s |
| Cache-fixed | 1.84 GB | 0.6 s |
| Multi-stage | 194 MB | 0.5 s |

**A)** Docker reuses a layer only if it and all the layers before it are unchanged. If only the package files are copied before `npm ci`, that step only re-runs when the dependencies change.

**B)** That's all the server uses at runtime: it serves `public/` and checks that the manifest file exists. `hasBuildManifest` is still true because the manifest was generated in the build stage and copied over.

**C)** Security: far fewer packages and tools in the image that could have vulnerabilities, and it doesn't run as root. Ops: the image is 10x smaller, so pulls, deploys and rollbacks are faster.

## Mission 4 - Five gates

I did both paths: `scripts/pipeline.sh` (local) and `.github/workflows/sdlc.yml` (GitHub Actions). Each gate starts the container, polls `/health` for up to 30 s (and fails straight away if the container exits), runs the test script and removes the container. Gates use port 4174; prod runs as `citybike-prod` on 4173 and stays up.

Local run on v1 (`./scripts/pipeline.sh citybike:v1`):
```
===== GATE: staging (citybike:v1) =====
Health payload: {"ok":true,"environment":"staging","hasBuildManifest":true,"secureKeyConfigured":false}
[STAGING] PASSED.
===== GATE: uat (citybike:v1) =====
[UAT] PASSED.
===== GATE: oat (citybike:v1) =====
[OAT] PASSED.
===== GATE: preprod (citybike:v1) =====
[PRE-PROD] PASSED.
===== GATE: prod (citybike:v1) =====
[PROD] Production verification PASSED.
===== ALL 5 GATES PASSED: citybike:v1 is live as citybike-prod on :4173 =====

$ curl localhost:4173/health
{"ok":true,"environment":"production","hasBuildManifest":true,"secureKeyConfigured":true}
```

GitHub Actions run: TODO (PR link + screenshot)

**A)** Each gate builds on the one before it. There's no point load-testing something that doesn't even start. Stopping at the first failure means a broken build never reaches prod.

**B)**
- Staging: the app starts and the API works.
- UAT: the business rules are correct (stations, valid and invalid reservations).
- OAT: it holds up operationally (bad input, large payloads, bursts of requests).
- Preprod: the image itself (size, no devDependencies) plus the real prod config.
- Prod: the deployed instance really uses production settings and the real key.

**C)** If you rebuild for each environment, you aren't testing the thing you ship: the dependencies or the base image could change between builds. Building once means the exact image that passed the tests is the one that goes to prod.

**D)** `server.js` falls back to `DEV_LOCAL_INSECURE_KEY` when `PROD_API_KEY` isn't set, so the app starts and looks healthy even with no key. Only preprod and prod check `secureKeyConfigured`. Without the key, the prod gate fails:
```
FAIL: Production container is still using the insecure fallback key! Inject PROD_API_KEY from GitHub Secrets.
```
