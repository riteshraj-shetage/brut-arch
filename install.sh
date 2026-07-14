#!/bin/bash
# source: https://raw.githubusercontent.com/riteshraj-shetage/brut-arch/main/install.sh

set -euo pipefail

# --- COLOR FORMATTING ---
BOLD="\033[1m"
RED="\033[1;31m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
RESET="\033[0m"

log_info()    { echo -e "${BLUE}[*]${RESET} ${BOLD}$1${RESET}"; }
log_success() { echo -e "${GREEN}[+]${RESET} ${BOLD}$1${RESET}"; }
log_warn()    { echo -e "${YELLOW}[!]${RESET} ${BOLD}$1${RESET}"; }
log_error()   { echo -e "${RED}[x]${RESET} ${BOLD}$1${RESET}"; }

# --- BANNER DISPLAY ---
show_banner() {
    clear
    echo -e "${BOLD}==================================================${RESET}"
    echo -e "${BOLD}            BRUT ARCH LINUX INSTALLER             ${RESET}"
    echo -e "${BOLD}==================================================${RESET}\n"
}

# --- RETRY HELPER ---
retry() {
    local n=1
    until "$@"; do
        if (( n >= 3 )); then
            log_error "Command failed after 3 attempts: $*"
            return 1
        fi
        log_warn "Command failed. Retrying ($n/3)..."
        rm -f /var/lib/pacman/db.lck /mnt/var/lib/pacman/db.lck 2>/dev/null || true
        sleep 2
        ((n++))
    done
}

# --- PRE-RUN SAFETY CHECKS ---
if [[ ! -f /etc/arch-release ]]; then
   log_error "This installer must be run from an Arch Linux environment."
   exit 1
fi

if [[ $EUID -ne 0 ]]; then
   log_error "This script must be executed as root."
   exit 1
fi

if [[ ! -d "/sys/firmware/efi/efivars" ]]; then
    log_error "UEFI environment not detected. This script requires UEFI mode."
    exit 1
fi

if [[ -f "${BASH_SOURCE[0]:-}" ]]; then
    REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    REPO_DIR="$PWD"
fi

show_banner

# --- MANUAL CONFIGURATION ---
log_info "Configure system identity:"
read -rp "Enter Hostname [default: archlinux]: " INPUT_HOST
HOSTNAME="${INPUT_HOST:-archlinux}"

read -rp "Enter Target Username [default: arch]: " INPUT_USER
TARGET_USER="${INPUT_USER:-arch}"

# --- SYSTEM CONFIGS (Defaults) ---
KERNEL_PKG="linux"       
TIMEZONE="Asia/Kolkata"       
LOCALE="en_US.UTF-8"          
KEYBOARD_LAYOUT="us"
MIRROR_COUNTRY="India"
BOOT_SIZE="+1G"

# --- LIVE ISO ENVIRONMENT SETUP ---
log_info "Configuring live ISO environment..."
loadkeys "${KEYBOARD_LAYOUT:-us}"
timedatectl set-ntp true

log_info "Refreshing Arch Linux keyring to prevent PGP signature failures..."
retry pacman -Sy --noconfirm archlinux-keyring

log_info "Configuring pacman..."
sed -i 's/^# *ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

log_info "Verifying internet connectivity..."
retry ping -c 1 -W 3 archlinux.org >/dev/null && log_success "Connectivity verified."

log_info "Synchronizing pacman mirrorlist..."
reflector --latest 5 --protocol https --age 12 --sort rate --save /etc/pacman.d/mirrorlist && log_success "Mirrors synchronized."

# --- RE-RUN DETECTION ---
SKIP_DISK_SETUP="false"
if mountpoint -q /mnt; then
    echo ""
    log_warn "Existing mounted filesystem detected at /mnt."
    read -rp "Re-use current mounts and skip partition/format phase? [Y/n]: " REUSE_MOUNTS
    if [[ "${REUSE_MOUNTS:-Y}" =~ ^[Yy]$ ]]; then
        SKIP_DISK_SETUP="true"
        log_info "Skipping disk setup. Using active mounts on /mnt."
    fi
fi

