Which linux flavor and distribution to install on your host, is entirely up to you.

I primarily use Ubuntu based images. So if you decide to use another linux flavor, you might need to change some parts of these series.

Also, we will be using Docker for pretty much everything. Since Docker is host OS agnostic, it does not really matter which OS we use. _Unless_ you go rootless for the docker install, then you should go for a debian-based flavor.

On my homelab server, i use the latest [Kubuntu LTS](https://kubuntu.org/getkubuntu/) image. As [Plasma](https://kde.org/plasma-desktop) is the only desktop environment that I've found to provide good support for high DPI displays.

>I recommend  you to keep the username identical across servers and clients. So that you don't need to provide a username for SSH connections. Since SSH defaults to your local username.

I will also provide a bash script that will do everything described in these series, [which is available here.](https://github.com/frealmyr/fmlab.no/blob/master/Homelab/fresh-install.sh)

## Install SSH server

SSH will be the preferred way for remotely connecting to the host. You can install a SSH server on Ubuntu by running

```bash
sudo apt install ssh
```

>By default, SSH allows password login for the local network, but for connections outside the network it will only allow authorized public keys for authentication.

To allow a new client to connect to the server outside the local network, without providing a password. We can use `ssh-copy-id` to connect to the server and add the remote client's public key

```bash
ssh-copy-id server_user_name@server_ip
```

If you have not yet created a public key for the client you are working from, you can run `ssh-keygen -C "DESIRED_NAME"` to generate a new key. Hit enter a few times, and you should now have a public key.

>If you provide a passphrase upon generation, you will need to provide that passphrase each time that you access the key.

To output the public key on your local client, run the command

```bash
cat ~/.ssh/id_rsa.pub
```

After adding the client's public key to the server, you should now be able to run `ssh server_ip` and you should be logged right in without a password prompt.

## Install Docker

You can install Docker using the stable and proven way with the default root-based install. Which is well documented and can be installed in few steps using the ubuntu package manager.

Or you could choose to install the experimental rootless Docker solution, which runs under a non-root user namespace. I list up the pros and cons for this setup in [the next page](https://fmlab.no/homelab/rootless-docker/).

The main benefit with rootless, is the ability to create users for your containers, which can restrict access to files and folders on the host. And make it harder to gain root access to the host from a exposed container.

If you wish to keep things rock stable using the default way to install, i will refer you to [Digital Ocean's excellent docker guides](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-18-04). You can then skip the next page for rootless docker install.

## Install Docker-compose

There are no extra steps for using `docker-compose` with either rootless or the default docker setup.

`docker-compose` will detect the `DOCKER_HOST` environment variable and connect to the Docker API using this value.

The versions in the Ubuntu LTS repository is often a bit dated, so let's install the newest `docker-compose` binary from the [github project](https://github.com/docker/compose/).

```bash
curl -s https://api.github.com/repos/docker/compose/releases/latest \
  | grep "browser_download_url.*docker-compose-`uname -s`-`uname -m`" \
  | cut -d : -f 2,3 \
  | tr -d \" \
  | wget -qi -

SUMFILE=$(cat docker-compose-Linux-x86_64.sha256 | cut -d ' ' -f 1)
CHECKFILE=$(sha256sum docker-compose-Linux-x86_64 | cut -d ' ' -f 1)

if [ "$CHECKFILE" = "$SUMFILE" ]
then
  sudo mv docker-compose-Linux-x86_64 /usr/local/bin/docker-compose
  rm docker-compose-Linux-x86_64.sha256
  sudo chmod +x /usr/local/bin/docker-compose
fi
```

You should now be able to run `docker-compose version` to see the currently installed version.

