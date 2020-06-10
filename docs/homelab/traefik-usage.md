### Use Case 1: Local lab network only

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

### Use Case 2: Accessible from the internet

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

### Use Case 3: Both accessible from local network and the Internet

In some cases, you might want to have a application available from both networks. If you do this, keep in mind that this application is now a bridge between `lab` and `web`, and should be secured from outside the network. 

We can now merge both the examples above, with some changes

```bash
# Project
PROJECT=home
LAN_DOMAIN=lab
WEB_DOMAIN=yourdomain.com
PORT=80
```

```yaml
version: '3.5'

networks:
  lab:
    external: true
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
      - lab
      - web
    labels:
      - traefik.enable=true
      - traefik.http.routers.${PROJECT}.rule=Host(`${PROJECT}.${WEB_DOMAIN}`)
      - traefik.http.routers.${PROJECT}.entryPoints=https
      - traefik.http.routers.${PROJECT}.tls.certresolver=letsEncrypt
      - traefik.http.services.${PROJECT}.loadbalancer.server.port=${PORT}
      - traefik.http.routers.${PROJECT}_lab.rule=Host(`${PROJECT}.${LAB_DOMAIN}`)
      - traefik.http.routers.${PROJECT}_lab.entryPoints=http
      - traefik.http.services.${PROJECT}_lab.loadbalancer.server.port=${PORT}
```

| Line | Description   |
| :--------------- | :------ |
| L3:L7 | We now want to make use of both the `lab` and `web` networks |
| L16:L18 | Both networks will be mounted by the container |
| L20 | In `traefik.yaml` we have set `exposedbydefault: false`, so we need to enable Traefik for this application |
| L21:L24 | This is the configuration for the **HTTPS** endpoint, which is available from the Internet. |
| L25:L27 | And this is the local network **HTTP** endpoint, take notice of the `${PROJECT}_lab` suffix. This is needed for seperating the two Traefik router configurations, or else one will simple overwrite the other. |
