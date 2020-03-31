This guide was written for Ubuntu and its derivatives. If you use a different operating system, then you might need to change some parts.

Personally i use the latest [Kubuntu LTS](https://kubuntu.org/getkubuntu/) image. As [Plasma](https://kde.org/plasma-desktop) provides a polished classic desktop experience, with no screen tearing, while scaling well on high DPI displays.

You can setup the operating system according to your own preferences, but i encurage you to keep the username identical across servers and clients. So that you don't need to provide a username for SSH connections as SSH defaults to your local username.

I also have provided a bash script that will do everything described in this guide, [which is available this repository.]()

## SSH

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

## Standard docker with root

If you wish to run the tested and proven way of installing Docker on Ubuntu, i will refer you to [DigitalOcean's install guide](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-18-04).

## Rootless docker

The default way to install docker is to grab the latest debian package and install it on your host using your _root_ user. Docker will then run the daemon, containers and volumes as _root_.

![ ](\homelab\images\sandwich.png#center)

If a container is configured without any security measures and is running as root while it's publicly available. It could be a potential attack vector for gaining [root access to the underlying host operating system](https://blog.trailofbits.com/2019/07/19/understanding-docker-container-escapes/).

>In general, one should not run applications as root. Instead make the applications run under dedicated users and/or groups.

With these things in mind, i've recently been trying out the experimental [rootless docker mode](https://docs.docker.com/engine/security/rootless/). Where the concept is to execute the Docker daemon and containers inside a user namespace, instead of running everything as root.

There are however [some limitations while going rootless](https://docs.docker.com/engine/security/rootless/#known-limitations), as the following features are not supported:

- [AppArmor](https://cloud.google.com/container-optimized-os/docs/how-to/secure-apparmor)
- [Checkpoint (Experimental)](https://docs.docker.com/engine/reference/commandline/checkpoint/)
- [Overlay network](https://docs.docker.com/network/overlay/)
- Exposing [SCTP ports](https://en.wikipedia.org/wiki/Stream_Control_Transmission_Protocol)
- [Cgroups](https://docs.docker.com/config/containers/resource_constraints/) (including `docker top`, which depends on the cgroups)
- Non-debian based OS only supports [vfs graphdriver](https://docs.docker.com/storage/storagedriver/select-storage-driver/) which is considered suboptimal for many filesystems.

One advantage to rootless, is the ability to run docker containers inside a user namespace. Which means that you can in theory create dedicated users or groups for docker containers and make use of the host systems UIDs/GIDs for restricting access to files and features.

The rootless Docker mode is still in a experimental stage. While it works rather flawlessly on my system, some breaking bugs might arise in the future.

Earlier issues like low network throughput [has been fixed](https://github.com/AkihiroSuda/libpod/commit/da7595a69fc15d131c9d8123d0a165bdde4232b6), so if you decide to use rootless Docker, please report any bugs or issues that you might have discovered to the relevant repositories.

### Installing rootless docker

First we need to install the dependency `uidmap` which is needed to allow multiple UIDs/GIDs to be used in the user namespace.

```bash
sudo apt update && sudo apt install -f curl uidmap
```

Now we can fetch and install the latest stable release of the rootless install script.

```bash
curl -fsSL https://get.docker.com/rootless | sh
```

When the install script finishes, the output will provide some environment variable exports that will be needed by the docker-cli for connecting to the rootless docker daemon.

If you run `cat ~/.profile`, you can see that Ubuntu automatically adds `${HOME}/bin` to $PATH if the folder exists. So there is no need to add this to path manually.

So we only need to add the `DOCKER_HOST` environment variable to our profile.

```bash
echo "export DOCKER_HOST=unix:///run/user/1000/docker.sock" >> ~/.profile
```

Now run `source ~/.profile` to refresh the environment variables.

#### Starting the rootless docker daemon

If you now try to run `docker ps`, it should result in a error as the docker daemon is not running.

To start rootless docker use the following command

```bash
systemctl --user start docker
```

You can now try to run `docker run hello-world` to test if Docker is working properly.

#### Enable rootless docker on boot

After you have made sure that Docker is working normally, you can run the following command to start rootless Docker on boot

```bash
systemctl --user enable docker
```

#### Allowing binding of privileged ports

By default on most GNU/Linux distrobutions, ports under `1000` are privileged and requires root access for changes. We can however allow the [rootlesskit](https://github.com/rootless-containers/rootlesskit) binary to bind privileged ports by running this command:

```bash
sudo setcap cap_net_bind_service=ep $HOME/bin/rootlesskit
```

>This will require a restart before the changes takes effect, applications which tries to bind privileged ports before restarting will return odd error messages.

### Installing docker-compose

There are no extra steps for using `docker-compose` with a rootless docker setup. `docker-compose` will detect the `DOCKER_HOST` environment variable and connect to the Docker API using this value.

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
