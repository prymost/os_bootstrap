# Project Overview

This project contains a set of bootstrap scripts and playbooks for automating the setup of personal machines across multiple platforms: Windows 11, macOS, WSL Ubuntu, and Linux Desktops (Fedora and Pop!_OS/Debian).

## Key Technologies

*   **Windows:** PowerShell, Winget
*   **macOS:** Ansible, Homebrew, Launchctl (via `mac/bootstrap.sh` trigger script)
*   **Linux (Fedora & Pop!_OS/Debian):** Ansible, DNF, APT, Flatpak, Linuxbrew, Systemd Timers
*   **Fedora Automation:** Anaconda Kickstart (`ks.cfg`), Ventoy automated installation

## Building and Running

### 1. Linux Desktops (Ansible)
Linux setup is declarative, using Ansible targetting `localhost`.
*   **Run configuration**:
    ```bash
    ansible-playbook -K ansible/local.yml
    ```
*   **Fedora Ventoy Setup**:
    ```bash
    ./linux/fedora/prepare_ventoy.sh
    ```

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

## Development Conventions

*   **Declarative Infrastructure as Code (Linux & macOS)**: The workstation setup is orchestrated by `ansible/local.yml`. Specific tasks are modularized under `ansible/tasks/`, templates in `ansible/templates/`, static files/scripts in `ansible/files/`, and OS variables in `ansible/vars/`.
*   **Idempotency**: The Ansible playbook and shell scripts are designed to be run multiple times safely without side effects.
*   **Secrets & Credentials**: Private workstation credentials (such as Syncthing pairing config `ansible/vars/secrets.yml`, `.ssh`, `.kube`, `.gnupg`, etc.) are protected using asymmetric `age` encryption via [backup_restore.sh](file:///home/boris/Workspace/os_bootstrap/backup_restore.sh).
    *   **Unattended Daily Backups**: `secrets-backup.timer` runs daily, uses the public `age` key to encrypt target dotfiles/secrets, verifies SHA-256 content hashes to avoid redundant snapshots, and pushes encrypted archives to the Synology NAS (`secrets_backup_dir`).
    *   **Day-0 Bootstrap Recovery**: On fresh OS installations, Ansible mounts the NAS, identifies missing secrets, and launches interactive decryption via Bitwarden CLI (`os_setup_secrets_key` note) or manual key entry before continuing with provisioning.


