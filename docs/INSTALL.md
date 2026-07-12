# Install Arch Linux

Install Arch Linux by booting into the interactive live environment and executing the installer script.

## Boot into Arch Live

1. **Insert & Power On:** Plug in your installation medium and boot the target machine.
2. **Select UEFI Boot:** Trigger your motherboard's boot menu and explicitly select the drive prefixed with **`UEFI:`** or **`EFI`** (e.g., UEFI: SanDisk Extreme or Ventoy (UEFI)).
3. **Launch Arch Linux:** Select `Arch Linux install medium (x86_64, UEFI)` (default top option) and press `Enter`.

## Verify the Boot Mode

Upon booting into `root@archiso ~ #`, verify that the system is running in 64-bit UEFI mode (**strictly required** for this installation):

```bash
# Check UEFI bitness (must output '64'; an error or missing file indicates unsupported BIOS/CSM mode)
cat /sys/firmware/efi/fw_platform_size
```

## Set Console Keyboard Layout and Font

Configure the keyboard layout and apply a larger font for readability on HiDPI displays:

```bash
# 1. Set console keymap (default is US; list alternatives using 'localectl list-keymaps')
loadkeys us

# 2. Apply a larger Terminus font from /usr/share/kbd/consolefonts/ for improved legibility
setfont ter-v22b

```

---

# Network & System Clock

Internet access is required to synchronize system packages, keyrings, and installation files.

## Connect to the Internet

Identify your wired and wireless network interfaces:

```bash
ip link
```

### Ethernet (Wired)

Wired interfaces use DHCP by default in the live environment and attempt connection automatically upon detection. No manual intervention is necessary.

### Wi-Fi (Wireless)

Scan and connect using `iwctl` commands (replace `SSID_NAME` and `WIFI_PASSWORD`):

```bash
# 1. Identify wireless device (e.g., wlan0)
iwctl device list

# 2. Initiate network scan
iwctl station wlan0 scan

# 3. List available SSIDs
iwctl station wlan0 get-networks

# 4. Connect to target network
iwctl --passphrase='WIFI_PASSWORD' station wlan0 connect SSID_NAME

# 5. Verify network connectivity
ping -c 3 archlinux.org
```

_Troubleshooting: If your device scan returns nothing or shows the adapter as powered off, run the following commands -_

```bash
# 1. Clear software radio locks and power on interface
rfkill unblock wlan && iwctl device wlan0 set-property Powered on

# 2. Verify device state (look for 'Powered: on')
iwctl device wlan0 show
```

## Update the System Clock

Synchronize the system clock via NTP (critical for preventing PGP and SSL/TLS validation errors during package downloads):

```bash
# 1. Enable Network Time Protocol (NTP) synchronization
timedatectl set-ntp true

# 2. Verify synchronization status (look for 'NTP service: active')
timedatectl status
```

---

# Run the Installer

Once the live environment is verified, connected, and synchronized, manual step is complete. Hand over control to the `brut-arch` interactive installer.

> [!CAUTION]  
> The script _install.sh_ performs destructive, low-level disk formatting. Back up all critical personal data from your target machine to an external physical drive or cloud storage before running the installer script.

## Clone and Run

Install `git`, clone the repository, and run the script:

```bash
# 1. Install git
pacman -Sy --noconfirm git

# 2. Clone the repo
git clone --depth 1 https://github.com/riteshraj-shetage/brut-arch.git

# 3. Make executable and run
cd brut-arch && chmod +x install.sh && ./install.sh
```

## Remote Execution (Alternative)

If you prefer to run the installer directly over the network without cloning the repository manually, execute:

```bash
# curl -fSsL https://raw.githubusercontent.com/riteshraj-shetage/brut-arch/main/install.sh -o install.sh && chmod +x install.sh && ./install.sh
```

**Additional Custom Software:** When prompted, pass a raw URL to your remote `packages.txt` or input space-separated package names manually (e.g., `wget tmux neovim`) to queue them for installation.

_Note: From this point onward, the [installer](../install.sh) takes complete control over the system installation. Please refer to operational [GUIDE](GUIDE.md) for any help._
