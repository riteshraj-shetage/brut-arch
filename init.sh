#!/bin/bash
# source: https://github.com/riteshraj-shetage/brut-arch.git

set -euo pipefail

# --- GLOBAL SYSTEM CONFIGURATION ---
HOSTNAME="archlinux"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="riteshraj"

# --- SYSTEM SETTINGS ---
KERNEL_PKG="linux-lts"       
TIMEZONE="Asia/Kolkata"       
LOCALE="en_US.UTF-8"          
KEYBOARD_LAYOUT="us"
MIRROR_COUNTRY="India"

# --- DISK CONFIGURATION ---
DISK="/dev/nvme0n1"              
FS_TYPE="ext4"     
BOOT_SIZE="+1G"
ROOT_SIZE="+40G"

# NVMe hardcoded partition mapping
BOOT_PART="${DISK}p1"
ROOT_PART="${DISK}p2"
HOME_PART="${DISK}p3"

# --- PRE-INSTALLATION LIVE ISO SETUP ---
echo "Configuring live environment..."
loadkeys "${KEYBOARD_LAYOUT}"
timedatectl set-ntp true

echo "Updating pacman mirrorlist for ${MIRROR_COUNTRY}..."
reflector --country "${MIRROR_COUNTRY}" --protocol https --latest 5 --sort rate --save /etc/pacman.d/mirrorlist

# --- DISK PARTITIONING ---
echo "Wiping existing partition table on ${DISK}..."
sgdisk --zap-all "${DISK}"

echo "Creating new partitions (EFI + Root + Home)..."
# 1. Create EFI System Partition (Type ef00)
sgdisk --new=1:0:${BOOT_SIZE} --typecode=1:ef00 --change-name=1:"EFI" "${DISK}"
# 2. Create Root Partition (Type 8304 for x86-64 root)
sgdisk --new=2:0:${ROOT_SIZE} --typecode=2:8304 --change-name=2:"ROOT" "${DISK}"
# 3. Create Home Partition using all remaining space (Type 8302 for x86-64 home)
sgdisk --new=3:0:0 --typecode=3:8302 --change-name=3:"HOME" "${DISK}"

echo "Informing the kernel of partition changes..."
partprobe "${DISK}"
sleep 2

# --- FILE SYSTEM FORMATTING ---
echo "Formatting partitions..."
mkfs.vfat -F 32 -n "EFI" "${BOOT_PART}"
mkfs.ext4 -F -L "ROOT" "${ROOT_PART}"
mkfs.ext4 -F -L "HOME" "${HOME_PART}"

# --- MOUNTING TARGET DIRECTORIES ---
echo "Mounting filesystems to /mnt..."
mount "${ROOT_PART}" /mnt

mkdir -p /mnt/boot
mount "${BOOT_PART}" /mnt/boot

mkdir -p /mnt/home
mount "${HOME_PART}" /mnt/home

echo "Disk structure layout verification:"
lsblk "${DISK}"

echo "Disk structure ready for pacstrap."
