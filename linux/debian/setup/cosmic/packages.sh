#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

echo "📦 Installing COSMIC-specific packages..."

# wl-clipboard: Wayland-native clipboard CLI (replaces X11-only xsel)
sudo apt install -y -qq wl-clipboard

# Flameshot via Flatpak for proper XDG portal / Wayland support
echo "📦 Installing Flameshot (Flatpak)..."
if ! flatpak list --app 2>/dev/null | grep -q "org.flameshot.Flameshot"; then
    flatpak install --noninteractive flathub org.flameshot.Flameshot
    echo "✅ Flameshot installed"
else
    echo "✅ Flameshot already installed"
fi

echo "✅ COSMIC packages installed!"
