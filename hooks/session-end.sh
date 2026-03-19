#!/bin/bash
# haiflow hook: SessionEnd
# Forwards session end events to the haiflow server to mark session as offline.
curl -s -X POST "http://localhost:${HAIFLOW_PORT:-3333}/hooks/session-end" \
  -H "Content-Type: application/json" \
  --data-binary @- > /dev/null 2>&1 || true
