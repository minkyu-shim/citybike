#!/usr/bin/env bash
set -euo pipefail
TARGET_URL="${TARGET_URL:-http://localhost:4173}"

echo "[STAGING] Verifying /health and build manifest..."
HEALTH=$(curl -sf "${TARGET_URL}/health")
echo "Health payload: ${HEALTH}"

echo "${HEALTH}" | grep -q '"ok":true' || { echo "FAIL: Service not healthy"; exit 1; }
echo "${HEALTH}" | grep -q '"hasBuildManifest":true' || { echo "FAIL: Missing dist/build-manifest.json (Did you run npm run build in the Builder stage?)"; exit 1; }

echo "[STAGING] Verifying /api/stations contract..."
STATIONS=$(curl -sf "${TARGET_URL}/api/stations")
echo "${STATIONS}" | grep -q '"id":"central"' || { echo "FAIL: Missing station data"; exit 1; }
echo "[STAGING] PASSED."