
# This is a work-in-progress, parts may be missing

I recommend you to get yourself a cheap domain name for personal use, if you don't do this. You will need to keep track of the public IP address, and update it on you device's hosts file.


#### Create docker network

First, lets make two docker networks for reverse proxying. One for our local network, and one for accessing externally outside our network.

Run the following commands to create the docker networks, they will be created in [bridge mode](https://docs.docker.com/network/#network-drivers) and will persist after reboot

```bash
docker network create lab
docker network create web
```

>We need to run the docker commands manually, since defining the network in `docker-compose.yml` will take down it down if we run `docker-compose down`, which will make dependent containers fail to start.

#### Basic traefik container

We can now create the `docker-compose.yml` file for traefik

>Make sure to create this file within a folder named `traefik`, so that the volumes and network appends the folder name to the docker resources.

```yaml
version: '3.5'

networks:
  lab:
    external: true
  web:
    external: true
  internal:

services:
  traefik:
    container_name: traefik
    image: traefik:latest
    environment:
      - TZ=Europe/Oslo
    ports:
      - 80:80
      - 443:443
    networks:
      - lab
      - web
      - internal
    volumes:
      - ./config/traefik.yml:/etc/traefik/traefik.yml
      - ./config/dynamic/:/etc/traefik/dynamic/
      - ./config/acme.json:/etc/traefik/acme/acme.json
    depends_on:
      - docker-proxy
    restart: unless-stopped

  docker-proxy:
    container_name: traefik_docker_proxy
    image: tecnativa/docker-socket-proxy:latest
    networks:
      - internal
    environment:
      - CONTAINERS=1
    volumes:
      - $XDG_RUNTIME_DIR/docker.sock:/var/run/docker.sock
    restart: unless-stopped
```

| Line       | Description   |
| :--------------- | :------ |
| L3:L6 | For networks, we add the docker network we created earlier as a external network. Which means that docker will try to connect to this network, but never create nor destroy it. We also have a internal network, which will only be used between services in this docker-compose. |
| L13 | Change the timezone to your current one, this will be used by things like traefik dashboard and logs. |
| L15:L16 | Traefik will take over port 80 and 443 on the host, since this will be our primary reverse proxy. |
| L17:L19 | Here we define the networks that Traefik will connect to, we will add more networks later for other integrations. Also, _L3:L6_ only makes networks available for the containers. |
| L18:L21 | The traefik configuration files, we will get to that bit soon. |
| L23 | The traefik container will not start before the docker proxy. |
| L34 | Here we can define which docker APIs that are available for read-only access, you can [read more about the available APIs here](https://github.com/Tecnativa/docker-socket-proxy#grant-or-revoke-access-to-certain-api-sections). |
| L36 | If you use a **rootless docker** install, then this is the correct volume. If you are using the standard docker install method, change this to `/var/run/docker.sock:/var/run/docker.sock`. |

#### Basic traefik configuration files

Now that we have the `docker-compose.yml` in place, we need to create the configuration files for traefik.

First we need to create two folders in our traefik folder, create a `config` folder and a `dynamic` folder inside the `config` folder.

It should look like this, excluding the files for now

```bash
fredrick@FM-SRV:~/Homelab/System$ tree -L 3 traefik/
traefik/
├── config
│   ├── acme.json
│   ├── dynamic
│   │   ├── dashboard.yml
│   │   ├── redirect.yml
│   └── traefik.yml
├── docker-compose.yml
```

Inside the `config` folder we can now create a `traefik.yml` file, which will be the primary config file

```yaml
entryPoints:
  http:
    address: :80
  https:
    address: :443

certificatesResolvers:
  letsEncrypt:
    acme:
      email: "change@me.com"
      storage: "/etc/traefik/acme/acme.json"
      httpChallenge:
        entryPoint: http

providers:
  docker:
    network: web
    exposedbydefault: false
    endpoint: "tcp://docker-proxy:2375"
  file:
    directory: "/etc/traefik/dynamic/"

api:
  dashboard: true
```

| Line       | Description   |
| :--------------- | :------ |
| L1:L5 | Here we define which ports Traefik should listen on. |
| L7:L13 | This bit is related to the automatic certificate generation for sub-domains that are available externally. Will not be used for the local network. |
| L17 | The default docker network when configuring backends, if the app runs in another network, this needs to be overridden by a label on the container. |
| L18 | Do not expose containers when they are detected in the docker API, we need to add a `traefik.enabled` label to the container since this is false. |
| L19 | Traefik connects to the docker-proxy over the `traefik_internal` network when connecting to the docker API. |
| L21 | Traefik will monitor this directory for configuration files, and automatically reload these if there are any changes made to the files. |
| L24 | Readies the dashboard by enabling the necessary APIs, further configuration needed. |

##### ACME certificate file

ACME requires a `acme.json` file for storing certificates, create it by running

```bash
touch acme.json
chmod 600 acme.json
```

##### Starting Traefik

We have now added all of the necessary static configuration files for running Traefik. We can now start Traefik to see if it is running properly

```bash
docker-compose up
```



##### Dynamic configuration files

Every configuration file that you create inside the `dynamic` folder, will be automatically reloaded if you makes changes. This makes it easy to create new routing rules, as you can listen for the Traefik container logs and check the endpoint while editing files for efficient setup.

But, since we don't have anything running, there is no need to start Traefik yet.

Let's add two dynamic configurations, `dashboard.yml` for the Traefik dashboard and `redirect.yml` for redirecting any external sites from HTTP to HTTPS

`dashboard.yml`:

```yaml
http:
  routers:
    dashboard:
      rule: Host(`traefik.lab`)
      service: api@internal
      entryPoints:
        - http
docker:
  network: lab
```

| Line       | Description   |
| :--------------- | :------ |
| L4 | The domin where the Traefik dashboard will be available from. |
| L5 | Connects the dashboard router to the traefik api which we made available in `traefik.yml` |

`redirect.yml`:

```yaml
http:
  routers:
    http:
      entryPoints:
        - http
      middlewares:
        - https_redirect
      rule: HostRegexp(`{host:.+yourdomain.com}`)
      service: noop

  services:
    noop:
      loadBalancer:
        servers:
          - url: http://10.0.0.5

  middlewares:
    https_redirect:
      redirectScheme:
        scheme: https
        permanent: true
```