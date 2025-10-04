# PopOS/Debian Setup Scripts

My personal scripts for setting up and maintaining a PopOS or Debian Linux desktop with development tools and applications.

## 🚀 Quick Start

1. **Run compatibility check** (recommended):
   ```bash
   ./check_compatibility.sh
   ```

2. **Run full bootstrap**:
   ```bash
   ./bootstrap.sh
   ```

## 📁 Script Overview

- **`bootstrap.sh`** - Main entry point that orchestrates the entire setup
- **`check_compatibility.sh`** - Validates system compatibility before setup
- **`setup/initial.sh`** - Installs essential build tools and system packages
- **`setup/my_installs.sh`** - Installs development tools, applications, and configures zsh with shared .zshrc template

## 🛠 Alternative Usage

### Running Individual Scripts
```bash
# Setup only core tools
./setup/initial.sh

# Install applications and tools only
./setup/my_installs.sh
```

## 🔄 Automated Updates

The bootstrap process automatically configures and enables systemd timers to keep the system and applications up-to-date. The setup is handled by the `setup/automations.sh` script, so manual configuration is no longer required after running the main bootstrap.

The update process is split into two parts for better security and management:

### System-wide Updates

- **Script:** `system-update.sh`
- **Scope:** Handles system-level packages that require root privileges, such as `apt` packages and Calibre.
- **Mechanism:** A system-wide systemd timer (`/etc/systemd/system/system-update.timer`) runs the script as the `root` user daily.

### User-specific Updates

- **Script:** `update.sh`
- **Scope:** Handles user-specific tools and applications like Homebrew, Flatpak, Oh My Zsh, and Kitty.
- **Mechanism:** A user-level systemd timer (`~/.config/systemd/user/update.timer`) runs the script as the current user daily and upon waking from sleep.

### Verifying the Timers

You can check the status of the automated timers to see when they are scheduled to run next.

- **To check the system timer:**
  ```bash
  sudo systemctl list-timers | grep update
  ```

- **To check the user timer:**
  ```bash
  systemctl --user list-timers | grep update
  ```

### Checking Update Logs

To see the output and confirm that the update scripts ran successfully, you can check their logs using `journalctl`.

- **To check the system update log (for apt, etc.):**
  ```bash
  sudo journalctl -u system-update.service --since "today"
  ```

- **To check the user update log (for Homebrew, Flatpak, etc.):**
  ```bash
  journalctl --user -u update.service --since "today"
  ```

If you need to re-apply the automation setup for any reason, you can run the script directly:
```bash
./setup/automations.sh
```

## 🎯 Post-Installation

After running the bootstrap:

**Configure Git**:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

**Set up SSH key** for GitHub:
   ```bash
   ssh-keygen -t ed25519 -C "your.email@example.com"
   # add it to ssh agent
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
   ```
