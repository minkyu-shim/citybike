# CityBike DevOps Lab: Starter Repository

This repository provides the baseline for the CityBike SDLC and DevOps lab. It contains a Node.js application designed to force students to resolve real-world deployment friction: runtime crashes, broken layer caching, image bloat, and pipeline security vulnerabilities.

## Directory Structure

```text
citybike-devops-lab/
├── package.json              # CommonJS setup with 10 heavy devDependencies
├── package-lock.json         # Locked dependency tree for deterministic npm ci
├── server.js                 # Contains Node 17+ structuredClone code & telemetry
├── .gitignore                # Excludes node_modules/ and dist/
├── public/
│   ├── index.html            # Static UI entry
│   ├── app.js                # Frontend reservation logic
│   └── styles.css            # Stylesheet asset
└── scripts/
    ├── build-manifest.js     # Generates dist/build-manifest.json
    ├── test-staging.sh       # Gate 1: API contract & build manifest audit
    ├── test-uat.sh           # Gate 2: Static assets, business rules, & 4-station count
    ├── test-oat.sh           # Gate 3: Payload limits, burst loads, & SIGTERM handling
    ├── test-preprod.sh       # Gate 4: Image size (<220MB), no node_modules, & preprod config
    └── test-prod.sh          # Gate 5: Production deployment & PROD_API_KEY security check
```

> **Note:** `Dockerfile`, `.dockerignore`, `.github/workflows/sdlc.yml`, and `scripts/pipeline.sh` are intentionally omitted. Students author them.

## Mission Roadmap

### Mission 0: Setup & Baseline

Students clone the repository (`-o ogn`), link it to a local bare git repo (`~/lab/remote.git`), run `npm install` and `npm run build`, and verify baseline application functionality.

### Mission 1: The Crash

Students run the application inside a legacy `node:16` container and observe an immediate startup failure caused by `structuredClone()`, contrasting it with a working `node:20` environment.

### Mission 2: Naive Dockerization

Students author an unoptimized single-stage Dockerfile (`COPY . .` before `npm ci`, no `.dockerignore`), producing a 1.2+ GB image and experiencing severe cache-invalidation latency on minor code edits.

### Mission 3: Build Latency & Bloat Audit

Students reorder Dockerfile layers to enforce caching (`COPY package*.json ./` followed by `npm ci`), test the `--omit=dev` build failure trap, and implement a true multi-stage build (`node:20` builder stage to `node:20-alpine` runtime stage) to drop the image size below 220MB and purge `node_modules`. They tag and push version `v1`.

### Mission 4: CI/CD Deployment Gates

Students author an orchestrator (`.github/workflows/sdlc.yml` for GitHub Actions or `scripts/pipeline.sh` locally) that manages the container lifecycle (`docker run`, health-check polling, and teardown) while executing the five passive `scripts/test-*.sh` gate scripts sequentially.

### Mission 5: Bad Push Detection & Rollback

Students introduce a breaking code change (`v2` missing `DB_URL`), manually deploy it to production to cause an outage, execute an operational rollback to `v1`, and prove that the automated CI/CD pipeline catches the crash at the Staging gate before production deployment.

### Mission 6: Deliverables & Exit Ticket

Students compile terminal outputs, image size/time metrics, CI/CD pipeline execution evidence, and answer technical reflection questions.

