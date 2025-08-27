# FreeSWITCH Testing

> **Note:** These instructions are for running on a Mac M1 (Apple Silicon).  
> Make sure your Docker images and dependencies support ARM64 architecture.

## Prerequisites

- [Docker Desktop for Mac (Apple Silicon)](https://docs.docker.com/desktop/install/mac-install/)  
- [Docker Compose](https://docs.docker.com/compose/)

## Setup & Run

1. **Build and start FreeSWITCH using Docker Compose:**

    ```sh
    docker compose up --build -d
    ```

    This will build the image from your `Dockerfile` and start the container.

2. **Access FreeSWITCH CLI inside the container:**

    ```sh
    docker compose exec freeswitch-prod fs_cli
    ```

    *(The service name is `freeswitch-prod` as set in your `docker-compose.yml`.)*

## SIPp Testing Examples

### Register

```sh
sipp -sf uas_register.xml 192.168.100.183:5060 \
  -i 192.168.100.183 \
  -p 5062 \
  -s 1001 \
  -au 1001 -ap 1234 \
  -m 1 -l 1 \
  -nd -nr -aa \
  -trace_msg -trace_err
```

### Invite

```sh
sipp -sf uas_invite.xml 192.168.100.183:5060 -i 192.168.100.183 \
  -p 5062 \
  -s 1001 \
  -mp 14000 \
  -m 1 \
  -nd -nr -aa \
  -trace_msg -trace_err
```

### UAC

```sh
sipp -sf uac_1000.xml 192.168.100.183:5060 -s 1001 -au 1000 -ap 1234 -m 1 -l 1 -trace_screen -trace_err -trace_msg
```

## Useful Commands (inside the container)

```sh
apt update
apt install -y iputils-ping bash curl vim
apt-get install dnsutils -y
apt install -y ca-certificates
update-ca-certificates
export PATH=$PATH:/usr/local/freeswitch/bin
fs_cli
```

---

**Tips for Mac M1:**
- If you encounter architecture issues, ensure your Dockerfile uses base images that support `arm64`.
- You may need to add `platform: linux/arm64` to your `docker-compose.yml` service for compatibility:

    ```yaml
    services:
      freeswitch:
        platform: linux/arm64
        ...
    ```

Adjust IP addresses and service names as needed