#!/usr/bin/env bash
set -euo pipefail
TARGET_URL="${TARGET_URL:-http://localhost:4173}"

echo "[OAT] Testing malformed JSON handling (expect HTTP 400)..."
BAD_JSON=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${TARGET_URL}/api/reservations" \
  -H "Content-Type: application/json" -d '{bad_json')
[ "${BAD_JSON}" -eq 400 ] || { echo "FAIL: Expected 400 on invalid JSON, got ${BAD_JSON}"; exit 1; }

echo "[OAT] Testing >10KB payload flood guard..."
LARGE_PAYLOAD=$(head -c 12000 < /dev/zero | tr '\0' 'A')
FLOOD_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${TARGET_URL}/api/reservations" \
  -H "Content-Type: application/json" -d "{\"data\":\"${LARGE_PAYLOAD}\"}" || true)
if [ "${FLOOD_CODE}" -ne 413 ] && [ "${FLOOD_CODE}" -ne 000 ]; then
  echo "FAIL: Expected stream termination (413/000), got ${FLOOD_CODE}"
  exit 1
fi

echo "[OAT] Running 50-request burst load test..."
for i in $(seq 1 50); do
  curl -sf "${TARGET_URL}/health" > /dev/null &
done
wait
echo "[OAT] PASSED."