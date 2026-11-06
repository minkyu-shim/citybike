#!/usr/bin/env bash
set -euo pipefail
TARGET_URL="${TARGET_URL:-http://localhost:4173}"

echo "[PROD] Running post-deployment production smoke & secret verification..."
HEALTH=$(curl -sf "${TARGET_URL}/health")

echo "${HEALTH}" | grep -q '"environment":"production"' || {
  echo "FAIL: APP_ENV is not set to 'production'"
  exit 1
}

echo "${HEALTH}" | grep -q '"secureKeyConfigured":true' || {
  echo "FAIL: Production container is still using the insecure fallback key! Inject PROD_API_KEY from GitHub Secrets."
  exit 1
}

echo "[PROD] Production verification PASSED."