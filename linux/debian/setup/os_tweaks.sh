#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

echo "⚙️  Applying OS tweaks and customizations..."

# Screen off after 20 min
echo "🔋 Setting screen timeout to 20 minutes..."
gsettings set org.gnome.desktop.session idle-delay 1200
echo "✅ Screen timeout configured"

# Performance & System tweaks
echo "🚀 Applying performance tweaks..."
# Reduce swappiness (better for systems with plenty of RAM)
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null

# Enable SSD TRIM (if using SSD)
if sudo systemctl enable fstrim.timer 2>/dev/null; then
    echo "✅ SSD TRIM timer enabled"
else
    echo "⚠️  Could not enable SSD TRIM timer (may not be needed)"
fi

# GNOME Desktop tweaks
echo "🎨 Configuring GNOME desktop..."
# Show battery percentage in top bar
gsettings set org.gnome.desktop.interface show-battery-percentage true

# Enable dark theme
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Show weekday in top bar
gsettings set org.gnome.desktop.interface clock-show-weekday true

# Enable tap to click on touchpad
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true

# Disable hot corners
# gsettings set org.gnome.desktop.interface enable-hot-corners false

# Show hidden files in file manager
gsettings set org.gtk.Settings.FileChooser show-hidden true

# Minimize/maximize buttons
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'

# Keyboard & Input tweaks
echo "⌨️  Configuring keyboard and input..."
# Faster key repeat
gsettings set org.gnome.desktop.peripherals.keyboard repeat-interval 30
gsettings set org.gnome.desktop.peripherals.keyboard delay 300
gsettings set org.freedesktop.ibus.panel.emoji hotkey "[]"

# File Manager (Nautilus) tweaks
echo "📁 Configuring file manager..."
if command -v nautilus &> /dev/null; then
    # List view by default
    gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'

    # Show full path in title bar
    gsettings set org.gnome.nautilus.preferences always-use-location-entry true
else
    echo "⚠️  Nautilus not found, skipping file manager tweaks"
fi

# Privacy & Security tweaks
echo "🔒 Configuring privacy settings..."

# Shorter retention for trash and temp files
gsettings set org.gnome.desktop.privacy remove-old-trash-files true
gsettings set org.gnome.desktop.privacy remove-old-temp-files true
gsettings set org.gnome.desktop.privacy old-files-age 7

# Window Management tweaks
echo "🪟 Configuring window management..."
# Alt-Tab cycles through windows, not applications
gsettings set org.gnome.desktop.wm.keybindings switch-windows "['<Alt>Tab']"
gsettings set org.gnome.desktop.wm.keybindings switch-applications "['<Super>Tab']"

# Developer-friendly tweaks
echo "💻 Applying developer-friendly tweaks..."
# Increase file watch limits (useful for development tools)
echo 'fs.inotify.max_user_watches=524288' | sudo tee -a /etc/sysctl.conf > /dev/null

echo "✅ OS tweaks applied successfully!"
echo "ℹ️  Some changes may require a restart to take full effect"
