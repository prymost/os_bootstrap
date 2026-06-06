# Bootstrap Scripts

Automated setup scripts for personal machine provisioning across multiple platforms.

## 🚀 Quick Start

### 1. Linux Desktops (Fedora / Pop!_OS / Debian)
Workstation configuration on Linux is declarative, managed via Ansible:

```bash
# 1. Install Ansible (if not already installed)
# On Fedora:
sudo dnf install -y ansible git
# On Debian/Pop!_OS:
sudo apt-get update && sudo apt-get install -y ansible git

# 2. Run the playbook
ansible-playbook -K ansible/local.yml
```

*Note: For a fully automated Fedora KDE installation, see the [Kickstart instructions](linux/fedora/README.md).*

### 2. Windows 11 (as Administrator)
```powershell
PowerShell -ExecutionPolicy Bypass -File windows/bootstrap-windows11.ps1
```

### 3. macOS
```bash
./mac/bootstrap.sh
```

### 4. WSL Ubuntu
```bash
./windows/wsl_scripts/bootstrap.sh
```

---

## 📁 Repository Overview

*   **[`ansible/`](file:///home/boris/Workspace/os_bootstrap/ansible/)** — Declarative configuration playbook (`local.yml`), modular tasks (`tasks/`), templates (`templates/`), scripts (`files/`), and OS variables (`vars/`).
*   **[`linux/fedora/`](file:///home/boris/Workspace/os_bootstrap/linux/fedora/)** — Kickstart installer automation configuration and custom ISO builder.
*   **[`linux/debian/`](file:///home/boris/Workspace/os_bootstrap/linux/debian/)** — Update timers and scripts for Debian/Pop!_OS environments.
*   **[`mac/`](file:///home/boris/Workspace/os_bootstrap/mac/)** — macOS configuration using Homebrew (Brewfile).
*   **[`windows/`](file:///home/boris/Workspace/os_bootstrap/windows/)** — Windows 11 setup scripts and WSL configurations.
*   **[`shared/`](file:///home/boris/Workspace/os_bootstrap/shared/)** — Common configuration files (e.g., `.zshrc`, `kitty.conf`) restored to home directories.

---

## 💾 BorgBackup Management

BorgBackup is set up declaratively to run automated daily backups to your NAS.

### 1. Operations & Monitoring

* **Manual Backup Run**:
  ```bash
  systemctl --user start borg-backup.service
  ```
* **Check Service Status**:
  ```bash
  systemctl --user status borg-backup.service
  ```
* **View Logs**:
  ```bash
  journalctl --user -u borg-backup.service -n 50 -f
  ```
* **List Backup Archives**:
  ```bash
  borg list ~/Backup/borg-repo
  ```

### 2. Restoring Files

#### Option A: Mount as a Folder (Recommended)
You can mount the entire repository as a virtual directory to browse archives and copy specific files/folders:
```bash
mkdir ~/restore-mount
borg mount ~/Backup/borg-repo ~/restore-mount

# Browse and copy files as needed (e.g., using Dolphin/Nautilus or cp)
cp -r ~/restore-mount/<archive_name>/media/boris/DataDrive/Documents/File.txt ~/Desktop/

# Always unmount when finished
borg umount ~/restore-mount
```

#### Option B: Extract Directly via CLI
To restore a complete archive into your current working directory:
```bash
borg extract ~/Backup/borg-repo::<archive_name>
```
