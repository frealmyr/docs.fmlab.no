# Network

In my homelab, most of the services I host are for personal use and only available from LAN.

There are also a few services that I want available from WAN, such as a [public photo gallery](https://photos.fmlab.no), and for those I have a seperate traefik instance dedicated for public access.

One of my goals for the homelab, is to have a somewhat production-grade cluster running, so having my public ip in a domain record should not be an issue as long as my configuration is solid.

> I did not want to use Cloudflare tunnel, as that service is for hosting low-bandwith services, where they clearly state in the ToS that tunneling media such as photos/video is forbidden. Makes sense that they don't want to tunnel petabytes of randoms Plex instances, just because they want their public ip proxied. (They leave their public ip all over they place when they surf the net anyway).
