# traefik-host (WIP)

A simple configuration for running Traefik as a reverse proxy for other docker containers in a home lab.
Also gives the benefit of easy setup and automatic renewal of Let's Encrypt certificates, for both domain and subdomains.

## Prerequisite:
- You have access to a FQDN
- Subdomains have been added to the FQDN DNS and is active
- Docker and docker-compose is installed
- Ports 80, 8080 and 443 are portforwarded in your network, and FQDN DNS points to your public IP
- Ports are available, and not in use by some other software

Note: If you do not have a FQDN, you can remove port 443 from the configuration files and comment out the `[acme]` block from traefik.toml. This will however limit you to using unecrypted traffic over HTTP.

## How to use:
- Clone repository
- Update traefik.toml with your email, domain and subdomain information for Let's Encrypt certification issuing
- Set the correct permissions for the acme.json file
```bash
chmod 600 acme.json
```
- Create a docker network that will be used for reverse proxy across docker containers:
```bash
docker network create web
```
- Start the docker container
```bash
docker-compose up -d
```
- Visit http://your-domain.com:8080 to check if Traefik is running
- Traefik is now ready to be used

### docker-compose.yml

```yaml
version: '3.5'

networks:
  web:
    external: true
  lab:
    external: true
  monitoring:
    external: true
  internal:
  proxy:

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
      - web
      - lab
      - monitoring
      - internal
      - proxy
    volumes:
      - ./config/traefik.yml:/etc/traefik/traefik.yml
      - ./config/dynamic/:/etc/traefik/dynamic/
      - ./config/acme.json:/etc/traefik/acme/acme.json
    depends_on:
      - docker-proxy
      - traefik-fa
    restart: unless-stopped

  docker-proxy:
    container_name: traefik_docker_proxy
    image: tecnativa/docker-socket-proxy:latest
    networks:
      - internal
    environment:
      - CONTAINERS=1
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped

  traefik-fa:
    container_name: traefik_forward_auth
    image: thomseddon/traefik-forward-auth
    networks:
      - proxy
    environment:
      - CONFIG=/forward.ini
      - LOG_LEVEL=warn
    volumes:
      - ./config/forward.ini:/forward.ini
    labels:
      - traefik.enable=true
      - traefik.backend=traefik-fa
      - traefik.http.services.traefik-fa.loadBalancer.server.port=4181
      # SSL configuration
      - traefik.http.routers.traefik-fa-ssl.entryPoints=https
      - traefik.http.routers.traefik-fa-ssl.rule=host(`auth.example.com`)
      - traefik.http.routers.traefik-fa-ssl.middlewares=sso@file
      - traefik.http.routers.traefik-fa-ssl.tls.certResolver=letsEncrypt
    restart: unless-stopped
```

### traefik.yml

```yaml
entryPoints:
  http:
    address: :80
  https:
    address: :443
  metrics:
    address: :8082

certificatesResolvers:
  letsEncrypt:
    acme:
      email: "your@email.com"
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

metrics:
  prometheus:
    buckets:
      - 0.1
      - 0.3
      - 1.2
      - 5.0
    addEntryPointsLabels: true
    addServicesLabels: true
    entryPoint: metrics
```

# dynamic configs

### dashboard.yml

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


### redirect.yml

```yaml
http:
  routers:
    http:
      entryPoints:
        - http
      middlewares:
        - https_redirect
      rule: HostRegexp(`{host:.+example.com}`)
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
        basicAppAuth:
```

### sso.yml

```yaml
http:
  routers:
    http:
      entryPoints:
        - http
      middlewares:
        - sso
      rule: HostRegexp(`{host:.+example.com}`)
      service: noop

  services:
    noop:
      loadBalancer:
        servers:
          - url: http://10.0.0.5

  middlewares:
    sso:
      forwardAuth:
        address: "http://traefik-fa:4181"
        authResponseHeaders: ["X-Forwarded-User"]
```

```yaml
# Cookie signing nonce, replace this with something random
secret = _SOMETHINGRANDOM_

# Google oAuth application values - you can follow https://rclone.org/drive/#making-your-own-client-id to make your own
providers.google.client-id = _CLIENTID_
providers.google.client-secret = _CLIENTSECRET_

log-level = debug

# Replace demo.carey.li with your own ${TRAEFIK_DOMAIN}
cookie-domain = example.com
auth-host = auth.example.com

# Add authorized users here
whitelist = your@email.com
```
