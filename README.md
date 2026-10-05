# Http3Server

An Elixir HTTP/3 (WebTransport) media relay server built on
[`wtransport`](https://github.com/bugnano/wtransport-elixir.git).
Authenticated clients join a room and exchange audio/video stream data
with the other participants in real time.

Used by:

- [Video Conference app](https://github.com/AlexeyAlexey/video_conference)
- [Video Conference vite](https://github.com/AlexeyAlexey/video_conference_vite)
- **All-in-one setup:** [videoconference_docker_compose](https://github.com/AlexeyAlexey/videoconference_docker_compose) — runs all three apps together

## How it works

1. A client opens a WebTransport session to `https://<host>:<port>/?auth_token=<jwt>`.
2. The JWT is verified against a trusted host's public key (RS256). Its claims
   (`room_id`, `participant_id`) identify which room the client joins.
3. Each bidirectional stream subscribes to a PubSub topic named after the room.
   Incoming packets are stamped with the sender's `participant_id` and fanned
   out to every other participant in the room.
4. Datagrams are echoed back to the sender.

## Requirements

- **Elixir ~> 1.19** and **Erlang/OTP 28** (see `.tool-versions`)
- **Rust toolchain** (`cargo`) — required to compile the `wtransport` NIF
- **dotenv-cli** — used to load environment variables in dev/test
- UDP access to the server port (QUIC)

## Quick start

Ubuntu/Debian:

```bash
sudo apt update
sudo apt install dotenv-cli
```

Set up environment variables (see the table below — `.env.example` shows the format):

```bash
cp .env.example .env
# edit .env: set SSL_KEY_PATH / SSL_CERT_PATH / JWT_LOCAL_HOST_PUBLIC_KEY
```

Install dependencies and start the server:

```bash
mix deps.get
dotenv -e .env iex -S mix
```

## Environment variables

| Variable | Required | Description |
|---|---|---|
| `MIX_ENV` | yes | `dev` or `prod` |
| `HOST` | yes | Interface to bind, e.g. `localhost` or `0.0.0.0` |
| `PORT` | yes | Port to listen on, e.g. `4433` |
| `SSL_KEY_PATH` | yes | Path to the TLS private key |
| `SSL_CERT_PATH` | yes | Path to the TLS certificate |
| `JWT_LOCAL_HOST_PUBLIC_KEY` | yes | PEM public key used to verify JWTs issued by the `local` trusted host |
| `JWT_LOCAL_HOST_SECRET_KEY` | tests only | PEM private key used to sign test JWTs |

## TLS certificates

### mkcert

A tool like [`mkcert`](https://github.com/FiloSottile/mkcert) is handy for
generating locally-trusted certificate files for development.

### Self-signed certificate

```bash
openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout server.key \
  -x509 -days 12 -out server.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:10.42.0.1"
```

The validity period must not exceed 14 days — browsers reject
self-signed certificates with a longer lifetime when
`serverCertificateHashes` is used. Add any LAN IPs you connect through
to `subjectAltName`.

Get the SHA-256 fingerprint (needed by the JS client below):

```bash
openssl x509 -in server.crt -outform DER | openssl dgst -sha256 -hex
# e.g. 380f661e9e24c0b9bcb2d760302e8290417fafa3227cb967f41ddd5a7a9ac5bb
```

## Connecting from the browser (JavaScript)

With a self-signed certificate, `serverCertificateHashes` is required:

```javascript
const http3Server = new WebTransport(`https://localhost:4433/authToken`, {
  serverCertificateHashes: [
    {
      algorithm: "sha-256",
      value: hexToBytes("380f661e9e24c0b9bcb2d760302e8290417fafa3227cb967f41ddd5a7a9ac5bb")
    }
  ]
});
```

With a trusted certificate:

```javascript
const http3Server = new WebTransport(`https://localhost:4433/authToken`);
```

## Authentication

The client passes a JWT in the query string: `?auth_token=<jwt>`.
The token must be signed with the private key of a trusted host
(see `Http3Server.Auth.TrustedHost`); the server looks up the matching
public key to verify it.

Required claims:

```json
{
  "host": "local",
  "room_id": "room-1",
  "participant_id": 42,
  "custom_params": {}
}
```

- `host` — selects which trusted host's public key verifies the token
- `room_id` — the PubSub topic / room to join
- `participant_id` — integer stamped into every packet the client sends
- `custom_params` — optional map, passed through to the stream handler

## Media packet format

Clients send packets framed as:

```
<<'M', 'S', payload_length::32, payload>>
```

The server rewrites the header to embed the sender's `participant_id`
before broadcasting to the room:

```
<<'M', 'S', 'E', extended_length::32, participant_id::32, payload>>
```

See `Http3Server.PackageStreamHandler.Package` for the framing parser.

## Tests

```bash
cp .env.test.example .env.test  # set SSL paths first
dotenv -e .env.test mix test
```

## Docker

```bash
# Debian 12 variant: docker build -f Dockerfile.deb12 -t http3_server .
docker build -t http3_server .

docker run --name http3_server \
  -p 4433:4433/tcp -p 4433:4433/udp \
  -v "/path/to/certs/on/host:/app/certs:ro" \
  -e MIX_ENV=prod \
  -e HOST="0.0.0.0" \
  -e PORT=4433 \
  -e JWT_LOCAL_HOST_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----\n..." \
  -e SSL_KEY_PATH=/app/certs/server.key \
  -e SSL_CERT_PATH=/app/certs/server.crt \
  http3_server
```

Archive an image and copy it to another machine:

```bash
docker save -o http3_server-app.tar http3_server:latest
```

Load it on the other machine and run it:

```bash
docker load -i http3_server-app.tar
# then: docker run ...
```

## Deploying to a remote server

The scripts in `deploys/` automate building a release with Docker,
copying it to a server, and switching a symlink to the new release.
This is a quick example — in production, review which system user,
directories, and permissions are appropriate for your setup.

### Extracting the release from the image

`docker create` makes a container from an image without starting it,
so the release can be copied out:

```bash
docker create --name temp-http3_server http3_server
docker cp temp-http3_server:/app /path/to/release/folder
docker rm temp-http3_server

cd /path/to/release/folder
tar -czvf http3_server.tar.gz ./app
```

Copy it to the remote server and decompress:

```bash
scp ./http3_server.tar.gz root@remote_ip:/home/http3_server
# on the remote server:
tar -xvf http3_server.tar.gz
```

### systemd service

If you want file-based logs:

```bash
mkdir /var/log/http3_server
```

Create the unit file:

```bash
nano /etc/systemd/system/http3_server.service
```

```ini
[Unit]
Description=Http3 Server

[Service]
Type=simple
User=root
WorkingDirectory=/home/http3_server/app
ExecStart=/home/http3_server/app/bin/http3_server start
ExecStop=/home/http3_server/app/bin/http3_server stop
Restart=on-failure
EnvironmentFile=/home/env/http3_server
StandardOutput=journal
StandardError=journal
SyslogIdentifier=http3_server

[Install]
WantedBy=multi-user.target
```

See `man systemd.exec` for more
[execution environment options](https://manpages.debian.org/trixie/systemd/systemd.exec.5.en.html).

The `EnvironmentFile` (`/home/env/http3_server`) provides the runtime
environment variables:

```
MIX_ENV=prod
HOST="your ip"
PORT=4433
JWT_LOCAL_HOST_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----\n..."
SSL_KEY_PATH=/home/certs/server.key
SSL_CERT_PATH=/home/certs/server.crt
```

Set ownership and permissions, then enable the service:

```bash
sudo chown root:root /etc/systemd/system/http3_server.service
sudo chmod 644 /etc/systemd/system/http3_server.service
sudo systemctl daemon-reload

systemctl start http3_server
systemctl stop http3_server
systemctl restart http3_server
systemctl status http3_server
systemctl enable http3_server
```

### Logs

Follow the service logs with:

```bash
journalctl -fu http3_server.service
```

With `StandardOutput=journal` / `StandardError=journal` /
`SyslogIdentifier=...` in the unit file, you can also use
`rsyslog` + `logrotate` for file-based log rotation.

### Deploy scripts

Make the scripts executable:

```bash
chmod +x ./deploys/gen_release.sh ./deploys/copy_to_remote.sh ./deploys/switch_to_release.sh
```

Build a release into a local folder (via Docker):

```bash
./deploys/gen_release.sh "/absolute/path/to/local/folder"
# creates a timestamped release, e.g. 20260428_184535
```

Copy a release to a remote server:

```bash
./deploys/copy_to_remote.sh remote_user remote_host local_release_dir release_name remote_release_dir
./deploys/copy_to_remote.sh root "xx.xx.xx.xx" "/absolute/path/to/local/folder/with/release" "20260428_184535" "/absolute/path/to/folder/on/remote/server"
```

Switch the live symlink to another release on the remote server:

```bash
./deploys/switch_to_release.sh remote_user remote_host release
./deploys/switch_to_release.sh root "xx.xx.xx.xx" 20260428_184535
```

## Ringtone

To send an mp3 file through an audio stream, prepend the packet header
described in [Media packet format](#media-packet-format):

```elixir
# 1. Read the file as binary
file_binary = File.read!("/path/to/mp3/file/chunk0.mp3")
file_binary_size = byte_size(file_binary)

# 2. Combine header and file data
new_binary_data = <<"M", "S", file_binary_size::32, 2::8>> <> file_binary

# 3. Save to a new file (optional)
File.write!("/path/to/mp3/file/chunk0.mp3", new_binary_data)
```
