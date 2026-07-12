# Arch Linux Installation

Bare-metal Arch Linux installer with dual-boot support.

## Quickstart

Boot into the official Arch Linux Live ISO, ensure you have an active internet connection, and execute:

> [!TIP]  
> It is strongly recommended to try this installer inside a Virtual Machine (e.g., QEMU/KVM, VMware, VirtualBox) before running it on the target machine.

```bash
curl -fSsL https://raw.githubusercontent.com/riteshraj-shetage/brut-arch/main/install.sh -o install.sh && chmod +x install.sh && ./install.sh
```

**Read the [source code](./install.sh) before running, or execute at your own risk.**

## What's Included

An overview of the base system environment and packages deployed by default.

- **Bootloader:** GRUB (UEFI)
- **Kernel:** `linux`
- **Filesystem:** ext4
- **Swap:** zram (`zstd` compressed, up to 8GB)
- **Network:** NetworkManager (`iwd` backend)
- **Base Packages:** `base`, `base-devel`, `linux`, `linux-headers`, `linux-firmware`, `intel-ucode`
- **Other Packages:** `networkmanager`, `iwd`, `zram-generator`, `grub`, `efibootmgr,` `dosfstools`, `lsof`, `usbutils`, `pciutils`, `pacman-contrib`, `acpid`, `power-profiles-daemon`, `nano`, `git`, `sudo`, `curl`, `wget`, `openssh`, `reflector`, `man-db`

## References

[Official Installation Guide](https://wiki.archlinux.org/title/Installation_guide)
