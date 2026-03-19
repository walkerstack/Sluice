#!/bin/bash
# haiflow hook: SessionStart
# Forwards Claude Code session start events to the haiflow server.
curl -s -X POST "http://localhost:${HAIFLOW_PORT:-3333}/hooks/session-start" \
  -H "Content-Type: application/json" \
  --data-binary @- > /dev/null 2>&1 || true
