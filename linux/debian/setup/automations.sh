#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "⚙️  Setting up automation services..."

# System services (run as root)
echo "-> Setting up system-wide update service..."
sudo cp "${SCRIPT_DIR}/../configs/system-update.service" /etc/systemd/system/
sudo cp "${SCRIPT_DIR}/../configs/system-update.timer" /etc/systemd/system/
echo "-> Reloading systemd daemon and enabling system timer..."
sudo systemctl daemon-reload
sudo systemctl enable --now system-update.timer
echo "✅ System automations enabled."

# User services (run as user)
echo "-> Setting up user-specific update service..."
mkdir -p ~/.config/systemd/user
cp "${SCRIPT_DIR}/../configs/update.service" ~/.config/systemd/user/
cp "${SCRIPT_DIR}/../configs/update.timer" ~/.config/systemd/user/
echo "-> Reloading user systemd daemon and enabling user timer..."
systemctl --user daemon-reload
systemctl --user enable --now update.timer
echo "✅ User automations enabled."
