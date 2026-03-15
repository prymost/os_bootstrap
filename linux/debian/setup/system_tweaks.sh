#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

echo "🚀 Applying system-level performance tweaks..."

# Reduce swappiness for better desktop responsiveness
grep -q "vm.swappiness" /etc/sysctl.conf || echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null

# Increase inotify watch limit (needed by IDEs, file watchers)
grep -q "fs.inotify.max_user_watches" /etc/sysctl.conf || echo 'fs.inotify.max_user_watches=524288' | sudo tee -a /etc/sysctl.conf > /dev/null

sudo sysctl -p

# Enable periodic SSD TRIM
sudo systemctl enable --now fstrim.timer

echo "✅ System tweaks applied!"
