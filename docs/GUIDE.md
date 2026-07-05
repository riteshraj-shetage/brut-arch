# OPERATIONAL GUIDE

This document defines the required, authoritative procedures for bootstrapping an Arch Linux system.

---

## 1. Firmware Configuration

Access your motherboard's UEFI/BIOS settings during boot and enforce the following baseline parameters:

- **Secure Boot: DISABLED**
  The standard Arch Linux live medium and default GRUB bootloaders are not cryptographically signed by Microsoft. Secure Boot must be disabled to boot the ISO and execute custom kernel images.
- **SATA / Storage Controller Mode: AHCI**
  If your storage controller is set to Intel RST (RAID/Optane) or IDE mode, the Linux kernel will fail to detect your NVMe or SATA SSDs. The controller must be explicitly set to **AHCI** or standard NVMe mode.
- **Boot Mode: 64-bit UEFI ONLY**
  Disable CSM (Compatibility Support Module) and Legacy BIOS modes. This deployment strictly requires a GPT partition table and an EFI System Partition (ESP).

## 2. Host OS Preparation (Windows Dual-Boot & Hibernation)

If the target machine currently runs Windows or will share hardware with a Windows installation, you must neutralize Windows disk-locking mechanics prior to installation:

1. **Disable Fast Startup:**
   Windows Fast Startup puts the hybrid kernel into a hibernated state upon shutdown, locking all attached NTFS and FAT32 filesystems (including the shared EFI System Partition).
   - In Windows: Navigate to **Control Panel -> Power Options -> Choose what the power buttons do -> Change settings that are currently unavailable**, and uncheck **Turn on fast startup**.
2. **Disable Hibernation System-Wide:**
   Open an elevated Windows Command Prompt (`cmd` as Administrator) and execute:

   ```cmd
   powercfg /h off
   ```

3. **Suspend BitLocker Encryption:**
   If drive encryption is active, suspend BitLocker protection before modifying partition tables or UEFI boot entries to prevent triggering a mandatory recovery key lockout on the next Windows boot.

## 3. Partition Sizing Standards

When executing the script or partitioning manually, adhere to these concrete storage boundaries based on your target disk capacity:

| Partition            | Target Size        | Filesystem | Engineering Rationale                                                                                                               |
| -------------------- | ------------------ | ---------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| **`EFI`** (`/boot`)  | **`+1G`**          | `FAT32`    | Prevents boot exhaustion when stacking multiple kernels (`linux`, `linux-lts`), Intel microcode, and fallback `initramfs` archives. |
| **`ROOT`** (`/`)     | **`30G – 50G`**    | `ext4`     | **30G:** Minimal CLI baseline. **40G (Default):** Optimal for developers. **50G+:** Power users/compilation.                        |
| **`HOME`** (`/home`) | **`REMAINING`**    | `ext4`     | Absorbs 100% of remaining disk space for project repositories, dotfiles, and data.                                                  |
| **`SWAP`**           | **`0G`** (On Disk) | `ZRAM`     | **Zero physical disk swap.** Memory overflow handled via `zstd`-compressed `zram-generator`.                                        |

## 4. Deployment Tiers

### Tier 1: Dedicated Bare-Metal Disk (Recommended / Safest)

The entire physical machine or target SSD is dedicated exclusively to Arch Linux.

- **Execution:** Select **Mode 1 (Whole-Disk Wipe)** in the deployment engine.

### Tier 2: Separate Physical Disk Dual-Boot (Recommended for Multi-OS)

The machine contains two distinct physical drives (e.g., `/dev/nvme0n1` for Windows, `/dev/nvme1n1` for Arch Linux).

- **Execution:** Select **Mode 1 (Whole-Disk Wipe)** targeting the dedicated Arch drive.
- **Safety Step:** Physically disconnect or disable the Windows drive in BIOS prior to booting to eliminate accidental drive selection errors.

### Tier 3: Single Shared Disk Dual-Boot (High Risk / Advanced Only)

A single physical SSD contains existing operating systems (e.g., Windows `C:`) that must be preserved.

- **Execution:** Select **Mode 2 (Shared Dual-Boot)** to bypass automated disk destruction and open `cfdisk`.
- **Mandatory Prerequisite:** Shrink your Windows volume exclusively from within `Windows Disk Management` prior to booting Linux. Leave the freed target space completely **Unallocated**.

---

## 5. Navigating cfdisk

Use `Mode 2` (Shared Dual-Boot) mode for Tier 3 deployments.

### 5.1 Visual Partitioning

When prompted: `"Launch interactive partitioner (cfdisk) now to carve free space? [Y/n]:"`, press **`Y`** and **`Enter`**.

1. **Locate Free Space:** Highlight **`Free space`**. **Never modify existing `NTFS` or `EFI` partitions.**
2. **Create ROOT Partition:**

- Select **`[ New ]`** -> Set size (e.g., `40G`) -> **`[ Type ]`** -> Select **`8304 Linux root (x86-64)`**.

3. **Create HOME Partition:**

- Highlight remaining **`Free space`** -> **`[ New ]`** -> Use default remaining size -> **`[ Type ]`** -> Select **`8302 Linux home (x86-64)`**.

4. **Write Changes:**

- Select **`[ Write ]`** -> Type `yes` -> **`[ Quit ]`**.

### 5.2 Partition Mapping

After exiting, input your partition identifiers when prompted:

- **Existing Windows EFI:** Path to the Microsoft EFI partition (e.g., `/dev/nvme0n1p1`). (Script mounts this to `/mnt/boot` **without formatting**).
- **Target ROOT:** Path to your new root (e.g., `/dev/nvme0n1p4`).
- **Target HOME:** Path to your new home (e.g., `/dev/nvme0n1p5`).
- **Authorize:** Type `INSTALL` to trigger the final deployment.
