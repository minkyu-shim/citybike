# Lab 04 — SDLC & Docker: Report (CityBike)

Host: macOS (Apple Silicon), Docker Engine 29.9.2, host Node v24.14.0.

---

## Mission 0 — Setup & baseline

- `node_modules` size after `npm ci`: **143M**
- devDependencies (10): `@babel/core`, `eslint`, `jest`, `nodemon`, `prettier`, `sass`, `ts-node`, `typescript`, `webpack`, `webpack-cli`

Baseline `curl localhost:4173/health`:

```json
{"ok":true,"environment":"development","hasBuildManifest":true,"secureKeyConfigured":false}
```

After the "works on my machine" change (`structuredClone(stations)`), `curl localhost:4173/api/stations` on the host (Node 24):

```json
{"stations":[{"id":"central","name":"Central Square","bikes":8,"docks":4},{"id":"riverside","name":"Riverside Park","bikes":0,"docks":12},{"id":"market","name":"Market Street","bikes":3,"docks":6},{"id":"campus","name":"Campus North","bikes":1,"docks":7}]}
```

4 stations returned → committed as `v1: station snapshot` and pushed to `ogn/main`.
