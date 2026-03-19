#!/bin/bash
# haiflow hook: UserPromptSubmit
# Forwards prompt events to the haiflow server to mark session as busy.
curl -s -X POST "http://localhost:${HAIFLOW_PORT:-3333}/hooks/prompt" \
  -H "Content-Type: application/json" \
  --data-binary @- > /dev/null 2>&1 || true
