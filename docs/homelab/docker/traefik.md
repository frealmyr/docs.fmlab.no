# Traefik

This is a practical guide for using Traefik v2 with docker-compose, I used this pattern previously, but have now gone all-in on Kubernetes.

## Create docker network

First, lets make two docker networks dedicated to reverse proxying. One for our local network, and one for accessing externally outside our network. 

>We seperate these, so that we can isolate applications that are accessible outside the network.

Run the following commands to create the docker networks, these networks will be created in [bridge mode](https://docs.docker.com/network/#network-drivers) and will persist after reboot

```bash
docker network create lab
docker network create web
```

>We need to run these docker commands manually, defining these network in a `docker-compose.yml` will take down the networks if we run `docker-compose down`, which will make dependent containers fail to start.

### Basic traefik container

If you have not already done it, I recommend to create a folder hierarchy for easier management of your docker-compose files, as mentioned in my [introduction post.](https://fmlab.no/homelab/introduction/)

>The volumes and network created by docker-compose will append the folder name to the docker resources, so in this case the internal network will be called `traefik_internal`.


```bash
mkdir -p $HOME/Homelab/System/traefik \
  && cd $HOME/Homelab/System/traefik
``` 

Inside the traefik folder, we can now create the `docker-compose.yml` file for traefik

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
      - internal
      - lab
      - web
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
    # image: tecnativa/docker-socket-proxy:arm32v7 # Raspberry Pi 32-bit host
    networks:
      - internal
    environment:
      - CONTAINERS=1
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped
```

| Line | Description   |
| :--------------- | :------ |
| L3:L8 | For networks, we add the docker network we created earlier as a external network. Which means that docker will try to connect to this network, but never create nor destroy it. We also have a internal network, which will only be used between services in this docker-compose. |
| L15 | Change the timezone to your current one, this will be used by things like traefik dashboard and logs. |
| L16:L18 | Traefik will bind to port 80 and 443 on the host, as this will be our primary reverse proxy. |
| L19:L22 | Here we define the networks that Traefik will connect to, we will add more networks later for other integrations. Also, _L3:L8_ only makes networks available for the containers. |
| L23:L26 | The traefik configuration files, mounts files in the `traefik` folder into the container. |
| L28 | The traefik container will not start before the docker proxy. |
| L29 | Traefik will restart on reboot, unless you stop the application with `docker-compose down` |
| L31 | Mounting a container to the docker API on the host is a huge security risk, so we can use a sidecar container which will make only a partion of the API accessible to the traefik container over a dedicated docker network. I highly recommend to search the web for this topic. |
| L37 | Here we can define which docker APIs that are available for read-only access, you can [read more about the available APIs here](https://github.com/Tecnativa/docker-socket-proxy#grant-or-revoke-access-to-certain-api-sections). |

### Basic Traefik configuration files

Now that we have the `docker-compose.yml` in place, we need to create the configuration files for traefik, which will be mounted from the root folder into the docker container.

First we need to create two folders in our traefik folder. Create a `config` folder and a `dynamic` folder inside the `config` folder.

```
mkdir -p config/dynamic
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
    network: lab
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
| L7:L13 | This bit is related to the automatic certificate generation for sites that are available externally, change the email to get warnings for expiring certificates. |
| L17 | The default docker network when configuring backends, if the app runs in another network, this needs to be overridden by a label on the container. |
| L18 | Do not expose containers when they are detected in the docker API, we need to add a `traefik.enabled` label to the container since this is false. |
| L19 | Traefik connects to the docker-proxy over the `traefik_internal` network when connecting to the docker API. |
| L21 | Traefik will monitor this directory for configuration files, and automatically reload these if there are any changes made to the files. |
| L24 | Readies the dashboard by enabling the necessary APIs, further configuration is needed. |

#### ACME certificate file

ACME requires a dedicated `acme.json` file for storing its certificates, create it by running

```bash
touch acme.json && chmod 600 acme.json
```

### Starting Traefik

We have now added all of the necessary static configuration files for running Traefik. We can now start Traefik to see if it is running properly

```bash
docker-compose up
```

If the application starts, and there are no errors. You can close the session above, and let it run in the background

```bash
docker-compose up -d
```

Now you should open up a new shell and follow the logs for the `traefik` container for the next steps, where you will see that `traefik` dynamically loads the configuration files as we edit them.

```bash
docker ps | grep traefik
docker logs -f <traefik_container_id>
```

### Dynamic configuration files

Every configuration file that you create inside the `dynamic` folder, will be automatically reloaded. This makes it easy to create new routing rules, as you can listen for the Traefik container logs and check the endpoint while editing files for efficient setup.

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
| L9 | Dashboard will only be available from the local `lab` network |

`redirect.yml`:

```yaml
http:
  routers:
    http:
      entryPoints:
        - http
      rule: HostRegexp(`{host:.+yourexternaldomain.com}`)
      middlewares:
        - https_redirect
      service: noop

  services:
    noop:
      loadBalancer:
        servers:
          - url: http://10.0.0.33

  middlewares:
    https_redirect:
      redirectScheme:
        scheme: https
        permanent: true
```

| Line       | Description   |
| :--------------- | :------ |
| L5 | This rule applies to incoming traffic on HTTP (Port 80) |
| L6 | Only redirect traffic if its coming from yourexternaldomain.com, change to your own FQDN. |
| L7:L8 | If the L6 rule is active, use the `https_redirect` middleware on L17:L21  |
| L11:L15 | Services are used for forwarding traffic, since we only want to redirect the traffic to HTTPS, we set this to the host ip. |
| L17:L21 | Use the `redirectScheme` middleware to redirect the request from HTTP to HTTPS |



### Folder structure after you are done

When you are done with all the config files above, the `traefik` folder should look like this

```bash
frealmyr@FM-SRV:~/Homelab/System$ tree -L 3 traefik/
traefik/
├── config
│   ├── acme.json
│   ├── dynamic
│   │   ├── dashboard.yml
│   │   ├── redirect.yml
│   └── traefik.yml
├── docker-compose.yml
```

Next, take a look at the [Traefik Usage](https://fmlab.no/homelab/traefik-usage/) guide, and/or the [PiHole](https://fmlab.no/homelab/pihole/) guide for resolving `.lab` HTTP requests.

# Practical examples
## Use Case 1: Local lab network only

Local network only example using [homer](https://github.com/bastienwirtz/homer), which is available from http://home.lab/, if you have setup a DNS server as i have done in the [PiHole](https://fmlab.no/homelab/pihole/) guide.

Example `.env` enviroment file, which i use for all my Traefik applications

```bash
# Project
PROJECT=home
DOMAIN=lab
PORT=80
```

```yaml
version: '3.5'

networks:
  lab:
    external: true

services:
  homer:
    container_name: homer
    image: b4bz/homer:latest
    volumes:
      - ./config/assets/:/www/assets
      - ./config/config.yml:/www/config.yml
    networks:
      - lab
    labels:
      - traefik.enable=true
      - traefik.http.routers.${PROJECT}.entryPoints=http
      - traefik.http.routers.${PROJECT}.rule=Host(`home.${DOMAIN}`)
      - traefik.http.services.${PROJECT}.loadbalancer.server.port=${PORT}
```

| Line | Description   |
| :--------------- | :------ |
| L3:L5 | We only want homer to be accessible from our `lab` network |
| L14:L15 | The network will be mounted by the container |
| L17 | In `traefik.yaml` we have set `exposedbydefault: false`, so we need to enable Traefik for this application |
| L18 | Tell Traefik that the entrypoint for this application is over **HTTP** |
| L19 | Here we define the domain that Traefik should redirect traffic to this application, which is now `http://home.lab` |
| L20 | This is the port that the application is listening for. If the application have a `EXPOSE` port defined in the Dockerfile, then Traefik should be able to auto-detect this. |

## Use Case 2: Accessible from the internet

Continuing with the example above, we make some slight changes

```bash
# Project
PROJECT=home
DOMAIN=yourdomain.com
PORT=80
```

```yaml
version: '3.5'

networks:
  web:
    external: true

services:
  homer:
    container_name: homer
    image: b4bz/homer:latest
    volumes:
      - ./config/assets/:/www/assets
      - ./config/config.yml:/www/config.yml
    networks:
      - web
    labels:
      - traefik.enable=true
      - traefik.http.routers.${PROJECT}.entryPoints=https
      - traefik.http.routers.${PROJECT}.rule=Host(`${PROJECT}.${DOMAIN}`)
      - traefik.http.routers.${PROJECT}.tls.certresolver=letsEncrypt
      - traefik.http.services.${PROJECT}.loadbalancer.server.port=${PORT}
```

| Line | Description   |
| :--------------- | :------ |
| L3:L5 | Now we want homer to be accessible from the internet over the `web` network |
| L14:L15 | The network will be mounted by the container |
| L17 | In `traefik.yaml` we have set `exposedbydefault: false`, so we need to enable Traefik for this application |
| L18 | Tell Traefik that the entrypoint for this application is over **HTTPS** |
| L19 | Here we define the domain that Traefik should redirect traffic to this application, which is now `https://home.yourdomain.com` |
| L20 | This is the port that the application is listening for. If the application have a `EXPOSE` port defined in the Dockerfile, then Traefik should be able to auto-detect this. |
