I will record changes to this file just so i don't need to look at commit history every time

# Changelog

2026-09-18:
- Restored active Syncthing pairing credentials into gitignored `ansible/vars/secrets.yml` from running config.
- Added anti-degradation safeguards to `backup_restore.sh` via `secrets_backup_required_targets` in `ansible/vars/default.yml` (`ansible/vars/secrets.yml`, `.ssh`), preventing unattended runs from creating hollow snapshots or overwriting `secrets-latest.tar.gz.age` when critical secrets are absent.
- Added `--force` flag to `backup_restore.sh backup` to optionally allow overriding the required targets check.
- Added `ConditionPathExists` for `secrets.yml` to `secrets-backup.service` in `ansible/tasks/backup.yml` and active user systemd unit to prevent automated backup execution on unprovisioned/day-0 systems.
- Added interactive snapshot selection menu and post-restore target verification to `backup_restore.sh restore`.

2026-09-07:
- Configured KDE Plasma panel position to be at the top instead of the bottom in `ansible/files/configure-kde.sh`.

2026-09-02:
- Implemented asymmetric `age`-encrypted secrets and dotfiles backup system via `backup_restore.sh`.
- Integrated Bitwarden CLI (`bw`) for automated day-0 private key storage and retrieval (`os_setup_secrets_key` note).
- Added unattended automated daily backups (`secrets-backup.service` and `secrets-backup.timer`) pushing encrypted archives to Synology NAS with SHA-256 change detection and 5-snapshot retention.
- Added automated bootstrap recovery hook in `ansible/local.yml` (`ansible/tasks/restore_secrets.yml`) to restore `.ssh`, `.kube`, `.gitconfig`, `.gnupg`, and `secrets.yml` on fresh installs.
- Updated `check_status.sh` to monitor secrets backup timer and report latest archive status.
- Added `age` to `common_cli_packages` and `bitwarden-cli` to `homebrew_packages`.
- Updated `AGENTS.md` and `README.md` with complete documentation on secrets management.

2026-08-08:
- Added `pibox` Docker sandbox setup and shell integration for running isolated `pi` sessions.

2026-07-04:
- Integrated automated local Syncthing directory synchronization with a remote Synology NAS.
- Created a gitignored local `ansible/vars/secrets.yml` file to store private pairing parameters (such as Device IDs, addresses, and local folder paths) securely.
- Added a Python utility `ansible/files/configure-syncthing.py` for early input validation and XML-based device/folder configuration.
- Added modular Ansible tasks in `ansible/tasks/syncthing.yml` to handle validation, user lingering via `loginctl`, systemd user service management, and dynamic path resolution.
- Registered the `syncthing` package in `ansible/vars/default.yml` and included the tasks in `ansible/local.yml`.
- Added python compiled cache (`__pycache__/`, `*.pyc`, etc.) to `.gitignore`.
- Documented Syncthing secrets and manual pairing instructions in `README.md` and `AGENTS.md`.

2026-06-23:
- Added `io.speedofsound.SpeedOfSound` Flatpak to default packages list for declarative offline voice dictation.
- Restructured Ansible package tasks and playbook tags to allow running only package-related steps via `--tags packages`.

2026-06-07:
- Fixed an issue where running the Ansible playbook deleted the Kitty configuration file from the repository due to the parent directory symlink.

2026-06-05:
- Refactored monolithic Ansible playbook into modular task files (`tasks/`), templates (`templates/`), and scripts/rules (`files/`) to improve readability and adherence to SRP, DRY, and KISS principles.

2026-05-31:
- Removed custom ISO builder script (`build_iso.sh`) and related references.
- Updated Ventoy preparation script (`prepare_ventoy.sh`) to automatically resolve and download the latest stable Fedora Everything Netinstall ISO if not found.

2026-05-28:
- Migrated Pop!_OS and Fedora KDE configurations to a unified declarative Ansible playbook (`ansible/local.yml`).
- Added automated Fedora Kickstart config (`ks.cfg`) and custom ISO builder script (`build_iso.sh`).

2026-04-18:
- Updated Kitty config to match iTerm2
- Added ZSA stuff and key mapping overrides for Cosmic
2025-12-21:
- Added script for updating mac on schedule
2025-11-09:
- Updated the script for updating linux on schedule to fix a bug where it was running before network was up and homebrew update was failing.

2025-10-04:
- Created a script for updating linux on schedule

2025-09-27:
- Just created this file. Everything before this date is in commit history.
- Added kinto.py config file to repo.
- Added homebrew to debian setup script.
- Tweaked how vscode is installed on debian.
- Added script for backing up and restoring config files.
