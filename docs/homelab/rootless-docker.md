The default way to install docker is to grab the latest debian package and install it on your host using your _root_ user. Docker will then run the daemon, containers, volumes and everything else as _root_.

![ ](\homelab\images\sandwich.png#center)

>If a container is configured without any security measures and is running as root while it's publicly available. It could be a potential attack vector for gaining [root access to the underlying host operating system](https://blog.trailofbits.com/2019/07/19/understanding-docker-container-escapes/).

With these things in mind, i've recently been trying out the experimental [rootless docker mode](https://docs.docker.com/engine/security/rootless/). Where the concept is to execute the Docker daemon and containers inside a user namespace, instead of running everything as root.

There are however [some limitations while going rootless](https://docs.docker.com/engine/security/rootless/#known-limitations), as the following features are not supported:

- [AppArmor](https://cloud.google.com/container-optimized-os/docs/how-to/secure-apparmor)
- [Checkpoint (Experimental)](https://docs.docker.com/engine/reference/commandline/checkpoint/)
- [Overlay network driver](https://docs.docker.com/network/overlay/)
- Exposing [SCTP ports](https://en.wikipedia.org/wiki/Stream_Control_Transmission_Protocol)
- [Cgroups](https://docs.docker.com/config/containers/resource_constraints/) (hardware limits, `docker top`)
- Non-debian based OS only supports [vfs graphdriver](https://docs.docker.com/storage/storagedriver/select-storage-driver/) which is considered suboptimal for many filesystems. (Overlay2 out-of-the-box on Ubuntu)

One key advantage to rootless, is the ability to run docker containers inside a user namespace. Which means that you can in theory create dedicated users or groups for docker containers and make use of the host systems UIDs/GIDs for restricting access to files and features.

The rootless Docker mode is still in a experimental stage. While it works rather well on my system, some bugs might arise in the future.

>Earlier issues like low network throughput [has been fixed](https://github.com/AkihiroSuda/libpod/commit/da7595a69fc15d131c9d8123d0a165bdde4232b6), so if you decide to use rootless Docker, please report any bugs or issues that you might have discovered to the relevant repositories.

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

### Enable rootless docker on boot

After you have made sure that Docker is working normally, you can run the following command to start rootless Docker on boot

```bash
systemctl --user enable docker
```

### Allowing binding of privileged ports

By default on most GNU/Linux distrobutions, ports under `1000` are privileged and requires root access for changes. We can however allow the [rootlesskit](https://github.com/rootless-containers/rootlesskit) binary to bind privileged ports by running this command:

```bash
sudo setcap cap_net_bind_service=ep $HOME/bin/rootlesskit
```

>This will require a restart before the changes takes effect, applications which tries to bind privileged ports before restarting will return odd error messages.

### Create dedicated user/group for containers

Create a group called `homelab` with the gid `1001`:

```bash
sudo groupadd -g 1001 homelab
```

Create a user called `docker` with the uid `1001`, without any home directory:

```bash
sudo useradd -s /bin/bash -u 1001 -M -g homelab docker
```

You can verify that the user and group is created with the `1001` id, by running:

```bash
grep homelab /etc/group
cat /etc/passwd | grep docker
```

We can now use `1001:1001` when starting a docker container, to make the system inside use the provided GID/UID. Which will on the host, will be translated as the user `docker` in the `homelab` group. Making it possible to restrict its access to files and folders.


### "Too many open files" Workaround

While i was converting to rootless docker, i only had a few containers running for trying out the setup. But after trying to run my whole homelab stack in rootless, i started to see some errors related to the host's security limits.

After some debugging i noticed the following limit in the `dockerd` process:

```bash
frealmyr@SRV:~$ ps aux | grep "dockerd --experimental"
frealmyr  1225  7.9  0.4 1829280 74712 ? Sl 14:46 0:08 dockerd --experimental --storage-driver=overlay2

frealmyr@SRV:~$ cat /proc/1242/limits | grep "Max open files"
Max open files 4096 4096 files
```

This output tells us that `dockerd` process will only be allowed to have a maximum of `4096` simultaneously open files at all times. Add a few web servers and databases, and we will blast past that limit in no time, where we will end up with these kinds of errors:

```bash
homelab: now starting Office//homer/
Starting homer ... error

ERROR: for homer  Cannot start service homer: failed to start shim: fork/exec /home/frealmyr/bin/containerd-shim: too many open files: unknown

ERROR: for homer  Cannot start service homer: failed to start shim: fork/exec /home/frealmyr/bin/containerd-shim: too many open files: unknown
ERROR: Encountered errors while bringing up the project.

homelab: now starting Office//kanboard/
Starting kanboard_db ... error

ERROR: for kanboard_db  Cannot start service postgres: failed to start shim: fork/exec /home/frealmyr/bin/containerd-shim: too many open files: unknown

ERROR: for postgres  Cannot start service postgres: failed to start shim: fork/exec /home/frealmyr/bin/containerd-shim: too many open files: unknown
ERROR: Encountered errors while bringing up the project.
```

What we are affected by here, is the kernel security configuration for [user limits](https://ss64.com/bash/ulimit.html). Where the limit for "Max open files", is way too low for running multiple docker containers under a normal user.

There are two limits, one soft that the user can decrease and one hard which sets the upper limit for the user. You can check the default limits for systemd processes by running:

```bash
frealmyr@SRV:~$ systemctl --user show foobar | grep LimitNOFILE
LimitNOFILE=4096
LimitNOFILESoft=4096
```

Since that is too low for our purpose, let's increase the default limit for our systemd processes. Edit the `/etc/systemd/system.conf` file with root privileges, uncomment and update the following line:

```bash
DefaultLimitNOFILE=100000
```

After a reboot. You can now try to run the previous command, where you should see that the default limits for number of open files have increased to `100000`:

```bash
frealmyr@SRV:~$ systemctl --user show foobar | grep LimitNOFILE
LimitNOFILE=100000
LimitNOFILESoft=100000
```

Since the `docker.service` file have `infinity` defined for the limits in the service config, it should now have default `100000` as the limit. Which should be more than enough for a large Homelab setup.

```bash
frealmyr@SRV:~$ cat ${HOME}/.config/systemd/user/docker.service | grep LimitNOFILE
LimitNOFILE=infinity

frealmyr@SRV:~$ cat /proc/$(ps aux | grep "dockerd --experimental" | head -n1 | awk '{print $2}')/limits | grep "Max open files"
Max open files 100000 100000 files
```

You can read more about the systemd limits here: https://www.freedesktop.org/software/systemd/man/systemd.exec.html#Process%20Properties