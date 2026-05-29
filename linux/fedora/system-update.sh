#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

echo "🔄 Updating Fedora system packages..."

# Update DNF packages
echo "📦 Updating dnf packages..."
sudo dnf upgrade -y -q
echo "✅ dnf packages updated!"

# Update Calibre
if command -v calibre &> /dev/null; then
    echo "📚 Updating Calibre..."
    sudo dnf install -y -q xcb-util-cursor
    wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sh /dev/stdin
    echo "✅ Calibre updated!"
else
    echo "ℹ️ Calibre not found, skipping."
fi

echo "🧹 Cleaning up..."
sudo dnf autoremove -y -q
sudo dnf clean all -q

echo "✅ System updates completed!"
