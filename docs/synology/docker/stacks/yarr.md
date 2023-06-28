# yarr

## Users

Create the following users in Synology DSM:

  - yarr

SSH into the NAS with admin user, and get the `id` for the user and group:

```bash
id -u yarr
id -g yarr
```

## Shares

Create the following shares, with read/write permissions for the `yarr` user.

  - entertainment
  - downloads

I recommend to use a M.2 SSD volume for the `download` share, and use `sonarr` / `radarr` to copy completed downloads to the `entertainment` share. As seeding is quite heavy on random read, this will lessen the burden on HDD and increase their lifespan.

## Stack

Create the following files and folders under the `stack` share:

```bash
stacks
└── Entertainment
    └── yarr
        ├── .env
        ├── config/
        └── docker-compose.yml
```

The `config/` folder will be used by all applications for storing configurations, which is handy to have close to the docker-compose stack.

## .env

Populate the `.env` file with the following content:

```bash
PUID=10xx
PGID=100
TIMEZONE=Europe/Oslo
EXTERNAL_IP=192.168.0.11
```

Replace `PUID` with the `id` for your own yarr user!

`EXTERNAL_IP` is used for only listening for connections on the second ethernet port, with the idea that the first port is used for NAS transfers and the second for Docker stuff. Can be removed if you remove the variable and colon in the `docker-compose.yml` file

## docker-compose.yml

```yaml
version: '3.5'

networks:
  internal:

services:
  transmission:
    image: lscr.io/linuxserver/transmission:latest
    container_name: transmission
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TIMEZONE}
      - PEERPORT=54213
    volumes:
      - ./config/transmission:/config
      - /volume2/downloads:/volume2/downloads
      - /volume1/entertainment:/volume1/entertainment
    networks:
      - internal
    ports:
      - ${EXTERNAL_IP}:9091:9091
      - ${EXTERNAL_IP}:54213:54213
      - ${EXTERNAL_IP}:54213:54213/udp
    restart: unless-stopped

  prowlarr:
    container_name: prowlarr
    image: lscr.io/linuxserver/prowlarr:develop
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TIMEZONE}
    volumes:
      - ./config/prowlarr:/config
    networks:
      - internal
    ports:
      - ${EXTERNAL_IP}:9696:9696
    restart: unless-stopped

  sonarr:
    container_name: sonarr
    image: linuxserver/sonarr:latest
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TIMEZONE}
    volumes:
      - ./config/sonarr:/config
      - /volume2/downloads:/volume2/downloads
      - /volume1/entertainment:/volume1/entertainment
    networks:
      - internal
    ports:
      - ${EXTERNAL_IP}:8989:8989
    depends_on:
      - prowlarr
    restart: unless-stopped

  radarr:
    container_name: radarr
    image: linuxserver/radarr:latest
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TIMEZONE}
    volumes:
      - ./config/radarr:/config
      - /volume2/downloads:/volume2/downloads
      - /volume1/entertainment:/volume1/entertainment
    networks:
      - internal
    ports:
      - ${EXTERNAL_IP}:7878:7878
    depends_on:
      - prowlarr
    restart: unless-stopped
```

## 