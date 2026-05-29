# Fedora Automated Installation

This directory contains scripts and configurations for building a custom, semi-automated Fedora KDE Netinstall ISO.

## 📁 File Overview

*   **`ks.cfg`** — The automated Kickstart configuration. It partitions the system interactively (prompting for target disk selection), installs base KDE desktop tools and Ansible dependencies, and creates a first-boot script to run the provisioning playbook.
*   **`build_iso.sh`** — Automation script to download the official Fedora Everything ISO, inject the modified boot configurations, attach the Kickstart script (`ks.cfg`), and output the final ISO.
*   **`system-update.sh`** — Executed weekly by root systemd timer to update system packages.
*   **`update.sh`** — Executed daily by user systemd timer to update user packages (Flatpak, Homebrew, Oh My Zsh, Kitty).

---

## 🛠 Usage

### 1. Build the ISO
On your host system:
```bash
./build_iso.sh
```
This downloads the Fedora Everything ISO and compiles a custom bootable image: `Fedora-Everything-KDE-Automated.iso`.

### 2. Write to USB
Write the ISO to a USB flash drive using `dd`:
```bash
sudo dd if=Fedora-Everything-KDE-Automated.iso of=/dev/sdX bs=4M status=progress oflag=sync
```
*(Replace `/dev/sdX` with your target USB block device).*

### 3. Install and Configure
1. Boot the target machine from the USB.
2. The bootloader will launch automatically after 2 seconds.
3. Select your target installation drive and layout in the Anaconda partitioning UI.
4. Confirm partition formatting and click **Begin Installation**.
5. Once installed, reboot. On first login, a terminal window (`konsole`) will launch automatically, clone this repository, run `ansible-playbook -K ansible/local.yml` (prompting you for your `sudo` password), self-destruct its desktop starter, and reboot.

---

## 🛠️ Useful Ansible Commands

Here are some helpful commands for testing, verifying, and maintaining your setup:

### 1. Dry Run / Simulating Changes (Check Mode)
Check which changes Ansible would apply to your workstation without actually modifying any files:
```bash
ansible-playbook -K ansible/local.yml --check
```

### 2. View File Differences (Diff Mode)
Inspect configuration file differences (like udev rules, sysctl settings, etc.) before writing changes:
```bash
ansible-playbook -K ansible/local.yml --check --diff
```

### 3. Syntax Verification
Ensure there are no YAML or structural syntax errors in your playbook or variables:
```bash
ansible-playbook ansible/local.yml --syntax-check
```

### 4. Resume/Start at a Specific Task
Skip earlier steps and run the playbook starting from a specific task name:
```bash
ansible-playbook -K ansible/local.yml --start-at-task="Ensure user shell is Zsh"
```

### 5. Run Step-by-Step (Interactive Mode)
Step through the playbook one task at a time. Ansible will prompt you before running each task, allowing you to run (`y`), skip (`n`), or abort (`q`):
```bash
ansible-playbook -K ansible/local.yml --step
```

