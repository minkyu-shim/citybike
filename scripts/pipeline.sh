#!/usr/bin/env bash
# Local promotion pipeline: runs the 5 gates in order against ONE image.
# Usage: ./scripts/pipeline.sh citybike:v1
set -euo pipefail

IMAGE="${1:?usage: $0 <image:tag>}"
PROD_API_KEY="${PROD_API_KEY:-lab-secret}"   # training-only value
GATE_PORT=4174
PROD_PORT=4173
SCRIPTS="$(cd "$(dirname "$0")" && pwd)"

docker image inspect "$IMAGE" >/dev/null || { echo "Image $IMAGE not found"; exit 1; }

# wait_healthy <container> <url>: poll /health with a 30s timeout
wait_healthy() {
  local name="$1" url="$2"
  for _ in $(seq 1 30); do
    if [ "$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null)" != "true" ]; then
      echo "FAIL: container $name exited during startup. Logs:"
      docker logs "$name" 2>&1 | tail -20
      return 1
    fi
    curl -sf "$url/health" >/dev/null && return 0
    sleep 1
  done
  echo "FAIL: $name not healthy after 30s"
  docker logs "$name" 2>&1 | tail -20
  return 1
}

# run_gate <gate> <container> <port> <docker env args...>
run_gate() {
  local gate="$1" name="$2" port="$3"; shift 3
  echo
  echo "===== GATE: $gate ($IMAGE) ====="
  docker rm -f "$name" >/dev/null 2>&1 || true
  docker run -d --name "$name" -p "$port:4173" "$@" "$IMAGE" >/dev/null
  wait_healthy "$name" "http://localhost:$port"
  TARGET_URL="http://localhost:$port" IMAGE_NAME="$IMAGE" "$SCRIPTS/test-$gate.sh"
}

cleanup_gate() { docker rm -f citybike-gate >/dev/null 2>&1 || true; }
trap cleanup_gate EXIT

run_gate staging citybike-gate $GATE_PORT -e APP_ENV=staging;  cleanup_gate
run_gate uat     citybike-gate $GATE_PORT -e APP_ENV=uat;      cleanup_gate
run_gate oat     citybike-gate $GATE_PORT -e APP_ENV=oat;      cleanup_gate
run_gate preprod citybike-gate $GATE_PORT -e APP_ENV=preprod -e PROD_API_KEY="$PROD_API_KEY"; cleanup_gate
# Prod replaces the live container on 4173 and is left running
run_gate prod    citybike-prod $PROD_PORT -e APP_ENV=production -e PROD_API_KEY="$PROD_API_KEY"

echo
echo "===== ALL 5 GATES PASSED: $IMAGE is live as citybike-prod on :$PROD_PORT ====="
