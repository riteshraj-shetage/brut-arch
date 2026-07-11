# Arch Linux Install Medium

Get the official Arch Linux ISO image and write it to your physical installation medium.

## Acquire an ISO image

Visit [https://archlinux.org/download](https://archlinux.org/download) to acquire the official ISO image (`archlinux-version-x86_64.iso`) and its corresponding PGP signature (`.sig`).

## Verify signature

It is strongly recommended to verify the cryptographic signature of the image before use to ensure integrity and authenticity, especially when downloading from HTTP mirrors where traffic is prone to interception.

From an existing Arch Linux host, download both the ISO (`archlinux-version-x86_64.iso`) and the signature file (`archlinux-version-x86_64.iso.sig`) to the same directory and execute:

```bash
pacman-key -v archlinux-version-x86_64.iso.sig
```

Alternatively, from any standard Linux, macOS, or WSL environment, use GnuPG to locate and download the release signing key directly from the Web Key Directory (WKD):

```bash
gpg --auto-key-locate clear,wkd -v --locate-external-key pierre@archlinux.org
```

Once the signing key is imported into your local keyring, verify the ISO image against the signature:

```bash
gpg --verify archlinux-version-x86_64.iso.sig archlinux-version-x86_64.iso
```

_(Note: The output must explicitly confirm a `Good signature from "Pierre Schmitz <pierre@archlinux.org>"`)._

### Quick Integrity Check (Optional)

To verify that the ISO was not corrupted during transmission, validate its cryptographic hash against the official checksum file (`sha256sums.txt`):

```bash
sha256sum -c sha256sums.txt --ignore-missing
```

## Prepare installation medium

To boot the Arch Linux installer, the ISO image must be written to a USB flash drive. Choose one of the following methods based on your host operating system and risk tolerance.

### Option A: Ventoy (Recommended / Best for Multi-Boot)

Ventoy creates a bootable USB drive that allows you to simply copy-paste ISO files without repeatedly re-flashing or destroying existing data on the drive.

1. Download and extract Ventoy from [https://ventoy.net](https://ventoy.net).
2. Run Ventoy2Disk.exe, select your target USB flash drive, and click Install (this wipes the drive).
3. Open your standard file manager and locate the newly created `Ventoy` partition on the USB drive.
4. Drag and drop the verified `archlinux-version-x86_64.iso` file directly onto this partition.
5. Safely eject the drive. When booting from the USB, the Ventoy menu will present the Arch Linux ISO for selection. _(Note: Secure your safety goggles—the default Ventoy menu emits enough lumens to flashbang you at 2 AM)._

### Option B: Rufus (Recommended for Windows Hosts)

Rufus is a reliable, standalone utility for creating bootable USB drives from a Windows workstation.

1. Download Rufus from [https://rufus.ie](https://rufus.ie) and insert your target USB drive.
2. Open the Rufus executable and select your USB flash drive under the **Device** dropdown.
3. Click **SELECT** and locate your verified `archlinux-version-x86_64.iso`.
4. Set partition scheme to `GPT` for modern `UEFI` systems.
5. Leave the rest of the format options (File system: FAT32) as default and click **START**.
6. **CRITICAL STEP:** When prompted with the ISOHybrid image detection warning, select **Write in DD Image mode**. (Using the default ISO Image mode might result in an unbootable installation medium for Arch).
7. Confirm the warning prompt to begin writing and wait for the status to say `Ready`.

### Option C: Native POSIX `dd` (For Advanced Users)

> **WARNING:** The `dd` command performs a destructive, low-level bit-stream write. Selecting the wrong block device will irreversibly destroy your host operating system.

If writing from a Linux or macOS terminal, first identify the exact block device name of your USB drive (e.g., `/dev/sdb` or `/dev/disk2`):

```bash
# On Linux:
lsblk -d -o NAME,SIZE,MODEL

# On macOS:
diskutil list
```

Once the target device path is verified with 100% certainty, execute the direct write. Replace `/My_flash_drive` with your drive identifier (e.g., `/dev/sdb`), **not** a partition number (like `/dev/sdb1`).

```bash
# sudo dd bs=4M if=path/to/archlinux-version-x86_64.iso of=/dev/disk/by-id/usb-My_flash_drive conv=fsync oflag=direct status=progress
```

The bootable installation medium (`Arch Installer`) is now ready.

# Prepare Target Machine

Verify and enforce the following baseline hardware and operating system states before proceeding.

## Firmware & Hardware

- **USB Boot:** `ENABLED`
- **Secure Boot:** `DISABLED`
- **SATA / Storage Controller Mode:** `AHCI` / `NVMe`
- **Boot Mode:** `64-bit UEFI ONLY`

## Windows Host (Dual-Boot)

- **Fast Startup:** `DISABLED`
- **System Hibernation:** `DISABLED`
- **BitLocker Encryption:** `SUSPENDED`

The target machine is now configured and ready to boot from the installation medium.
