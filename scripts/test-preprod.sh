#!/usr/bin/env bash
set -euo pipefail
IMAGE_NAME="${IMAGE_NAME:-citybike:latest}"
TARGET_URL="${TARGET_URL:-http://localhost:4173}"

echo "[PRE-PROD] Auditing Docker image size for ${IMAGE_NAME}..."
SIZE_BYTES=$(docker image inspect "${IMAGE_NAME}" --format='{{.Size}}')
MAX_BYTES=220000000 # ~220MB ceiling (Dev A's image is >1.2GB; node:20-alpine is ~135MB)
if [ "${SIZE_BYTES}" -gt "${MAX_BYTES}" ]; then
  echo "FAIL: Image size (${SIZE_BYTES} bytes) exceeds 220MB limit. Refactor Dockerfile into a multi-stage build."
  exit 1
fi

echo "[PRE-PROD] Verifying devDependencies (typescript) are excluded from runtime image..."
if docker run --rm "${IMAGE_NAME}" sh -c "test -d node_modules/typescript"; then
  echo "FAIL: devDependency 'typescript' found inside final runtime image!"
  exit 1
fi

echo "[PRE-PROD] Verifying environment promotion flag (APP_ENV=preprod) and PROD_API_KEY..."
HEALTH=$(curl -sf "${TARGET_URL}/health")
echo "${HEALTH}" | grep -q '"environment":"preprod"' || {
  echo "FAIL: Container not running with APP_ENV=preprod"
  exit 1
}
echo "${HEALTH}" | grep -q '"secureKeyConfigured":true' || {
  echo "FAIL: Preprod container is missing PROD_API_KEY (secureKeyConfigured is false)"
  exit 1
}
echo "[PRE-PROD] PASSED."


