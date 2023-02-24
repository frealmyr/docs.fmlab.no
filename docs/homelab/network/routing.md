I make use of `netplan` label functionallity for my ethernet adapter so that it can listen on two IP addresses. These two IP addresses are dedicated to public and private traffic.

You can listen on multiple IP addresses, using only two is not a limt just a preference for my use-case, I tested up to 8 which worked fine. [You can read more about this in the netplan docs.](https://netplan.io/examples#using-multiple-addresses-on-a-single-interface)

You can check out my configuration for this here: [k8s-0-static-ip.yml](https://github.com/frealmyr/homelab/blob/main/ansible/playbooks/k8s-0-static-ip.yml#L24-L28)

> I also have a second network adapter installed in my server, but this is used strictly for management of the server with its own VLAN. Useful as a fallback for when I play with networking remotely without locking myself out.

### LAN

Most of the services I host are only available from local network, with firewall rules in place for allow-listed subnets.

``` mermaid
graph RL
  subgraph WAN ["WAN (0.0.0.0/24)"]
  user((client)) -->|request| svc[argocd.fmlab.no]
  end

  subgraph LAN [LAN 10.0.0.0/24]
  svc -->|CNAME<br/>10.8.0.10| server[/enp3s0:private<br/>10.8.0.10\]
  server --> traefik(traefik-internal)
  traefik -->|response| user;
  end


  style LAN fill:#282a36
  style WAN fill:#282a36
  style user fill:#6272a4;
  linkStyle 0 stroke:green;
  linkStyle 1 stroke:green;
  linkStyle 2 stroke:green;
  linkStyle 3 stroke:yellow;
```

For accessing these services outside my network, I use Wireguard VPN.

### WAN

A few services is available from WAN, these services gets their own DNS CNAME Records which points to my external IP.

``` mermaid
graph RL
  subgraph WAN ["WAN (0.0.0.0/24)"]
  user((client)) -->|request| svc[argocd.fmlab.no]
  end

  subgraph LAN ["LAN (10.0.0.0/24)"]
  svc -->|CNAME<br/>120.110.0.123| router["Router<br/>TP-Link R605"]
  router -->|"Port-forward"| server[/enp3s0:public<br/>10.8.0.11\]
  server --> traefik(traefik-external)
  traefik -->|response| user;
  end

  style LAN fill:#282a36
  style WAN fill:#282a36
  style user fill:#6272a4;
  linkStyle 0 stroke:green;
  linkStyle 1 stroke:green;
  linkStyle 2 stroke:green;
  linkStyle 3 stroke:yellow;
  linkStyle 4 stroke:yellow;
```

These services have a CNAME record which points to my public ip, my router port-forwards this traffic to the public network adapter on my server.
The public traefik instance then reverse-proxy the request based on the requested sub-domain.
