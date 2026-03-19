#!/bin/bash
# haiflow hook: Stop
# Forwards stop events to the haiflow server to save responses and drain the queue.
curl -s -X POST "http://localhost:${HAIFLOW_PORT:-3333}/hooks/stop" \
  -H "Content-Type: application/json" \
  --data-binary @- > /dev/null 2>&1 || true
