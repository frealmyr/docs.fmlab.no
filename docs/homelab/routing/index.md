# Routing Traffic

In my homelab,

Most services are only available from local network, from a allowlisted subnet.

``` mermaid
graph BT
  subgraph "LAN (10.0.0.0/24)"
  user(client) -->|request| svc[argocd.fmlab.no]
  svc -->|10.8.0.10| server(eth0)
  server --> traefik(traefik-internal)
  traefik -->|response| user;
  end
```

``` mermaid
graph BT
  subgraph "WAN (0.0.0.0/24)"
  user(client) -->|request| svc[argocd.fmlab.no]
  end

  subgraph "LAN (10.0.0.0/24)"
  svc -->|120.110.0.123| server(eth0)
  server --> traefik(traefik-internal)
  traefik -->|response| user;
  end
```
q