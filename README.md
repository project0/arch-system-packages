# Project0's Arch Linux System Packages

This repository contains my Arch Linux PKGBUILD files and scripts to bootstrap, configure and manage my whole system configuration.
At the end a single host based package bootstraps a whole arch linux installation and can be updated at any time.

> Note: It is not intended to cover user based configuration. A typical dotfiles approach is better suited for this case. You can use [dotbot](https://github.com/anishathalye/dotbot) for example.

## Packages

The project split into several parts and leverage Make targets to build the final packages and pacman repo.

```bash
# build all packages
make all
# cleanup repo (dist/) and temp files
make clean

# build all packages
make packages

# build only specific package groups
make pkgbuild/system/*
make pkgbuild/packages/*
# build the aur hosted packages defined in Makefile
make aur

# build specific package and update repo db
# todo: find better approach to wire this automatically
make pkgbuild/system/<name> update-db/system
make pkgbuild/packages/<name> update-db/packages
# build a arbitrary AUR hosted package
make pkgbuild/aur/<name> update-db/aur
```

### System

The system packages covers all the customizations, configurations and package dependencies to install.

It contains the following PKGBUILDs (what may create multiple packages):

**project0-base-{helper,packages,configs}**: Shared base packages, systemd wide configurations and helper scripts or hooks for further usage.

**project0-cryptsetup**: Cryptsetup configurations and scripts to automate decryption on boot wit TPM.

**project0-refind{,-secureboot}**: Refind (EFI boot manager) configurations and scripts to automate configuration updates with optional secureboot signing.

**project0-desktop{,-aur,gnome}**: Provides packages to installs and configures desktops (gnome) and applications.

**project0-host-<hostname>**: Bundles all required packages and dependencies together per host. May add specific host based configs.

## Install a new machine

The whole point of the system package is actually to avoid any manual configuration and directly boot into the system on first boot. However, some steps still needs to be proceed, so everything is scripted to automate or at least print guidance (set passwords).

Serve the local repo, so it becomes accessible for remote installation. It will show further instructions for retrieve the scripts and how to start the arch linux installation:

```bash
make run-local
```

- **bin/disk.sh </dev/disk-device> <true\false=enable-encrypt?>**: A script to initialize and prepare a disk with "best practice" partitions on fresh machine. Optional encryption parameter enables cryptsetup on the disk.
- **bin/install.sh**: A script to install arch linux on a fresh machine. Basically just install the package `project0-host-<hostname>` from repo.

## References

- [alpm-hooks - Trigger actions based on pacman transactions](https://man.archlinux.org/man/alpm-hooks.5)

### Similar projects

- [Foxboron PKGBUILD](https://github.com/Foxboron/PKGBUILDS/tree/master/foxboron-system): I have been highly inspired by this project.
