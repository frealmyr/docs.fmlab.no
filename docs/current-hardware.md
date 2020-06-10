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

The NUC7i3 have around 40+ docker images running simultaneously.
It runs adblock on all dns traffic using [pihole](https://github.com/pi-hole/pi-hole), stream media over network using [jellyfin](https://github.com/jellyfin/jellyfin), run a [prometheus](https://github.com/prometheus/prometheus) & [grafana](https://github.com/grafana/grafana) stack, hosts a few office applications, automatically finds and download media content to HDDs, runs a VR modded minecraft server and plays 4K content to a connected TV using [kodi](https://github.com/xbmc/xbmc) on movie nights.

The NUC can normally handle all of the above, at the same time without any problems. The exception being CPU intensive tasks, such as media transcoding or a highly populated game servers.
