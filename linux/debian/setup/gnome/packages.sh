#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

echo "📦 Installing GNOME-specific packages..."

sudo apt install -y -qq \
    gnome-sushi \
    xsel \
    flameshot

echo "✅ GNOME packages installed!"