if [[ "$SKIP_DISK_SETUP" == "false" ]]; then
    echo ""
    log_info "Available Storage Devices:"
    echo -e "${BOLD}----------------------------------------------------${RESET}"
    lsblk -d -p -n -l -o NAME,SIZE,MODEL | grep -E "/dev/(sd|nvme|vd|mmcblk)"
    echo -e "${BOLD}----------------------------------------------------${RESET}\n"

    # --- DISK SELECTION ---
    while true; do
        read -rp "Enter target disk path (e.g., /dev/nvme0n1 or /dev/sda): " DISK
        
        if [[ ! -b "$DISK" ]]; then
            log_error "Device '$DISK' does not exist or is not a block device. Try again."
            continue
        fi
        
        if lsblk -no MOUNTPOINTS "$DISK" | grep -q "^/run/archiso"; then
            log_error "Device '$DISK' appears to be the Arch Live ISO medium! Select another disk."
            continue
        fi
        
        break
    done

    # --- INSTALLER MODE SWITCH ---
    echo ""
    log_info "Select Install Mode for ${BOLD}$DISK${RESET}:"
    echo -e "  ${BOLD}[1] Whole-Disk Wipe${RESET}  (Destroys all data, automated GPT layout)"
    echo -e "  ${BOLD}[2] Shared Dual-Boot${RESET} (Preserves existing Windows/data, uses unallocated space)"
    echo -e "${BOLD}----------------------------------------------------${RESET}"
    read -rp "Enter mode [1 or 2, default: 1]: " INSTALL_MODE
    INSTALL_MODE="${INSTALL_MODE:-1}"

    ENABLE_OS_PROBER="false"

    # --- MODE 1: WHOLE-DISK AUTOMATED WIPE ---
    if [[ "$INSTALL_MODE" == "1" ]]; then
        DISK_SIZE_BYTES=$(lsblk -b -d -n -o SIZE "$DISK")
        DISK_SIZE_GB=$(( DISK_SIZE_BYTES / 1024 / 1024 / 1024 ))

        echo ""
        log_info "Selected Drive: ${BOLD}$DISK${RESET} (Total Capacity: ${BOLD}${DISK_SIZE_GB} GB${RESET})"
        log_info "Recommendation: 30 to 50 GB is optimal for Arch Linux root."
        echo -e "${BOLD}----------------------------------------------------${RESET}"

        DEFAULT_ROOT=40
        (( DISK_SIZE_GB - 2 < DEFAULT_ROOT )) && DEFAULT_ROOT=$(( DISK_SIZE_GB - 2 ))

        while true; do
            read -rp "Enter desired ROOT partition size in GB [default: ${DEFAULT_ROOT}]: " INPUT_ROOT
            INPUT_ROOT="${INPUT_ROOT:-$DEFAULT_ROOT}"
            
            if [[ ! "$INPUT_ROOT" =~ ^[0-9]+$ ]]; then
                log_error "Please enter a valid integer (e.g., 30, 40, 60)."
                continue
            fi
            
            if (( INPUT_ROOT + 2 >= DISK_SIZE_GB )); then
                log_error "Size too large! On a ${DISK_SIZE_GB} GB drive, ROOT cannot exceed $(( DISK_SIZE_GB - 2 )) GB."
                continue
            fi
            break
        done

        ROOT_SIZE="+${INPUT_ROOT}G"
        HOME_SIZE_GB=$(( DISK_SIZE_GB - INPUT_ROOT - 1 ))

        log_success "Partition layout locked: [EFI: ${BOOT_SIZE}] [ROOT: ${ROOT_SIZE}] [HOME: ~${HOME_SIZE_GB}G (REMAINING)]"

        if [[ "$DISK" =~ (nvme|mmcblk|loop) ]]; then
            PART_PREFIX="${DISK}p"
        else
            PART_PREFIX="${DISK}"
        fi

        BOOT_PART="${PART_PREFIX}1"
        ROOT_PART="${PART_PREFIX}2"
        HOME_PART="${PART_PREFIX}3"

        echo ""
        log_warn "WARNING: YOU ARE ABOUT TO PERMANENTLY ERASE ALL DATA ON:"
        echo -e "${RED}${BOLD} => $DISK ($(lsblk -d -no MODEL "$DISK" | xargs))${RESET}"
        log_warn "Target layout: [EFI: ${BOOT_SIZE}] [ROOT: ${ROOT_SIZE}] [HOME: ~${HOME_SIZE_GB}G (REMAINING)]"
        echo ""
        read -rp "Type 'WIPE' in all caps to authorize destruction of $DISK: " CONFIRM

        if [[ "$CONFIRM" != "WIPE" ]]; then
            log_info "Authorization failed. Aborting installation. Your disk is untouched."
            exit 0
        fi

        echo ""
        log_info "Starting installation..."
        log_info "Cleaning up any previous active mounts..."
        umount -q -R /mnt 2>/dev/null || true
        swapoff -a 2>/dev/null || true

        log_info "Wiping existing partition table on ${DISK}..."
        sgdisk --zap-all "${DISK}"

        log_info "Creating new GPT partitions (EFI + Root + Home)..."
        sgdisk --new=1:0:"${BOOT_SIZE}" --typecode=1:ef00 --change-name=1:"EFI" "${DISK}"
        sgdisk --new=2:0:"${ROOT_SIZE}" --typecode=2:8304 --change-name=2:"ROOT" "${DISK}"
        sgdisk --new=3:0:0            --typecode=3:8302 --change-name=3:"HOME" "${DISK}"
        partprobe "${DISK}"
        sleep 2

        log_info "Formatting filesystems..."
        mkfs.fat -F 32 -n "EFI" "${BOOT_PART}"
        mkfs.ext4 -F -L "ROOT" "${ROOT_PART}"
        mkfs.ext4 -F -L "HOME" "${HOME_PART}"

    # --- MODE 2: SHARED DISK DUAL-BOOT ---
    elif [[ "$INSTALL_MODE" == "2" ]]; then
        ENABLE_OS_PROBER="true"
        echo ""
        log_info "Current partition layout on ${BOLD}$DISK${RESET}:"
        echo -e "${BOLD}----------------------------------------------------${RESET}"
        lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DISK"
        echo -e "${BOLD}----------------------------------------------------${RESET}"
        
        log_info "To preserve Windows (C: / D:), you must allocate your unallocated free space."
        read -rp "Launch interactive partitioner (cfdisk) now to carve free space? [Y/n]: " RUN_CFDISK
        RUN_CFDISK="${RUN_CFDISK:-Y}"
        
        if [[ "$RUN_CFDISK" =~ ^[Yy]$ ]]; then
            cfdisk "$DISK"
            log_info "Informing kernel of partition table updates..."
            partprobe "$DISK"
            sleep 2
            echo ""
            log_info "Updated partition layout:"
            lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DISK"
            echo -e "${BOLD}----------------------------------------------------${RESET}"
        fi

        log_info "Map your partitions carefully. Do NOT select Windows basic data partitions!"
        while true; do
            read -rp "Enter EXISTING Windows EFI partition (e.g., /dev/nvme0n1p1): " BOOT_PART
            read -rp "Enter target ROOT partition (e.g., /dev/nvme0n1p4): " ROOT_PART
            read -rp "Enter target HOME partition (e.g., /dev/nvme0n1p5): " HOME_PART
            
            if [[ ! -b "$BOOT_PART" || ! -b "$ROOT_PART" || ! -b "$HOME_PART" ]]; then
                log_error "One or more partition paths are invalid block devices. Try again."
                continue
            fi
            
            if [[ "$BOOT_PART" == "$ROOT_PART" || "$ROOT_PART" == "$HOME_PART" || "$BOOT_PART" == "$HOME_PART" ]]; then
                log_error "Partition paths cannot be identical! Try again."
                continue
            fi
            break
        done

        echo ""
        log_warn "SAFETY VERIFICATION:"
        log_warn " -> ROOT (${BOLD}$ROOT_PART${RESET}) and HOME (${BOLD}$HOME_PART${RESET}) will be FORMATTED as ext4."
        log_warn " -> EFI  (${BOLD}$BOOT_PART${RESET}) will NOT be formatted to protect Windows bootloaders."
        echo ""
        read -rp "Type 'INSTALL' in all caps to authorize formatting of Linux partitions: " CONFIRM

        if [[ "$CONFIRM" != "INSTALL" ]]; then
            log_info "Authorization failed. Aborting installation."
            exit 0
        fi

        echo ""
        log_info "Cleaning up any previous active mounts..."
        umount -q -R /mnt 2>/dev/null || true
        swapoff -a 2>/dev/null || true

        log_info "Formatting Linux filesystems (Skipping EFI format)..."
        mkfs.ext4 -F -L "ROOT" "${ROOT_PART}"
        mkfs.ext4 -F -L "HOME" "${HOME_PART}"
    else
        log_error "Invalid mode selected. Aborting."
        exit 1
    fi

    # --- MOUNTING TARGET DIRECTORIES ---
    log_info "Mounting filesystems to /mnt..."
    mount "${ROOT_PART}" /mnt

    mkdir -p /mnt/boot
    mount "${BOOT_PART}" /mnt/boot

    mkdir -p /mnt/home
    mount "${HOME_PART}" /mnt/home
