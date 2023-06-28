# Jellyfin

## Users

Create the following users in Synology DSM:

  - jellyfin

SSH into the NAS with admin user, and get the `id` for the user and group:

```bash
id -u jellyfin
id -g jellyfin
```

## Shares

Grant the Jellyfin user **read only** access to the `entertainment` share. If you have yet to create it, see the `yarr` docs.

## Stack

Create the following files and folders under the `stack` share:

## docker-compose.yml

Remember to change the `user: ` to the `id` of your `jellyfin` user.

```bash
stacks
└── Entertainment
    └── jellyfin
        ├── config/
        └── docker-compose.yml
```

```yaml
version: '3.5'

services:
  jellyfin:
    container_name: jellyfin
    image: jellyfin/jellyfin:latest
    user: 10xx:100
    group_add:
      - "937" # Group on host for allowing jellyfin access to hardware encoding/decoding
    volumes:
      - ./config:/config
      - /volume1/entertainment:/volume1/entertainment:ro
    devices:
      - /dev/dri/card0:/dev/dri/card0
      - /dev/dri/renderD128:/dev/dri/renderD128
    network_mode: host
    restart: unless-stopped
```
