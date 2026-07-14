<h1>
  Base <a href=https://www.archlinux.org/>Arch Linux</a> Installer
</h1>

[![Shell Linting](https://img.shields.io/github/actions/workflow/status/riteshraj-shetage/brut-arch/shellcheck.yml?style=flat-square&label=ShellCheck&labelColor=101010&color=1793d1&logo=gnubash&logoColor=white)](https://github.com/riteshraj-shetage/brut-arch/actions/workflows/shellcheck.yml)

_Bare-metal Arch Linux installer with dual-boot support_

## Quickstart

Boot into the official [Arch Linux Live ISO](https://archlinux.org/download/), ensure you have an active internet connection, and execute:

> [!TIP]  
> It is strongly recommended to try this installer inside a Virtual Machine (e.g., QEMU/KVM, VMware, VirtualBox) before running it on the target machine.

```bash
curl -fSsL https://raw.githubusercontent.com/riteshraj-shetage/brut-arch/main/install.sh -o install.sh && chmod +x install.sh && ./install.sh
```

**Read the [source code](./install.sh) before running, or execute at your own risk.**

## What's Included

An overview of the base system environment and packages deployed by default.

| Component        | Specification / Defaults                   |
| :--------------- | :----------------------------------------- |
| **Bootloader**   | GRUB (automated `os-prober` for dual-boot) |
| **Kernel**       | `linux` (with `intel-ucode`)               |
| **Filesystem**   | ext4                                       |
| **Partitioning** | EFI (1G) + Root (40G) + Home               |
| **Swap**         | zram (`zstd` compressed, up to 8GB)        |
| **Network**      | NetworkManager (`iwd` backend)             |
| **User**         | Single user with `sudo` access             |
| **Locale**       | `en_US.UTF-8`                              |
| **Audio**        | None                                       |
| **Graphics**     | None                                       |
| **Shell**        | `bash` default                             |
| **Pacman**       | Parallel downloads enabled (`pacman.conf`) |

### Package Manifest

- **Base Packages:** `base`, `base-devel`, `linux`, `linux-headers`, `linux-firmware`, `intel-ucode`
- **Other Packages:** `networkmanager`, `iwd`, `zram-generator`, `grub`, `efibootmgr`, `dosfstools`, `lsof`, `usbutils`, `pciutils`, `pacman-contrib`, `acpid`, `power-profiles-daemon`, `nano`, `git`, `sudo`, `curl`, `wget`, `openssh`, `reflector`, `man-db`
- **Extra Packages:** Default [`packages.txt`](./packages.txt) / Remote URL / Manual add-ons
- **Total Payload:** Less than `1GB` (~2GB Total Installed size) with default package selection

> The complete Base Arch Linux Installation typically takes **~10 minutes** with the default package selection on a standard broadband connection.

## References

[Official Installation Guide](https://wiki.archlinux.org/title/Installation_guide)
