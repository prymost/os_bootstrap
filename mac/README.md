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
- **`mount_nas.sh`** - Keeps the NAS share mounted (see below).
- **`ansible/local.yml`** - The Ansible playbook that provisions packages, dotfiles, settings, and updates.

## 🗄️ NAS Auto-Mount

A LaunchAgent (`com.user.nas.mount`, deployed by `ansible/tasks/mac_mounts.yml`) runs `mount_nas.sh` to keep the NAS share mounted at `~/NAS`:

- **At login** (`RunAtLoad`) and **on every network change** (`WatchPaths`), so the share remounts automatically when the Mac rejoins the home network.
- Every 5 minutes (`StartInterval`) as a retry for failed mounts and sleep/wake gaps.
- If the NAS is unreachable (e.g. laptop taken elsewhere), a stale mount is force-unmounted so the next trigger can remount cleanly.
- **Credentials** live only in the login keychain. On a fresh install the script shows a native password dialog once and stores the password with an ACL trusting `security` and `mount_smbfs`. The password is never written to disk or logged. It is passed to `mount_smbfs` percent-encoded (via `jq`, piped on stdin) which briefly exposes it in the process list while mounting.
- Configuration (host, share, user, mount path) lives in `ansible/vars/Darwin.yml`.
- Log: `~/Library/Logs/nas_mount.log`.

To trigger a remount manually:

```bash
launchctl kickstart "gui/$(id -u)/com.user.nas.mount"
```

## 💻 Compatibility

- ✅ **macOS 15.5 (Sequoia)** - Fully tested and compatible
- ✅ **Apple Silicon & Intel Macs** - Universal support
- ✅ **zsh shell** - Optimized for modern macOS default shell

## 🔄 Maintenance

- **`update_tools.sh`** - Update Homebrew packages and Brewfile
- **`backup.sh`** - Backup current configuration
