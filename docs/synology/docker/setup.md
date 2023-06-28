# Docker Setup & Pattern

To make our docker configuration simple, clean and secure we are going to do the following:

 - Install docker using the `Container Manager` package
 - Create a folder structure with a category pattern
 - Create dedicated users for docker containers
 - Create a share dedicated for `docker-compose` shares
 - Use the `docker-compose` functionality introduced in DSM 7.2

I'll assume you know how to to do basic configuration in Synology DSM, such as creating shares, installing packages, etc.

## M.2 SSD Array

I recommend you to install docker on a dedicated M.2 SSD, even if your device does not officially support it. You can do this at a later date and keep the data when moving the package over to the M.2 SSD volume.

> Docker on M.2 benefits includes lower latency when accessing applications, less random access on spinning disk array, less wakeups on HDDs if you hibernate.

## Setup

Install the `Container Manager` package from the Package Center.

This will automatically create the share `docker` on the Volume you selected (or set as default) in Package Center.

The `docker` share will contain docker volumes, which will be used if you define a [named volume](https://docs.docker.com/storage/volumes/). Useful when you want to persist data in a centralized location on the host, such as taking backup of all docker volumes.

Normal users will not need access to this share, only services which will make backups from docker volumes.

## Stacks

We need a share for storing `docker-compose` stacks, which contains `docker-compose.yml` definitions, optional `.env` files and possibly bind mounts if we want to keep configuration close to the stack.

> `docker-compose` prefixes the current folder to the docker containers, so we need a bottom level folder with the name of the stack. Else `docker ps` will become ugly.

Create the `stack` share, grant your standard user read/write permissions for the share. Add the share to your local machine, open up the share in an IDE.

### Folder pattern

I recommend the following folder pattern:

```bash
stacks
├── Data
│   └── duplicati
│       └── docker-compose.yml
├── Entertainment
│   ├── jellyfin
│   │   ├── config
│   │   └── docker-compose.yml
│   └── yarr
│       ├── .env
│       ├── config
│       └── docker-compose.yml
└── System
    └── watchtower
        └── docker-compose.yml
```

This will seperate a set of stacks under a category, which scales well when the number of stacks grow.

## Starting a stack

Create the following folders on the `stacks` share:

```bash
stacks
└── System
    └── watchtower
        └── docker-compose.yml
```

Create the `docker-compose.yml` with the following content:

> Watchtower is a application for auto-upgrading all docker container images using the Docker API.

```yaml
version: "3.5"

networks:
  internal:

services:
  watchtower:
    container_name: watchtower
    image: containrrr/watchtower:latest
    networks:
      - internal
    environment:
      - TZ=Europe/Oslo
      - WATCHTOWER_CLEANUP=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped
```

We are now ready to start the `docker-compose.yml` stack, and you got two options.

### CLI

 - SSH into the NAS using your admin user
 - `cd /volume2/stacks`
 - `cd System/watchtower`
 - `docker-compose up -d`
 - `docker ps` or `docker-compose ps`

### GUI

> There are two limitations with GUI. You cannot create folders when selecting location and no support for `.env` files for using variables inside `docker-compose.yml`

![](\assets\images\synology\docker-stack-1.png#center)
![](\assets\images\synology\docker-stack-2.png#center)
![](\assets\images\synology\docker-stack-3.png#center)
![](\assets\images\synology\docker-stack-4.png#center)
![](\assets\images\synology\docker-stack-5.png#center)
![](\assets\images\synology\docker-stack-6.png#center)

## Users

By default, Docker containers run with root access to the host system. We can make it more secure by defining linux users with standard access that the different containers will use.

Setting user id is ad-hoc between the host and the container.

We can set define which user `id` and group `id` to use inside the container, say `1000:1000`, which will not have access for files on the host as the user `1000` does not exist on the host, nor has the permission for accessing the files.

> Setting UID/GID is either done in the docker run command, during docker image build, or as a pre-step script in the entrypoint using environment variables.

So we basically need to:

 - Create a standard user in DSM
    - Optional: grant access to shares for the standard user to use
 - SSH into the nas with admin user
 - Run `id -u USERNAME` and `id -g USERNAME` to get UID and GID values
 - Set the UID and GID on the container configuration