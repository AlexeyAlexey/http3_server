# AI Coding Agent Instructions - Http3Server

## Project Overview

This is an **Elixir HTTP3/WebTransport server** using the [`wtransport`](https://github.com/bugnano/wtransport-elixir.git) library for real-time communication (video conferencing, phone calls).

### Key Technologies
- **Elixir 1.19+** with OTP supervision trees
- **Wtransport** - Elixir wrapper for WebTransport protocol
- **PubSub** - For message broadcasting between participants
- **JWT authentication** with RS256 signatures

---

## Build & Development Commands

```bash
# Install dependencies
mix deps.get

# Compile
mix compile

# Run tests
dotenv -e .env.test mix test

# Start dev server (requires environment variables)
dotenv -e .env iex -S mix  # or run manually with required env vars
```

### Release Build
```bash
./deploys/gen_release.sh local_dir remote_dir
```

---

## Architecture Overview

```
Http3Server.Application (OTP Application)
├── Registry (AudioPhoneCallManager, VideoPhoneCallManager) - Unique name registration
├── Wtransport.Supervisor - Manages HTTP3 server
├── PubSub - Message bus for participants
└── DynamicSupervisors
    ├── Http3Server.AudioPhoneCallManagerSupervisor
    └── Http3Server.VideoPhoneCallManagerSupervisor
```

### Core Modules

| Module | Purpose |
|--------|---------|
| `Http3Server.ConnectionHandler` | Handles new HTTP3 connections, JWT authentication |
| `Http3Server.StreamHandler` | Manages bidirectional/unidirectional streams |
| `Http3Server.PhoneCallManager` | Orchestrates audio/video phone calls |
| `Http3Server.AudioPhoneCallManager` / `VideoPhoneCallManager` | GenServers for individual call sessions |

---

## Authentication Flow

1. Client sends JWT token in URL path: `https://localhost:4433/authToken?token=xxx`
2. `SessionParameters.parse/1` extracts query params including `auth_token`
3. `AuthUserConnection.auth/1` verifies JWT using RS256 signature
4. Public key fetched from trusted hosts via `HostPublicKey.fetch/1`

### JWT Claims Format

**Phone Call:**
```json
{
  "from": "user_id",
  "to": "target_user_id", 
  "type": "phone_call",
  "direction": "outcome|income"
}
```

**Conference:**
```json
{
  "type": "conference",
  "conference_id": "room_id"
}
```

---

## Phone Call Architecture

- **DynamicSupervisor** creates one supervisor per call (audio/video separated)
- **Call ID format:** `"phone_call/#{from}/#{to}"`
- **Two directions:** `"outcome"` (caller) and `"income"` (receiver)
- **Features:**
  - 30-second waiting time for receiver response
  - Ringtone playback during wait
  - Reconnection handling

### PubSub Topics
```
"{stream_type}/phone_call/{from}/{to}"
# Example: "audio/phone_call/user1/user2"
```

---

## Configuration

### Required Environment Variables

```bash
MIX_ENV=dev|prod
HOST="0.0.0.0"  # or "localhost"
PORT=4433
SSL_KEY_PATH=/path/to/server.key
SSL_CERT_PATH=/path/to/server.crt
JWT_SECRET="xxxxxxxxxxxxxxxxx"  # For JWT signing
```

### Certificate Requirements
- Self-signed certificates supported (for dev)
- Validity limited to ≤13 days (browser requirement)
- Certificate hash required in JavaScript client for self-signed certs

**Generate certificate:**
```bash
openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout server.key \
  -x509 -days 12 -out server.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
```

---

## JavaScript Client Setup

```javascript
// For self-signed certificates, serverCertificateHashes is required:
const http3Server = new WebTransport(`https://localhost:4433/authToken`, {
  serverCertificateHashes: [
    {
      algorithm: "sha-256",
      value: hexToBytes("certificate_hash_here")
    }
  ]
});

// For trusted certificates:
const http3Server = new WebTransport(`https://localhost:4433/authToken`);
```

---

## Key Conventions

1. **Registry Usage:** Audio/Video phone call managers registered with unique keys
2. **Supervisor Strategy:** `:one_for_one` for dynamic call supervisors
3. **State Management:** GenServer with `{:ok, pid}` or `{:error, {:already_started, pid}}`
4. **Error Handling:** Custom error messages in auth flow (see `AuthUserConnection.auth/1`)
5. **Logging:** Use `Logger.info/error` with structured data for debugging

---

## Common Tasks

### Adding a New Phone Call Feature
1. Update `PhoneCallManager` or create new GenServer under `phone_call_manager/`
2. Register in appropriate DynamicSupervisor
3. Add PubSub topic subscription in `StreamHandler.handle_stream/3`

### Modifying Authentication
1. Update `AuthToken.verify_token/2` for JWT claims structure
2. Modify `AuthUserConnection.auth/1` to handle new claim formats
3. Update trusted hosts in `TrustedHost` module

---

## Debugging Tips

- Enable network logging: `log_network_data: true` in config
- Check registry entries: `Registry.lookup(AudioPhoneCallManager, call_id)`
- View supervisor tree: `Supervisor.which_children(Http3Server.AudioPhoneCallManagerSupervisor)`
