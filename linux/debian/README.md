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