fi

echo ""
log_success "Disk structure ready and mounted!"
echo -e "${BOLD}----------------------------------------------------${RESET}"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "${DISK:-/dev/sda}" | grep -E "/mnt|NAME" || lsblk
echo -e "${BOLD}----------------------------------------------------${RESET}"
log_success "Ready for Phase 2: base system bootstrap."

# --- PHASE 2: BASE SYSTEM BOOTSTRAP ---

CORE_PKGS=(base base-devel "${KERNEL_PKG}" "${KERNEL_PKG}-headers" linux-firmware intel-ucode)
SYS_PKGS=(networkmanager iwd zram-generator grub efibootmgr dosfstools lsof usbutils pciutils pacman-contrib acpid power-profiles-daemon nano git sudo curl wget openssh reflector man-db)
SYS_SERVICES=(NetworkManager iwd sshd acpid power-profiles-daemon fstrim.timer paccache.timer)

PKGS_URL="${PKGS_URL:-}"

EXTRA_PKGS=()
TARGET_SERVICES=()

if [[ -z "${PKGS_URL}" ]]; then
    echo ""
    read -r -p ":: Enter URL for custom packages.txt (press Enter to skip/use default): " PKGS_URL
fi

if [[ -n "${PKGS_URL}" ]]; then
    log_info "Remote package URL detected. Fetching payload from ${PKGS_URL}..."
    if retry curl -fSsL "${PKGS_URL}" -o /tmp/remote_packages.txt; then
        mapfile -t EXTRA_PKGS < <(sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]].*//' -e 's/[[:space:]]*$//' /tmp/remote_packages.txt | grep -E '^[a-z0-9._+][a-z0-9._+-]*$')
        mapfile -t TARGET_SERVICES < <(grep -oE '@[a-zA-Z0-9_-]+' /tmp/remote_packages.txt | tr -d '@')
    else
        log_warn "Failed to fetch remote package list. Proceeding without remote packages."
    fi
