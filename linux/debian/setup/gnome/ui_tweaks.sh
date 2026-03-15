#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

echo "🎨 Configuring GNOME desktop UI..."

# ── Dark mode ────────────────────────────────────────────────────────────────
echo "🌙 Enabling Dark Mode..."
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-dark'

# ── Screen idle / lock timeout ───────────────────────────────────────────────
echo "🔋 Setting screen idle timeout (20 min)..."
gsettings set org.gnome.desktop.session idle-delay 1200
gsettings set org.gnome.desktop.screensaver lock-delay 0

# ── Key repeat ───────────────────────────────────────────────────────────────
echo "⌨️  Setting key repeat rate..."
gsettings set org.gnome.desktop.peripherals.keyboard repeat-interval 30
gsettings set org.gnome.desktop.peripherals.keyboard delay 300

# ── Shortcuts (Mac-style alignment) ─────────────────────────────────────────
# Launcher      → Ctrl+Space  (mirrors Cmd+Space)
# Close window  → Ctrl+Q      (mirrors Cmd+Q)
echo "⌨️  Configuring keyboard shortcuts..."
gsettings set org.gnome.desktop.wm.keybindings close "['<Control>q']"

# Custom shortcut: Launcher via Ctrl+Space
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
    "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ \
    name 'Launcher'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ \
    command 'gnome-shell-search'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ \
    binding '<Control>space'

echo "✅ GNOME UI tweaks applied!"
