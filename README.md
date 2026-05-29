# Http3Server

It is a stream server. I use it for [Video Conference app](https://github.com/AlexeyAlexey/video_conference) + [Video Conference vite](https://github.com/AlexeyAlexey/video_conference_vite)


```rust cargo``` is required


## Certificate

## mkcert tool

A tool like mkcert can be handy for generating certificate files suitable for local development.

## Self signed certificate


```bash
openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout server.key \
  -x509 -days 12 -out server.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:10.42.0.1"
```

-days 12 cannnot me more than 13 days

```bash
openssl x509 -in server.crt -outform DER | openssl dgst -sha256 -hex
380f661e9e24c0b9bcb2d760302e8290417fafa3227cb967f41ddd5a7a9ac5bb
```

# WebTransport (javascript)

If you use self signed certificate, serverCertificateHashes is required

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


```javascript
const http3Server = new WebTransport(`https://localhost:4433/authToken`);
```


# Setting up dev env

Ubuntu/Debian
development environment variables 

```bash
sudo apt update
sudo apt install dotenv-cli
```
Dev env
```bash
dotenv -e .env iex -S mix
```

# Docker

```bash
docker build -t http3_server .

docker run  --name http3_server \
  -p 4433:4433/tcp -p 4433:4433/udp \
  -v "/path/to/certs/folder/on/host/machine/certs:/app/certs:ro" \
  -e MIX_ENV=prod \
  -e HOST="0.0.0.0" \
  -e HTTP3_SERVER=true \
  -e PORT=4433 \
  -e JWT_SECRET="xxxxxxxxxxxxxxxxx" \
  -e SSL_KEY_PATH=/app/certs/server.key \
  -e SSL_CERT_PATH=/app/certs/server.crt \
  http3_server

```

You can use the following commands to archive an copy an image to another computer/server

```bash
docker save -o http3_server-app.tar http3_server:latest
```

You can unarchive the image and to run it on another computer/server

```bash
docker load -i http3_server-app.tar
```

and then ```docker run ...```

# Deploying to remote server

If you want to deploy it to remote server you can use the following approach.
If you want to use this approach you should read more what directory should be used what system users should be used and what permissions they should be have and what folder permissions should be.

The following example is a quick example 



## Copying release to a host machine 

The ```docker container``` create (or shorthand: docker create) command creates a new container from the specified image, without starting it.

```bash
docker create --name temp-http3_server http3_server
```

```bash
docker cp temp-http3_server:/app /path/to/release/folder
```

```bash
docker rm temp-http3_server
```

```bash
cd /pat/to/release/folder

tar -czvf http3_server.tar.gz ./app
```

copy to remote server
```bash
scp ./http3_server.tar.gz root@remote_ip:/path/to/destination/
```

```bash
scp ./http3_server.tar.gz root@remote_ip:/home/http3_server
```

decompress on remote server
```bash
tar -xvf http3_server.tar.gz
```


## Adding Service

for logs if you want to use log files
```bash
mkdir /var/log/http3_server
```

```bash
cd /etc/systemd/system/
```


```bash
nano /etc/systemd/system/http3_server.service
```
You can read more parameters in 

[Execution environment configuration](https://manpages.debian.org/trixie/systemd/systemd.exec.5.en.html)
```                                                                  
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


I use EnvironmentFile to set up environment variable

/home/env/http3_server
```
MIX_ENV=prod
HOST="your ip"
HTTP3_SERVER=true
PORT=4433
JWT_SECRET="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" 
SSL_KEY_PATH=/home/certs/server.key 
SSL_CERT_PATH=/home/certs/server.crt
```


Set ownership to root
```bash
sudo chown root:root http3_server.service
```

# Set permissions to 644
```bash
sudo chmod 644 http3_server.service
```

```bash
# Apply changes to systemd
sudo systemctl daemon-reload
```

```bash
systemctl start http3_server

systemctl stop http3_server

systemctl restart http3_server

systemctl status http3_server


systemctl enable http3_server
```

# Logs

You can use the following command to view the app logs
```bash
journalctl -fu http3_server.service
```

## Log rotation

if you use

```
StandardOutput=journal
StandardError=journal
SyslogIdentifier=video_conference
```

You can use logrotate and rsyslog


# Added bash scrips to deploy the app to remote server

Added a couple of simple bash scripts (look at deploys folder)

It is required to do the script executable
```bash
chmod +x ./gen_release.sh
chmod +x ./copy_to_remote.sh
chmod +x ./switch_to_release.sh
```
  
  

  to generate a release to local folder

```bash
./gen_release.sh "/absolute/path/to/local/folder"
```

  to copy a release to remote server

```bash
./copy_to_remote.sh remote_user remote_host local_release_dir release_name remote_release_dir
./copy_to_remote.sh root "xx.xx.xx.xx" "/absolute/path/to/local/folder/with/release" "20260428_184535" "/absolute/path/to/folder/on/remote/server"

```

  to switch from one to another on on remote server

```bash 
./switch_to_release.sh remote_user remote_host release
./switch_to_release.sh root "xx.xx.xx.xx" 20260428_184535
```


# Ringtone

add header to mp3 file to send it through audio stream


```bash

# 1. Read the file as binary
file_binary = File.read!("/path/to/mp3/file/chunk0.mp3")

file_binary_size = byte_size(file_binary)

# 2. Combine header and file data
new_binary_data = <<"M", "S", file_binary_size::32, 2::8>> <> file_binary

# 4. Save to a new file (optional)
File.write!("/path/to/mp3/file/chunk0.mp3", new_binary_data)
```