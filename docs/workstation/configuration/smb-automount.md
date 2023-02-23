# SMB auto-mount

Mounting SMB automatically on a Unix system is not-so-forward, navigating posts from stackoverflow and forums will most likely result in trying out old and deprecated solutions.

Here are my experiences with mounting samba shares:

  - `cifs` is the newer implementation for the smb proctocol in the kernel. The older `smbfs` is deprecated, without any maintainers and is only available due to backwards compability.
  - Credentials for `cifs` basically requires a plaintext file containing `username=` and `password=` which is referenced during mount, which is truly horrifying security wise.
    - Creating a file at `/root/.smbcredentials` with `chmod 0600` permissions is as secure as it gets.
    - If you got a better alternative, please reach out.
  - Kerberos does not look like a sane solution for single-users.
  - `autofs` is deprecated and superseeded by the `systemd` module `remote-fs`.
  - Be careful mounting remote locations in `/etc/stab`, as they will not work when you are not in your local network. In worst case, it will make your computer panic during boot.
  - Follow principle of least privilege, create a seperate user on the smb server with access to only the folders that you are going to mount.

Here is a example of a line I use in `/etc/fstab`

```bash
//nas.fmlab.no/media  /mnt/nas/media  cifs  _netdev,vers=3,x-systemd.automount,x-systemd.idle-timeout=15min,rw,dir_mode=0775,file_mode=0664,iocharset=utf8,uid=fredrick,gid=users,credentials=/root/.smbcredentials 0 0
```

Breakdown of the flags used:

| Flag | Description |
|---|---|
|_netdev | wait for networking service to start before attempting this mount |
| vers=3 | use SMBv3.0 protocol version and above |
| x-systemd.automount | establish remote connection to share and mount only when local directory is accessed |
| x-systemd.idle-timeout=15min | unmount share if the local directory has not been accessed for over x minutes |
| rw | enable read-write access on remote share |
| dir_mode=0775 | default directory permission |
| file_mode=0664 | default file permission |
| iocharset=utf8 | allows access to files with names in non-English languages |
| uid=fredrick | makes the user owner of the mounted share |
| gid=users | makes the group owner of the mounted share |
| credentials=/root/.smbcredentials | path to credentials file which contains lines with `username=` and `password=`, can be stored in home dir, recommend permission `600` on file for security. |

This requires a credentials file stored in `/root` containing your smb credentials

```bash
sudo tee /root/.smbcredentials > /dev/null <<EOT
username=
password=
EOT
```

Set the permission to `0600` so that only root can access it

```bash
sudo chmod 0600 /root/.smbcredentials
```

To reload entries in `/etc/fstab`, run the following command

```bash
sudo systemctl daemon-reload && sudo systemctl restart remote-fs.target
```

> We don't need to use `mount -a`, as systemd will automatically mount the remote folder when you access the local folder, the command will work, but systemd will unmount the folder when the idle-timeout for the share is activated.

You should now be able to see the files from the remote share in the local folder you specified in `/etc/fstab`, such as navigating to `/mnt/nas/media` in the example above.

## Debugging

The following command will monitor kernel logs, where CIFS errors should be present

```bash
dmesg -w
```

Errors here can be a bit cryptic. I found out that error `-13` can be a indicator for a credentials file misconfiguration,.

After making changes to `/etc/fstab` or the credentials file, restart the systemd component for remote-fs

```bash
sudo systemctl daemon-reload && sudo systemctl restart remote-fs.target
```

If all is well, `dmesg` should output the following

```bash
[   35.934212] Key type dns_resolver registered
[   36.015220] Key type cifs.spnego registered
[   36.015231] Key type cifs.idmap registered
[   36.015848] CIFS: Attempting to mount \\nas.fmlab.no\media
```
