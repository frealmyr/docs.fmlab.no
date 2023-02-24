# Dotfiles

I make use of a bare git repository for my dotfiles, which is a git repository without a working tree and copies of checked out files.

This results in the possibility to have a folder named `~/.dotfiles`, which keeps track of only my committed configuration files in my home folder, without any hacky symlinks.

Basically, this allows me to make my home folder a git repository, where I only keep track of checked in files, ignoring untracked files when using git commands.

I make use of a alias for managing the dotfiles

```bash
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
```

### Example commands

Downloading the latest commit

```bash
dotfiles pull
```

Using a different branch for dotfiles

```bash
dotfiles checkout x11/i3
```

Add / edit files, then push commit to dotfiles repository

```bash
dotfiles status
dotfiles add .vimrc
dotfiles commit -m "add vimrc"
dotfiles push origin wayland/sway
```

### Use ssh instead of https

> Ansible playbooks configures my dotfiles with https by default. Due to my new ssh key is not present in github during setup.

```bash
dotfiles remote set-url origin git@github.com:frealmyr/dotfiles-configs.git
```
