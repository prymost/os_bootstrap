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

# Or run only package-related tasks (e.g., to install Brave, VS Code, Flatpaks, Homebrew):
ansible-playbook -K ansible/local.yml --tags packages
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

---

## 🔄 Syncthing Synchronization

Syncthing is configured to synchronize directories (e.g., Obsidian vaults) with my NAS.

### 1. Configuration Secrets

Since Syncthing parameters (Device IDs, paths) are private, they are stored in a local, gitignored file. To configure Syncthing from scratch, create `ansible/vars/secrets.yml` with the following variables:

```yaml
---
syncthing_nas_device_id: "YOUR_NAS_DEVICE_ID"
syncthing_nas_address: "tcp://<NAS_IP>:<PORT>"
syncthing_folder_id: "YOUR_FOLDER_ID"
syncthing_local_path: "/home/boris/MyNotes"
```

The playbook will validate this file and fail early with a clear warning if it is missing or incomplete.

### 2. Manual Pairing Step

After running the playbook:
1. The local Syncthing daemon will be installed and configured as a systemd user service.
2. The playbook outputs your local Device ID.
3. Access your NAS Syncthing console, add your local Device ID as a remote device, and share the configured Folder ID (`syncthing_folder_id`) with it to complete the pairing.

---

## 🔐 Secrets & Dotfiles Backup (age + Bitwarden)

Sensitive dotfiles (`.ssh`, `.kube`, `.gitconfig`, `.gnupg`, `.zsh_history`) and repository secrets (`ansible/vars/secrets.yml`) are backed up automatically to the Synology NAS using **asymmetric `age` encryption**.

### 1. Operations & Commands

* **Initialize Keypair & Bitwarden Integration**:
  ```bash
  ./backup_restore.sh genkey
  ```
  Generates an `age` keypair, saves the private key as a Secure Note (`os_setup_secrets_key`) in Bitwarden via `bw` CLI, and configures the public key in `ansible/vars/default.yml`.

* **Run Manual Backup**:
  ```bash
  ./backup_restore.sh backup
  ```
  *(Calculates SHA-256 hash across target files, skips redundant runs if unchanged, encrypts with the public key, and retains the 5 most recent snapshots on NAS).*

* **Restore Secrets**:
  ```bash
  # Automatic via Bitwarden CLI:
  ./backup_restore.sh restore --from-bw

  # Or interactive prompt (Bitwarden login or manual key paste):
  ./backup_restore.sh restore
  ```

* **Check Backup & Archive Status**:
  ```bash
  ./backup_restore.sh status
  # Or run full health check:
  ./check_status.sh
  ```

### 2. Systemd Automation

Daily automated backups run unattended via a user systemd timer:
* **Service**: `systemctl --user status secrets-backup.service`
* **Timer**: `systemctl --user status secrets-backup.timer`
* **Logs**: `journalctl --user -u secrets-backup.service -n 50 -f`


