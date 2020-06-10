### Custom domain name

I recommend you to get yourself a cheap domain name for personal use, it will make visiting your hosted applications outside the network a lot easier.

But you don't absolutely have to buy a domain name, there are some options you could explore:

- You could use a dynamic DNS services such as No-IP or DynDNS.
- You could keep track of the public IP address yourself, and keep it  updated in your device's hostfile. (Certificates needs to be self-signed.)
- You could set up a [split tunnel VPN](https://en.wikipedia.org/wiki/Split_tunneling) on your device, and keep it connected to the homelab subnet when you need to access services. (Need to keep track of public IP as well.)

This guide also have parts that requires a FQDN to work, if you don't have a FQDN. Then you can remove every bit containing FQDN and certificates from this guide. Also, you can research how to set up self-signed certificates using Traefik if you still want to encrypt traffic.

### What is reverse proxying?

A reverse proxy server is a server that receives requests and forward them to the appropriate backend services.

Basic example:

- The reverse proxy server receives a HTTP request that originated from the url `http://home.lab`
- The server checks it's configuration for any services that is configured to receive request from `host.lab`
- If this service exist, the server will redirect the traffic to this service
- If it doesn't exist, then it will just return a `404 not found` [HTTP status code](https://http.cat/404)

### Why use Traefik for reverse proxying?

There are three obvious choices for small-scale reverse proxing; [Nginx](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/), [HAProxy](http://www.haproxy.org/) and [Traefik](https://docs.traefik.io/).

[Nginx](https://nginx.org/en/) a popular reverse proxy, known for its high-performance and stability. Many have fiddled with it as a web server before, and it's quite easy to configure as a reverse proxy. The downside is that the freemium version lacks health-checks, JWT authorization, real-time metrics and dynamic reconfiguration without reloads. This is due to F5's commercial offering [Nginx Plus](https://www.nginx.com/products/nginx/).

[HAProxy](https://github.com/jcmoraisjr/haproxy-ingress) is another well known reverse proxy and load balancer. It has DNS based service discovery, soft configuration reload, health checking, tons of detailed metrics, [and more](https://en.wikipedia.org/wiki/HAProxy#Features). It also has a fairly good reputation for [on-premise](https://en.wikipedia.org/wiki/On-premises_software) [Kubernetes](https://kubernetes.io/) clusters, as the developers prioritize optimization, resource efficiency and high speed networking.

[Traefik](https://docs.traefik.io/) is a relatively new (_released 2016_) [edge router](https://docs.traefik.io/), which was created with [microservices](https://en.wikipedia.org/wiki/Microservices) in mind. A key feature in Traefik is [configuration discovery](https://docs.traefik.io/providers/overview/), where Traefik will query a provider API, such as the Docker API, to find relevant information and configure the routing. If you make changes to the configuration or labels on a docker container, it will dynamically update Traefik's routing configuration. [You can read more about this here.](https://docs.traefik.io/providers/overview/)

>Since Docker a the central component in my homelab setup, and the features that are offered out-of-box fits my use-case quite nicely. It just makes sense to use Traefik in my case.

With Traefik, enabling reverse proxying for a application, is as simple as adding three labels to the docker container. If i need more middlewares on a container, like for instance, protecting an app with [SSO authorization](https://auth0.com/blog/what-is-and-how-does-single-sign-on-work/). Then i can just add another label, and Traefik will enable this for that container.

Here are some neat features you get with Traefik:

  - Auto service discovery using the Docker API
  - Changes are reflected in realtime (No manual config reloads needed)
  - Configuration can be written in yaml
  - [Automatic certificate issuing](https://docs.traefik.io/https/acme/) using [LetsEncrypt](https://letsencrypt.org/)
  - [Metrics](https://docs.traefik.io/observability/metrics/overview/) (Prometheus/REST)
  - [Tracing](https://docs.traefik.io/observability/tracing/overview/) (Jaeger/ELK)
  - Supports [TCP](https://docs.traefik.io/routing/services/#configuring-tcp-services)/[UDP](https://docs.traefik.io/routing/services/#configuring-udp-services)
  - Lots of built-in [middleware](https://docs.traefik.io/middlewares/overview/) for tweaking requests before they reach the service. Such as [circuit breakers](https://docs.traefik.io/middlewares/circuitbreaker/), [retry mechanics](https://docs.traefik.io/middlewares/retry/), [rate limiting](https://docs.traefik.io/middlewares/ratelimit/) and [forwardAuth](https://docs.traefik.io/middlewares/forwardauth/) for JWT authorization.

### Create docker network

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
│   ├── acme.json
│   ├── dynamic
│   │   ├── dashboard.yml
│   │   ├── redirect.yml
│   └── traefik.yml
├── docker-compose.yml
```

Next, take a look at the [Traefik Usage](https://fmlab.no/homelab/traefik-usage/) guide, and/or the [PiHole](https://fmlab.no/homelab/pihole/) guide for resolving `.lab` HTTP requests.
