#!/usr/bin/env bash
set -euo pipefail

# Download and run the installer
curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin

# Create symlinks in local bin
mkdir -p "${HOME}/.local/bin"
ln -sf "${HOME}/.local/kitty.app/bin/kitty" "${HOME}/.local/bin/kitty"
ln -sf "${HOME}/.local/kitty.app/bin/kitten" "${HOME}/.local/bin/kitten"

# Setup desktop integrations
mkdir -p "${HOME}/.local/share/applications"
cp "${HOME}/.local/kitty.app/share/applications/kitty.desktop" "${HOME}/.local/share/applications/"
cp "${HOME}/.local/kitty.app/share/applications/kitty-open.desktop" "${HOME}/.local/share/applications/"

# Correct icon and binary paths in desktop files
sed -i "s|Icon=kitty|Icon=${HOME}/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" "${HOME}/.local/share/applications"/kitty*.desktop
sed -i "s|Exec=kitty|Exec=${HOME}/.local/kitty.app/bin/kitty|g" "${HOME}/.local/share/applications"/kitty*.desktop

# Set as default XDG terminal
echo 'kitty.desktop' > "${HOME}/.config/xdg-terminals.list"
