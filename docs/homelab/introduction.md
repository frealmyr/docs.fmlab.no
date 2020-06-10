I made this blog series for those who wish to configure and run a decent homelab, using only a single-node host without any fancy hardware.

Docker containers will be a core component in these series, if you are not familiar with it, and don't how it works on a high level. I would suggest to spend some time reading articles on this topic.

## The Homelab

My homelab configuration is, except from the host, entirely based on docker images. As there is [little overhead](https://domino.research.ibm.com/library/cyberdig.nsf/papers/0929052195DD819C85257D2300681E7B/$File/rc25482.pdf) compared to running software on the host itself.

In my home folder i have a `Homelab` folder and sub-folders with category names, the structure looks like this

```bash
frealmyr@SRV:~$ tree -L 2 -d Homelab/
Homelab/
├── Entertainment
│   ├── jellyfin
│   ├── kiwix
│   ├── minecraft
│   ├── wallabag
├── Office
│   ├── archivebox
│   ├── bookstack
│   ├── homepage
│   ├── homer
│   ├── kanboard
│   ├── kimai
│   ├── miniflux
│   └── simple-portfolio
└── System
    ├── ikevpn
    ├── networks
    ├── openvpn
    ├── pihole
    ├── portainer
    ├── prometheus
    ├── samba
    ├── traefik
    └── watchtower
```

Each stack gets their own folder, with it's own `.env` for local variables and a `docker-compose.yml` file for the docker stack.

```bash
frealmyr@SRV:~$ tree -L 2 -a Homelab/Office/
Homelab/Office/
├── archivebox
│   ├── config
│   ├── data
│   ├── docker-compose.yml
│   └── .env
├── bookstack
│   ├── docker-compose.yml
│   └── .env
├── homepage
│   ├── config
│   ├── docker-compose.yml
│   ├── .env
├── homer
│   ├── config
│   ├── docker-compose.yml
│   └── .env
├── kanboard
│   ├── docker-compose.yml
│   ├── .env
│   └── plugins
├── kimai
│   ├── config
│   ├── create-superuser.sh
│   ├── docker-compose.yml
│   ├── .env
│   └── plugins
├── miniflux
│   ├── docker-compose.yml
│   └── .env
└── simple-portfolio
    ├── config
    ├── docker-compose.yml
    ├── .env
    ├── LICENSE.md
    └── README.md
```

Docker-compose will pick up any `.env` files that resides in the same folder as `docker-compose.yml`, and will make the variables in `.env` available by using `${VAR_NAME}` in the `docker-compose.yml` file.

Docker will also append the folder name as the project name when creating docker resources.

>You can override this by using the `--project-name DESIRED_NAME` argument with `docker-compose` commands. However, it's far easier and more maintainable to just name the folder as the project name.

How does this look in practice?

In the `bookstack` folder i declare the following resources in the `docker-compose.yml`:

```yaml
networks:
  internal:

volumes:
  uploads:
  mysql_data:
  storage_uploads:
```

This will then result in the following docker resources being created:

```bash
frealmyr@SRV:~$ docker volume list | grep bookstack | awk '{print $2}'
bookstack_mysql_data
bookstack_storage_uploads
bookstack_uploads

frealmyr@SRV:~$ docker network list | grep bookstack | awk '{print $2}'
bookstack_internal
```

For easier maintenance of the different stacks, i've created a bash script that can start/stop all of the stacks, with a optional category argument. [The script is available in the Homelab folder.](https://github.com/frealmyr/fmlab.no/blob/master/Homelab/homelab.sh)

### What's running in my Homelab?

In my homelab, i use [pihole](https://github.com/pi-hole/pi-hole) to adblock DNS queries on the LAN, and make use of the [dnsmasq](http://www.thekelleys.org.uk/dnsmasq/doc.html) DNS server in the pihole container to direct any `appname.lab` DNS queries to my server.

For reverse proxy i use [traefik](https://containo.us/traefik/), which can route traffic on my LAN-only domain and/or my FQDN, based on which labels that are set on the docker container.

With the two stack above, i can dynamically create sub-domains in the local `.lab` domain for all my services.

If i wanted to make a transmission instance available for my local network only, i could just add a label to the docker container, which traefik will resolve from `transmission.lab` to the docker container. Any device that are connected to my LAN or VPN can then use this address.

This is way simpler than maintaining a html page with a list of the port numbers whenever i create a new service.

All of the running docker images are kept up to date using [watchtower](https://github.com/containrrr/watchtower), which scans for new docker images periodically, and updates these seamlessly. Watchtower also sends a slack message when it updates the applications.

I also have a monitoring stack with Prometheus, Alertmanager and Grafana. Which gives me a full overview of the current resource utilization, and customized alerting for events. If a harddrive reports bad health over the S.M.A.R.T. protocol, i will get a slack message with the warning shortly afterwards.

In the next pages, i will create a few guides for how to achieve this homelab setup.
