# API Reference

All endpoints (except `/health` and `/hooks/*`) require an `Authorization: Bearer <HAIFLOW_API_KEY>` header. `HAIFLOW_API_KEY` is any secret string you define — not a paid key or external credential.

## `POST /session/start`

Start a Claude Code session in a detached tmux session.

```bash
curl -X POST http://localhost:3333/session/start \
  -H "Content-Type: application/json" \
  -d '{"session": "worker", "cwd": "/path/to/project"}'
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `cwd` | string | **Yes** | Working directory for Claude |
| `session` | string | No | Session name (default: `"default"`) |

## `POST /session/stop`

Kill a Claude tmux session.

```bash
curl -X POST http://localhost:3333/session/stop \
  -H "Content-Type: application/json" \
  -d '{"session": "worker"}'
```

## `POST /trigger`

Send a prompt to Claude. If Claude is busy, the prompt is auto-queued and sent when idle.

```bash
curl -X POST http://localhost:3333/trigger \
  -H "Content-Type: application/json" \
  -d '{"prompt": "summarize recent commits", "session": "worker", "id": "task-001"}'
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `prompt` | string | **Yes** | The prompt or slash command to send |
| `session` | string | No | Session name (default: `"default"`) |
| `id` | string | No | Custom task ID (auto-generated if omitted) |
| `source` | string | No | Label for where the trigger came from |

Responses:
- **Idle**: `{"id": "...", "sent": true}` — sent immediately
- **Busy**: `{"id": "...", "queued": true, "position": 1}` — auto-sends when idle
- **Offline**: `503` error

## `GET /responses/:id`

Get the response for a completed task.

```bash
curl -s "http://localhost:3333/responses/task-001?session=worker" | jq .
```

```json
{
  "id": "task-001",
  "completed_at": "2025-03-18T02:35:09Z",
  "messages": ["Here's a summary of recent commits..."]
}
```

Status codes:
- **200**: Complete — response body included
- **202**: `{"status": "pending"}` or `{"status": "queued"}`
- **404**: Unknown task ID

## `GET /responses/:id/stream`

Stream response status via Server-Sent Events. Opens a persistent connection that sends real-time updates until the task completes — no polling required.

```bash
curl -N "http://localhost:3333/responses/task-001/stream?session=worker"
```

| Param | Default | Description |
|-------|---------|-------------|
| `timeout` | `300` | Max seconds to wait (capped at 600) |

Events:
- **`status`**: `{"id": "...", "status": "pending"}` or `{"status": "queued", "position": 2}`
- **`complete`**: Full response object (same as `GET /responses/:id`)
- **`error`**: `{"error": "Session is offline"}`
- **`timeout`**: Sent when the timeout is reached

Example with EventSource (browser/Node):

```js
const es = new EventSource("http://localhost:3333/responses/task-001/stream?session=worker");
es.addEventListener("complete", (e) => {
  const response = JSON.parse(e.data);
  console.log(response.messages);
  es.close();
});
es.addEventListener("status", (e) => console.log("Status:", JSON.parse(e.data)));
es.addEventListener("error", (e) => { console.error(e.data); es.close(); });
es.addEventListener("timeout", () => { console.log("Timed out"); es.close(); });
```

## `GET /status`

```bash
curl -s http://localhost:3333/status?session=worker | jq .
```

## `GET /sessions`

List all sessions and their status.

## `GET /responses`

List all completed response IDs.

## `GET /queue`

View queued prompts for a session.

## `DELETE /queue`

Clear all queued prompts.

## `GET /health`

Returns `ok`.
