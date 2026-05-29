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

*   **[`ansible/`](file:///home/boris/Workspace/os_bootstrap/ansible/)** — Unified declarative configuration playbook (`local.yml`) and OS-specific variables (`vars/`).
*   **[`linux/fedora/`](file:///home/boris/Workspace/os_bootstrap/linux/fedora/)** — Kickstart installer automation configuration and custom ISO builder.
*   **[`linux/debian/`](file:///home/boris/Workspace/os_bootstrap/linux/debian/)** — Update timers and scripts for Debian/Pop!_OS environments.
*   **[`mac/`](file:///home/boris/Workspace/os_bootstrap/mac/)** — macOS configuration using Homebrew (Brewfile).
*   **[`windows/`](file:///home/boris/Workspace/os_bootstrap/windows/)** — Windows 11 setup scripts and WSL configurations.
*   **[`shared/`](file:///home/boris/Workspace/os_bootstrap/shared/)** — Common configuration files (e.g., `.zshrc`, `kitty.conf`) restored to home directories.