elif [[ -f "${REPO_DIR}/packages.txt" ]]; then
    mapfile -t EXTRA_PKGS < <(sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]].*//' -e 's/[[:space:]]*$//' "${REPO_DIR}/packages.txt" | grep -E '^[a-z0-9._+][a-z0-9._+-]*$')
    mapfile -t TARGET_SERVICES < <(grep -oE '@[a-zA-Z0-9_-]+' "${REPO_DIR}/packages.txt" | tr -d '@')

    if (( ${#EXTRA_PKGS[@]} > 0 )); then
        log_info "Found local packages.txt (${#EXTRA_PKGS[@]} packages queued)."
        read -r -p ":: Install packages from local packages.txt? [Y/n]: " CONFIRM_PKGS
        if [[ "$CONFIRM_PKGS" =~ ^[Nn]$ ]]; then
            log_info "Skipping local package manifest."
            EXTRA_PKGS=()
            TARGET_SERVICES=()
        fi
    fi
else
    log_warn "No package manifest found."
fi

read -r -p ":: Enter additional packages to install (space-separated, press Enter to skip): " MANUAL_INPUT
if [[ -n "${MANUAL_INPUT}" ]]; then
    read -ra MANUAL_PKGS <<< "${MANUAL_INPUT}"
    EXTRA_PKGS+=("${MANUAL_PKGS[@]}")
    log_info "Added ${#MANUAL_PKGS[@]} manual package(s)."
fi

TOTAL_PKGS=("${CORE_PKGS[@]}" "${SYS_PKGS[@]}" "${EXTRA_PKGS[@]}")

echo -e "${BOLD}----------------------------------------------------${RESET}"
if [[ -f /mnt/bin/bash && -f /mnt/etc/os-release ]]; then
    log_info "Existing Arch Linux installation detected in /mnt."
    log_info "Installing missing or updated packages..."
    retry pacman --sysroot /mnt -S --needed --noconfirm "${TOTAL_PKGS[@]}"
else
    log_info "Initiating pacstrap installation to /mnt..."
    log_info "Payload size: ${#TOTAL_PKGS[@]} unique packages/groups."
    retry pacstrap -K /mnt "${TOTAL_PKGS[@]}"
fi
echo -e "${BOLD}----------------------------------------------------${RESET}"
log_success "Base system packages successfully installed!"

# --- GENERATE FSTAB ---
log_info "Generating filesystem table (fstab)..."
genfstab -U /mnt > /mnt/etc/fstab

if [[ -s /mnt/etc/fstab ]]; then
    log_success "fstab successfully generated. Verifying contents:"
    echo -e "${BOLD}----------------------------------------------------${RESET}"
    cat /mnt/etc/fstab
    echo -e "${BOLD}----------------------------------------------------${RESET}"
else
    log_error "fstab generation failed or file is empty!"
    exit 1
fi

log_success "Phase 2 complete! Ready to enter Phase 3: Chroot Configuration."

# --- PHASE 3: CHROOT SYSTEM CONFIGURATION ---

log_info "Entering arch-chroot to configure system internals..."
echo -e "${BOLD}----------------------------------------------------${RESET}"

arch-chroot /mnt /bin/bash -e <<EOF

# 1. TIMEZONE & CLOCK
echo "Setting timezone to ${TIMEZONE}..."
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# 2. LOCALIZATION
echo "Configuring locale (${LOCALE})..."
sed -i "s/^#\(${LOCALE}\)/\1/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYBOARD_LAYOUT:-us}" > /etc/vconsole.conf

# 3. NETWORK CONFIGURATION 
echo "Setting hostname to ${HOSTNAME}..."
echo "${HOSTNAME}" > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS

echo "Configuring NetworkManager to use iwd backend..."
mkdir -p /etc/NetworkManager/conf.d
cat <<NMWIFI > /etc/NetworkManager/conf.d/wifi_backend.conf
[device]
wifi.backend=iwd
NMWIFI

# 4. SUDO PRIVILEGES
echo "Enabling sudo access for wheel group..."
sed -i 's/^# \%wheel ALL=(ALL:ALL) ALL/\%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# 5. PACMAN CONFIGURATION 
echo "Configuring pacman for performance..."
sed -i 's/^# *ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# 6. ZRAM COMPRESSED MEMORY SETUP
echo "Configuring zram-generator for compressed RAM swap..."
cat <<ZRAM > /etc/systemd/zram-generator.conf
[zram0]
zram-size = min(ram, 8192)
compression-algorithm = zstd
ZRAM

# 7. BOOTLOADER CONFIGURATION (GRUB UEFI)
echo "Installing and configuring GRUB bootloader..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB 2>/dev/null || true

if [[ "${ENABLE_OS_PROBER:-false}" == "true" ]]; then
    echo "Dual-boot mode detected. Installing and enabling os-prober..."
    pacman -S --noconfirm --needed os-prober
    if grep -q "GRUB_DISABLE_OS_PROBER" /etc/default/grub; then
        sed -i 's/^#* *GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
    else
        echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
    fi
fi

echo "Generating GRUB configuration..."
grub-mkconfig -o /boot/grub/grub.cfg

EOF

echo "Enabling system daemons..."
for svc in "${SYS_SERVICES[@]}" "${TARGET_SERVICES[@]:-}"; do
    [[ -z "$svc" ]] && continue
    [[ "$svc" != *.* ]] && svc="$svc.service"
    if systemctl --root=/mnt list-unit-files "$svc" &>/dev/null; then
        systemctl --root=/mnt enable "$svc" &>/dev/null
        echo " -> Enabled $svc"
    else
        echo "[!] Warning: Unit '$svc' not found or invalid; skipping."
    fi
done

log_info "Configuring root password..."
arch-chroot /mnt passwd root

if arch-chroot /mnt id -u "${TARGET_USER}" &>/dev/null; then
    log_info "User '${TARGET_USER}' already exists. Updating password..."
else
    log_info "Creating user: ${TARGET_USER}..."
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "${TARGET_USER}"
fi
log_info "Enter password for ${TARGET_USER}:"
arch-chroot /mnt passwd "${TARGET_USER}"

echo -e "${BOLD}----------------------------------------------------${RESET}"
log_success "Chroot configuration complete!"

# --- PHASE 4: POST INSTALLATION CLEANUP & AUTO-REBOOT ---

log_info "Unmounting partitions..."
umount -R /mnt 2>/dev/null || true

echo ""
log_success "ARCH LINUX INSTALLATION FINISHED SUCCESSFULLY!"
echo ""
echo -e "\e[1;7;33m  >>> ACTION REQUIRED: Please remove your installation USB drive NOW! <<<  \e[0m"
echo ""
log_info "System will auto-reboot in 10 seconds. Press ANY KEY to abort..."

for (( i=10; i>0; i-- )); do
    echo -ne "\r${BLUE}[*]${RESET} ${BOLD}Rebooting in ${i} seconds... ${RESET}"
    if read -t 1 -n 1 -s -r; then
        echo -e "\n"
        log_info "Auto-reboot aborted by user, type 'reboot' manually when ready."
        exit 0
    fi
done

echo -e "\n"
log_info "Rebooting now..."
reboot