# macOS Setup via Ansible

My personal scripts and Ansible configurations for setting up and maintaining a new MacBook with my preferred configuration.

## 🚀 Quick Start

1. **Run compatibility check** (recommended):
   ```bash
   ./check_compatibility.sh
   ```

2. **Run full bootstrap**:
   ```bash
   ./bootstrap.sh
   ```

## 📁 Script & Playbook Overview

- **`bootstrap.sh`** - Main trigger script that installs Xcode Command Line Tools, Homebrew, and Ansible, then runs the Ansible playbook.
- **`check_compatibility.sh`** - Validates system compatibility before setup.
- **`setup/configure_osx.sh`** - Configures macOS system preferences (called by Ansible).
- **`setup/restore.sh`** - Restores backed-up configuration files (optional/manual).
- **`ansible/local.yml`** - The Ansible playbook that provisions packages, dotfiles, settings, and updates.

## 💻 Compatibility

- ✅ **macOS 15.5 (Sequoia)** - Fully tested and compatible
- ✅ **Apple Silicon & Intel Macs** - Universal support
- ✅ **zsh shell** - Optimized for modern macOS default shell

## 🔄 Maintenance

- **`update_tools.sh`** - Update Homebrew packages and Brewfile
- **`backup.sh`** - Backup current configuration
