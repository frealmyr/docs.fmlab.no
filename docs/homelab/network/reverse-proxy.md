## What is reverse proxying?

A reverse proxy server is a server that receives requests and forward them to the appropriate backend services.

Basic example:

- The reverse proxy server receives a HTTP request that originated from the url `http://home.lab`
- The server checks it's configuration for any services that is configured to receive request from `host.lab`
- If this service exist, the server will redirect the traffic to this service
- If it doesn't exist, then it will just return a `404 not found` [HTTP status code](https://http.cat/404)

## Why use Traefik for reverse proxying?

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
