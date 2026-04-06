#!/bin/bash
# Health check — verifies all haiflow services are running and reachable
# Usage: bash bin/healthcheck.sh  or  bun run healthcheck

set -uo pipefail

# Load .env from project root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_DIR/.env" ]; then
  set -a
  source "$PROJECT_DIR/.env"
  set +a
fi

PORT="${PORT:-3333}"
HAIFLOW_URL="http://localhost:$PORT"
HAIFLOW_API_KEY="${HAIFLOW_API_KEY:-}"
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY:-}"

PASS=0
WARN=0
FAIL=0

pass()  { printf "  \033[32m✓\033[0m %-25s %s\n" "$1" "$2"; ((PASS++)); }
warn()  { printf "  \033[33m○\033[0m %-25s %s\n" "$1" "$2"; ((WARN++)); }
fail()  { printf "  \033[31m✗\033[0m %-25s %s\n" "$1" "$2"; ((FAIL++)); }

echo ""
echo "haiflow health check"
echo "===================="
echo ""

# ── 1. Required binaries ──────────────────────────────────────────────

echo "Binaries:"
for cmd in bun tmux claude jq curl; do
  if command -v "$cmd" &> /dev/null; then
    pass "$cmd" "$(command -v "$cmd")"
  else
    fail "$cmd" "not installed"
  fi
done
echo ""

# ── 2. Haiflow server ─────────────────────────────────────────────────

echo "Haiflow server ($HAIFLOW_URL):"

HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$HAIFLOW_URL/health" 2>/dev/null || echo "000")
if [ "$HEALTH" = "200" ]; then
  pass "GET /health" "200 OK"
else
  fail "GET /health" "unreachable (HTTP $HEALTH) — is haiflow running?"
fi

if [ -n "$HAIFLOW_API_KEY" ]; then
  AUTH=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $HAIFLOW_API_KEY" "$HAIFLOW_URL/sessions" 2>/dev/null || echo "000")
  if [ "$AUTH" = "200" ]; then
    pass "API auth" "HAIFLOW_API_KEY valid"
  else
    fail "API auth" "rejected (HTTP $AUTH) — check HAIFLOW_API_KEY in .env"
  fi
else
  warn "API auth" "HAIFLOW_API_KEY not set in .env"
fi
echo ""

# ── 3. Claude Code sessions ───────────────────────────────────────────

echo "Claude Code sessions:"

if [ "$HEALTH" = "200" ] && [ -n "$HAIFLOW_API_KEY" ]; then
  SESSIONS_JSON=$(curl -s -H "Authorization: Bearer $HAIFLOW_API_KEY" "$HAIFLOW_URL/sessions" 2>/dev/null || echo "[]")
  SESSION_COUNT=$(echo "$SESSIONS_JSON" | jq 'length' 2>/dev/null || echo "0")

  if [ "$SESSION_COUNT" -gt 0 ]; then
    echo "$SESSIONS_JSON" | jq -r '.[] | "\(.session) \(.status)"' 2>/dev/null | while read -r name status; do
      case "$status" in
        idle)    pass "$name" "idle" ;;
        busy)    pass "$name" "busy (processing)" ;;
        offline) warn "$name" "offline" ;;
        *)       warn "$name" "$status" ;;
      esac
    done
  else
    warn "sessions" "none found — start one with POST /session/start"
  fi
else
  warn "sessions" "skipped (haiflow not reachable)"
fi
echo ""

# ── 4. tmux sessions ──────────────────────────────────────────────────

echo "tmux:"

if command -v tmux &> /dev/null; then
  TMUX_COUNT=$(tmux list-sessions 2>/dev/null | wc -l | tr -d ' ')
  if [ "$TMUX_COUNT" -gt 0 ]; then
    pass "tmux sessions" "$TMUX_COUNT active"
  else
    warn "tmux sessions" "none running"
  fi
else
  fail "tmux" "not installed"
fi
echo ""

# ── 5. Pipeline ───────────────────────────────────────────────────────

echo "Pipeline:"

