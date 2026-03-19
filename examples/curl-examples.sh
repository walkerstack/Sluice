#!/bin/bash
# haiflow - Quick start examples
# Make sure the server is running: bun start

BASE="http://localhost:3333"

echo "=== Start a session ==="
curl -s -X POST "$BASE/session/start" \
  -H "Content-Type: application/json" \
  -d '{"session": "worker", "cwd": "/path/to/your/project"}' | jq .

echo ""
echo "=== Send a prompt ==="
curl -s -X POST "$BASE/trigger" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "explain this codebase", "session": "worker", "id": "my-task"}' | jq .

echo ""
echo "=== Check status ==="
curl -s "$BASE/status?session=worker" | jq .

echo ""
echo "=== Poll for response ==="
while true; do
  RESP=$(curl -s "$BASE/responses/my-task?session=worker")
  STATUS=$(echo "$RESP" | jq -r '.status // "done"')
  [ "$STATUS" = "done" ] && echo "$RESP" | jq . && break
  echo "Status: $STATUS - waiting..."
  sleep 3
done

echo ""
echo "=== List all sessions ==="
curl -s "$BASE/sessions" | jq .

echo ""
echo "=== View queue ==="
curl -s "$BASE/queue?session=worker" | jq .

echo ""
echo "=== Stop session ==="
curl -s -X POST "$BASE/session/stop" \
  -H "Content-Type: application/json" \
  -d '{"session": "worker"}' | jq .
