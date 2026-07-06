# 1. Install Arch Linux

Install Arch Linux by booting into the interactive live environment and executing the installer script.

## 1.1 Boot into Arch Live

- **Insert Installation Medium:** Plug the installation medium into the target machine and power on (or restart).
- **Select UEFI Boot Device:** Trigger your motherboard's boot menu repeatedly during startup and select the entry explicitly prefixed with **`UEFI:`** or **`EFI`** (e.g., `UEFI: SanDisk Extreme` or `Ventoy (UEFI)`).
- **Launch Arch Linux:** Highlight `Arch Linux install medium (x86_64, UEFI)` (it is usually the top default option) and press `Enter`.

## 1.2 Verify the boot mode

Upon booting the installation medium, you will drop into the default root shell:
`root@archiso ~ #`

To verify that the system has booted in UEFI mode, check the UEFI bitness:

```bash
cat /sys/firmware/efi/fw_platform_size
```

If the command returns `64`, the system is booted in 64-bit UEFI mode. If the file does not exist or returns an error, the system has booted in BIOS/CSM mode. **This installation strictly requires 64-bit UEFI mode.**

## 1.3 Set the console keyboard layout and font

The default console keymap is US (`us`). Available layouts can be listed with `localectl list-keymaps`. To explicitly set or change the keyboard layout, pass its name to `loadkeys`:

```bash
loadkeys us
```

Console fonts are located in `/usr/share/kbd/consolefonts/`. To improve readability and legibility on high-resolution (HiDPI) displays, apply a larger Terminus font:

```bash
setfont ter-v22b
```

---

# 2. Network & System Clock

An active Internet connection is mandatory for fetching official mirrors, synchronizing cryptographic keyrings, and cloning the installer repository.

## 2.1 Connect to the Internet

Identify your wired and wireless network interfaces:

```bash
ip link
```

### Ethernet (Wired)

Wired interfaces use DHCP by default in the live environment and attempt connection automatically upon detection. No manual intervention is necessary.

### Wi-Fi (Wireless)

To connect via Wi-Fi, invoke the `iwctl` interactive daemon:

```bash
iwctl
```

Within the `[iwd]#` interactive prompt, execute the configuration sequence step-by-step:

Identify your wireless device (typically `wlan0`):

```text
[iwd]# device list
```

Initiate a network scan on the device:

```text
[iwd]# station wlan0 scan
```

List available wireless networks detected by the scan:

```text
[iwd]# station wlan0 get-networks
```

Identify the target network name (`SSID`).

Exit the interactive daemon:

```text
[iwd]# exit
```

Connect to the target network (replace `SSID_NAME` and `YOUR_PASSWORD` with your wireless credentials):

```bash
iwctl --passphrase="YOUR_PASSWORD" station wlan0 connect SSID_NAME
```

## 2.2 Verify network connectivity

Validate DNS resolution and outbound packet transmission:

```bash
ping -c 3 archlinux.org
```

## 2.3 Update the system clock

Use `timedatectl` to ensure the system clock is accurate and synchronized via Network Time Protocol (NTP). Accurate system time is critical for SSL/TLS verification and PGP package signature validation:

```bash
timedatectl set-ntp true
```

Verify the system clock synchronization status:

```bash
timedatectl status
```

---

# 3. Installer Script

Once the live environment is verified, connected, and synchronized, manual step is complete. Hand over control to the `brut-arch` interactive installer.

> **CRITICAL WARNING:** The script (install.sh) performs destructive, low-level disk formatting. Back up all critical personal data from your target machine to an external physical drive or cloud storage before running the installer script.

## 3.1 Run the Installer

Install `git`, clone the repository, and run the script:

```bash
# 1. Install git
pacman -Sy --noconfirm git

# 2. Clone the repo
git clone https://github.com/riteshraj-shetage/brut-arch.git

# 3. Make executable and run
cd brut-arch && chmod +x install.sh && ./install.sh
```

## 3.2 One-Line Install (Alternative)

If you prefer to run the installer directly over the network without cloning the repository manually, execute:

```bash
# curl -fSsL https://raw.githubusercontent.com/riteshraj-shetage/brut-arch/main/install.sh | bash
```

**Additional Custom Software:** - When prompted, pass a raw URL to your remote `packages.txt` or input space-separated package names manually (e.g., `wget tmux neovim`) to queue them for installation.

_Note: From this point onward, the [installer](../install.sh) takes complete control over the system installation. Please refer to operational [GUIDE](GUIDE.md) for any help._