if [ "$HEALTH" = "200" ] && [ -n "$HAIFLOW_API_KEY" ]; then
  PIPELINE_JSON=$(curl -s -H "Authorization: Bearer $HAIFLOW_API_KEY" "$HAIFLOW_URL/pipeline" 2>/dev/null || echo "{}")
  TOPIC_COUNT=$(echo "$PIPELINE_JSON" | jq '.topics | length' 2>/dev/null || echo "0")
  REDIS=$(echo "$PIPELINE_JSON" | jq -r '.redis' 2>/dev/null || echo "false")
  EVENTS=$(echo "$PIPELINE_JSON" | jq '.recentEvents | length' 2>/dev/null || echo "0")

  if [ "$TOPIC_COUNT" -gt 0 ]; then
    pass "topics" "$TOPIC_COUNT configured"
  else
    warn "topics" "none — add pipeline.json to HAIFLOW_DATA_DIR"
  fi

  if [ "$EVENTS" -gt 0 ]; then
    pass "recent events" "$EVENTS"
  else
    warn "recent events" "none"
  fi
else
  warn "pipeline" "skipped (haiflow not reachable)"
fi
echo ""

# ── 6. n8n ────────────────────────────────────────────────────────────

# ── 6. Redis ──────────────────────────────────────────────────────────

REDIS_URL="${REDIS_URL:-redis://localhost:6379}"
echo "Redis ($REDIS_URL):"

REDIS_HOST=$(echo "$REDIS_URL" | sed 's|redis://||' | cut -d: -f1)
REDIS_PORT=$(echo "$REDIS_URL" | sed 's|redis://||' | cut -d: -f2 | cut -d/ -f1)
REDIS_PORT="${REDIS_PORT:-6379}"

# Try redis-cli first, fall back to raw TCP PING
REDIS_PING=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping 2>/dev/null || \
  echo "PING" | nc -w 2 "$REDIS_HOST" "$REDIS_PORT" 2>/dev/null | grep -o "PONG" || echo "FAIL")
if echo "$REDIS_PING" | grep -q "PONG"; then
  pass "ping" "PONG"
else
  # Check if port is at least open (haiflow server connecting successfully also confirms Redis)
  if [ "$HEALTH" = "200" ]; then
    # If haiflow started successfully, Redis must be reachable (it's a hard dep now)
    pass "reachable" "connected (via haiflow)"
  else
    fail "ping" "unreachable — is Redis running? (docker run -d -p 6379:6379 redis)"
  fi
fi
echo ""

# ── 7. n8n ────────────────────────────────────────────────────────────

echo "n8n ($N8N_URL):"

N8N_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$N8N_URL/healthz" 2>/dev/null || echo "000")
if [ "$N8N_HEALTH" = "200" ]; then
  pass "GET /healthz" "200 OK"
else
  # Try alternative health endpoint
  N8N_HEALTH2=$(curl -s -o /dev/null -w "%{http_code}" "$N8N_URL/" 2>/dev/null || echo "000")
  if [ "$N8N_HEALTH2" = "200" ] || [ "$N8N_HEALTH2" = "302" ]; then
    pass "reachable" "HTTP $N8N_HEALTH2"
  else
    fail "reachable" "unreachable (HTTP $N8N_HEALTH) — is n8n running?"
  fi
fi

if [ -n "$N8N_API_KEY" ]; then
  N8N_WF=$(curl -s -w "\n%{http_code}" -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_URL/api/v1/workflows?limit=1" 2>/dev/null || echo -e "\n000")
  N8N_CODE=$(echo "$N8N_WF" | tail -1)
  if [ "$N8N_CODE" = "200" ]; then
    pass "API auth" "N8N_API_KEY valid"
    ACTIVE=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_URL/api/v1/workflows" 2>/dev/null | jq '[.data[] | select(.active == true)] | length' 2>/dev/null || echo "?")
    TOTAL=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_URL/api/v1/workflows" 2>/dev/null | jq '.data | length' 2>/dev/null || echo "?")
    pass "workflows" "$ACTIVE active / $TOTAL total"
  else
    fail "API auth" "rejected (HTTP $N8N_CODE) — check N8N_API_KEY in .env"
  fi
else
  warn "API auth" "N8N_API_KEY not set in .env"
fi
echo ""

# ── Summary ───────────────────────────────────────────────────────────

echo "===================="
printf "  \033[32m$PASS passed\033[0m"
[ "$WARN" -gt 0 ] && printf "  \033[33m$WARN warnings\033[0m"
[ "$FAIL" -gt 0 ] && printf "  \033[31m$FAIL failed\033[0m"
echo ""
echo ""

[ "$FAIL" -gt 0 ] && exit 1
exit 0
