I recommend you to get yourself a cheap domain name for personal use, it will make visiting your hosted applications a lot easier. I use Cloudflare as my dns provider since they got a solid API.

The domain itself is bought elsewhere, but I have moved the dns management over to Cloudflare.

I have a CNAME record for `*.fmlab.no`, which is a wildcard for all sub-domain requests that points to my internal IP for the server. If I want to override this for a service, I can simply create a new CNAME record for `whatever.fmlab.no` to override for single instances.

My Cloudflare dashboard looks like this

![](\assets\images\homelab\cloudflare-dashboard.png#center)

- A Record `server` is the private ip address, `traefik-internal` handles reverse-proxy. This value is hardcoded.
- CNAME Record `*` is a wildcard record which points to A Record `server`, if a record for sub-domain does not exist, this wildcard is used.
- A Record `vpn` is the public ip, `traefik-external` handles reverse-proxy. This value is automatically updated by [cloudflare-ddns](https://hub.docker.com/r/oznu/cloudflare-ddns/).
- CNAME Record `photos` points to the A Record `vpn`, this record is managed by [external-dns](https://github.com/kubernetes-sigs/external-dns).
