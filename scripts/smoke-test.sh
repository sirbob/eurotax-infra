#!/usr/bin/env bash
# Smoke tests for Eurotax platform deployment.
# Usage: ./scripts/smoke-test.sh <server-ip>
# Exit 0 = all checks pass, Exit 1 = failures found.

set -uo pipefail

SERVER_IP="${1:-}"

if [[ -z "$SERVER_IP" ]]; then
  echo "Usage: $0 <server-ip>"
  exit 1
fi

ERRORS=0
TOTAL=0

check() {
  local name="$1"
  local cmd="$2"
  local expected="$3"
  TOTAL=$((TOTAL + 1))

  local result
  result=$(eval "$cmd" 2>&1) || true

  if echo "$result" | grep -q "$expected"; then
    echo "  PASS: $name"
  else
    echo "  FAIL: $name (expected '$expected', got: $result)"
    ERRORS=$((ERRORS + 1))
  fi
}

echo "Smoke testing Eurotax platform at $SERVER_IP..."
echo ""

echo "--- Health Endpoints ---"
check "API health (8080)" \
  "curl -sf --max-time 10 http://${SERVER_IP}:8080/actuator/health" \
  "UP"

check "Mock health (8090)" \
  "curl -sf --max-time 10 http://${SERVER_IP}:8090/actuator/health" \
  "UP"

check "UI responds (8000)" \
  "curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://${SERVER_IP}:8000" \
  "200"

echo ""
echo "--- Container Status ---"
check "All containers running" \
  "ssh -o StrictHostKeyChecking=no root@${SERVER_IP} 'docker compose -f /opt/eurotax/docker-compose.yml ps --format json 2>/dev/null | python3 -c \"import sys,json; lines=sys.stdin.read().strip().split(chr(10)); states=[json.loads(l)[\\\"State\\\"] for l in lines if l]; print(\\\"all_running\\\" if all(s==\\\"running\\\" for s in states) else \\\"not_all_running\\\")\"'" \
  "all_running"

echo ""
if [[ $ERRORS -gt 0 ]]; then
  echo "RESULT: FAIL — $ERRORS/$TOTAL checks failed"
  exit 1
else
  echo "RESULT: PASS — $TOTAL/$TOTAL checks passed"
  exit 0
fi
