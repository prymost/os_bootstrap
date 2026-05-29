# PopOS/Debian Setup with Ansible

This directory contains the update scripts and documentation for managing a Pop!_OS or Debian desktop environment using the unified Ansible provisioning system.

## 🚀 Quick Start

To provision your Pop!_OS/Debian workstation:

1. **Install Ansible**:
   ```bash
   sudo apt-get update
   sudo apt-get install -y ansible git
   ```

2. **Run the Playbook**:
   From the repository root:
   ```bash
   ansible-playbook -K ansible/local.yml
   ```

---

## 📁 Directory Structure

*   **`system-update.sh`** — Executed weekly by root systemd timer to update system packages.
*   **`update.sh`** — Executed daily by user systemd timer to update user packages (Flatpak, Homebrew, Oh My Zsh, Kitty).

---

## 🔄 Automated Updates

The Ansible playbook automatically configures systemd timers to run update automation tasks in the background:

### System-wide Updates (Apt & Calibre)
*   **Script:** `system-update.sh` (runs with root privileges)
*   **Timer:** `/etc/systemd/system/system-update.timer` (runs weekly)
*   **Check status:** `sudo systemctl list-timers | grep update`
*   **Check logs:** `sudo journalctl -u system-update.service --since "today"`

### User-specific Updates (Flatpak, Homebrew, Kitty, OMZ)
*   **Script:** `update.sh` (runs as user `boris`)
*   **Timer:** `~/.config/systemd/user/update.timer` (runs daily)
*   **Check status:** `systemctl --user list-timers | grep update`
*   **Check logs:** `journalctl --user -u update.service --since "today"`

---

## 🎯 Post-Installation Steps

After running the playbook, verify the configuration:

1. **Configure Git**:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

2. **Set up SSH key** for GitHub:
   ```bash
   ssh-keygen -t ed25519 -C "your.email@example.com"
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
   ```
