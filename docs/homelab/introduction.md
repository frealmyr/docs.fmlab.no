This is my blog series dedicated to those who wish to configure and run a decent homelab using only a single-node host without any fancy hardware.

## My current hardware

Everything runs on a single Intel NUC7i3 barebone machine, with the following specs and attached storage.

### Specs

  - Intel Core i3-7100U (0.8GHz-2.40GHz, 3mb Cache)
  - 16GB DDR4-2133MHz
  - Intel I219-LM Gitabit Ethernet
  - Intel Wireless-AC 8265 2x2 WiFi

### Storage

  - SSD: WD Green 480GB M.2
    - Root filesystem
    - Home folder
    - Network share
  - SSD: Intel 520 60GB 2.5" _(Wear sacrifice)_
    - `/var/log`
    - Docker container databases
    - Swap location for `/tmp` (when it runs out of ram)
  - USB: WD MyBook V2 8TB
    - Network share
    - Media location
  - USB: WD MyBook V2 8TB
    - Network share
    - Nightly backups using [rsync](https://linux.die.net/man/1/rsync)
      - Backup of important folders
      - Backup of personal media favorites
    - Backup folders are synced to cloud service

The NUC7i3 have about 40+ docker images running simultaneously.
It runs adblock on all dns traffic using [pihole](https://github.com/pi-hole/pi-hole), stream media over network using [jellyfin](https://github.com/jellyfin/jellyfin), run a full [prometheus](https://github.com/prometheus/prometheus) stack, hosts a few office applications, automatically finds and download media content to HDDs, runs a VR modded minecraft server and plays 4K content to a connected TV using [kodi](https://github.com/xbmc/xbmc) on movie nights.

The NUC can normally handle all of the above, at the same time without any problems. The exception being CPU intensive tasks, such as media transcoding or a highly populated game server.

# The Homelab

My homelab configuration is, except from the host, entirely hosted from docker images. As there is [little overhead](https://domino.research.ibm.com/library/cyberdig.nsf/papers/0929052195DD819C85257D2300681E7B/$File/rc25482.pdf) compared to running software on the host itself.

Every stack gets their own folder, with it's own `.env`  and `docker-compose.yml` file.

I use [pihole](https://github.com/pi-hole/pi-hole) to adblock DNS queries on the LAN, and make use of the [dnsmasq](http://www.thekelleys.org.uk/dnsmasq/doc.html) DNS server in the pihole container to direct any `appname.lab` DNS queries to my server.

For network routing, i use [traefik](https://containo.us/traefik/), which can route traffic on my LAN and to the Internet, based on the labels which are set on the application.

All of the running docker images are kept up to date using [watchtower](https://github.com/containrrr/watchtower), which scans for new docker images periodically, and updates these seamlessly.

There is also a monitoring stack with Prometheus, Alertmanager and Grafana. Which gives me a full overview of the current resource utilization, and customized alerting for events. If a harddrive reports bad health over the S.M.A.R.T. protocol, i will get a slack message with the warning shortly afterwards.

In the next pages, i will create a few guides for how to achieve this homelab setup.
