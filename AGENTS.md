# Project Overview

This project contains a set of bootstrap scripts and playbooks for automating the setup of personal machines across multiple platforms: Windows 11, macOS, WSL Ubuntu, and Linux Desktops (Fedora and Pop!_OS/Debian).

## Key Technologies

*   **Windows:** PowerShell, Winget
*   **macOS:** Bash, Homebrew
*   **Linux (Fedora & Pop!_OS/Debian):** Ansible, DNF, APT, Flatpak, Linuxbrew, Systemd Timers
*   **Fedora Automation:** Anaconda Kickstart (`ks.cfg`), custom ISO builder (`xorriso`)

## Building and Running

### 1. Linux Desktops (Ansible)
Linux setup is declarative, using Ansible targetting `localhost`.
*   **Run configuration**:
    ```bash
    ansible-playbook -K ansible/local.yml
    ```
*   **Fedora Semi-Automated ISO Build**:
    ```bash
    ./linux/fedora/build_iso.sh
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

*   **Declarative Infrastructure as Code (Linux)**: Package installs, purges, configurations, systemd services, and desktop custom shortcuts are specified in `ansible/local.yml` and variables in `ansible/vars/`.
*   **Idempotency**: The Ansible playbook and shell scripts are designed to be run multiple times safely without side effects.
*   **Shared Configuration**: The `shared` directory contains shared templates (e.g. `.zshrc`, `kitty.conf`, `.vimrc`) linked via GNU Stow.
