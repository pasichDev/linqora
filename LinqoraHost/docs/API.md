# Linqora Host WebSocket API

All communication happens over a single WebSocket connection to `wss://<host>:<port>/ws`.

Every message is a JSON object with at least a `type` field. The server always replies with a JSON object containing `type`, `status` (`"success"` or `"error"`), and a `data` payload.

---

## Authentication

Before any other message is accepted the client must authenticate.

### 1. Auth Request

**Client → Server**
```json
{
  "type": "auth_request",
  "data": {
    "deviceId": "<uuid>",
    "deviceName": "My Phone",
    "version": "1.0"
  }
}
```

**Server → Client (no shared secret)**
```json
{ "type": "auth_response", "status": "pending", "data": { "message": "Waiting for host approval" } }
```
The server console shows a prompt; the host operator types `y` or `n`. The client polls with `auth_check`.

**Server → Client (shared secret configured)**
```json
{ "type": "auth_challenge", "status": "success", "data": { "token": "<64-char hex>" } }
```
The client must respond with HMAC-SHA256 (see below).

---

### 2. HMAC Challenge Response

**Client → Server**
```json
{
  "type": "auth_challenge_response",
  "data": {
    "token": "<same 64-char hex>",
    "hmac": "<hex HMAC-SHA256(token, sharedSecret)>"
  }
}
```

**Server → Client (success)**
```json
{ "type": "auth_response", "status": "success", "data": { "message": "Authorized" } }
```

**Server → Client (failure)**
```json
{ "type": "auth_response", "status": "error", "data": { "code": 300, "message": "Invalid challenge response" } }
```

---

### 3. Auth Check (polling)

**Client → Server**
```json
{ "type": "auth_check" }
```

**Server → Client**
```json
{ "type": "auth_response", "status": "success"|"pending"|"error", "data": { ... } }
```

---

## Ping / Pong

**Client → Server**
```json
{ "type": "ping", "data": { "timestamp": 1714000000000 } }
```

**Server → Client**
```json
{ "type": "pong", "status": "success", "data": { "timestamp": 1714000000000 } }
```

---

## Rooms

Rooms gate streaming data. A client only receives broadcasts for rooms it has joined.

| Room name | Streamed data           |
|-----------|------------------------|
| `media`   | `NowPlaying`, `MediaCapabilities`, volume |
| `metrics` | CPU, RAM, GPU, disk, battery metrics      |

### Join Room

**Client → Server**
```json
{ "type": "join_room", "room": "metrics" }
```

### Leave Room

**Client → Server**
```json
{ "type": "leave_room", "room": "metrics" }
```

---

## Host Info

**Client → Server**
```json
{ "type": "host_info" }
```

**Server → Client**
```json
{
  "type": "host_info",
  "status": "success",
  "data": {
    "os": "windows",
    "hostname": "MY-PC",
    "su": true,
    "cpu": { "model": "Intel Core i7-12700K", "cores": 12, "threads": 20, "frequency": 3600 },
    "ram": { "total": 32768, "used": 12000, "available": 20768 },
    "gpu": { "model": "NVIDIA GeForce RTX 3080", "memory": 10240 },
    "disks": [{ "name": "C:", "total": 512000, "used": 256000, "free": 256000 }],
    "battery": { "isPresent": false, "level": 0, "isCharging": false, "status": "Unknown" }
  }
}
```

---

## Media Control

**Client must be in `media` room.**

**Client → Server**
```json
{ "type": "media", "room": "media", "data": { "action": <int>, "value": <int> } }
```

### Media Actions

| Action | Value | Description            |
|--------|-------|------------------------|
| 0      | —     | Play / Pause           |
| 1      | —     | Next track             |
| 2      | —     | Previous track         |
| 3      | —     | Mute / Unmute          |
| 10     | 0–100 | Set volume (%)         |
| 11     | —     | Increase volume step   |
| 12     | —     | Decrease volume step   |

---

## Power Control

**Client → Server**
```json
{ "type": "power", "data": { "action": <int> } }
```

### Power Actions

| Action | Description      |
|--------|-----------------|
| 0      | Shutdown         |
| 1      | Restart          |
| 2      | Lock screen      |

**Server → Client (executing)**
```json
{ "type": "power", "status": "success", "data": { "action": 0, "status": "executing" } }
```

---

## Mouse / Touchpad

**Client → Server**
```json
{
  "type": "mouse",
  "data": {
    "action": <int>,
    "dx": <int>,
    "dy": <int>,
    "delta": <int>
  }
}
```

### Mouse Actions

| Action | `dx`/`dy` | `delta` | Description              |
|--------|-----------|---------|--------------------------|
| 0      | pixels    | —       | Move (relative)          |
| 1      | —         | —       | Left click               |
| 2      | —         | —       | Right click              |
| 3      | —         | —       | Middle click             |
| 4      | —         | ±1      | Scroll (+ up, − down)    |
| 5      | —         | —       | Double click             |

Move events (`action: 0`) receive **no success reply** to minimise latency.

---

## Script Scheduler

### List Scripts

**Client → Server**
```json
{ "type": "script_list" }
```

**Server → Client**
```json
{
  "type": "script_list",
  "status": "success",
  "data": {
    "scripts": [
      { "id": "backup", "name": "Daily Backup", "description": "Runs the backup script" }
    ]
  }
}
```

### Execute Script

**Client → Server**
```json
{ "type": "script_execute", "data": { "id": "backup" } }
```

**Server → Client**
```json
{
  "type": "script_execute",
  "status": "success",
  "data": {
    "id": "backup",
    "exit_code": 0,
    "stdout": "Backup complete.\n",
    "stderr": "",
    "duration_ms": 1240
  }
}
```

Scripts are defined server-side only (`~/.config/linqora/scripts.json`). The client cannot inject commands — it only supplies a registered script ID.

---

## Error Response Format

```json
{
  "type": "<original type>",
  "status": "error",
  "data": {
    "code": <int>,
    "message": "<description>"
  }
}
```

### Common Error Codes

| Code | Meaning              |
|------|----------------------|
| 400  | Bad request / invalid format |
| 401  | Unauthorized         |
| 403  | Forbidden            |
| 404  | Not found            |
| 429  | Rate limit exceeded  |
| 500  | Internal server error|

---

## Rate Limiting

Each client is limited to **60 messages burst** and **30 messages/second** sustained (token-bucket). `ping` messages are exempt. Exceeding the limit returns a `429` error; the connection is not closed.
