#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

echo "🔄 Updating system packages..."

# Update apt packages
echo "📦 Updating apt packages..."
apt update -qq && apt upgrade -y -qq
echo "✅ apt packages updated!"

# Update Calibre
if command -v calibre &> /dev/null; then
    echo "📚 Updating Calibre..."
    wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sh /dev/stdin
    echo "✅ Calibre updated!"
else
    echo "ℹ️ Calibre not found, skipping."
fi

echo "🧹 Cleaning up..."
apt autoremove -y -qq
apt autoclean -qq

echo "✅ System updates completed!"

