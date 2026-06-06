I will record changes to this file just so i don't need to look at commit history every time

# Changelog

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
