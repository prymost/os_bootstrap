#!/usr/bin/env bash

# Select the global dark theme and prefer-dark for GTK apps
lookandfeeltool -a org.fedoraproject.fedoradark.desktop || true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true

# Remove the previous start menu shortcut customization to prevent conflicts
kwriteconfig6 --file kglobalshortcutsrc --group "plasmashell" --key "activate application launcher" --delete || true

# Set keyboard shortcut to launch krunner to Ctrl+Space
kwriteconfig6 --file kglobalshortcutsrc --group "krunner" --key "_launch" "$(printf 'Ctrl+Space\tAlt+Space\tSearch')"
kwriteconfig6 --file kglobalshortcutsrc --group "org.kde.krunner.desktop" --key "_launch" "$(printf 'Ctrl+Space\tAlt+Space\tSearch')"

# Map PrintScreen to Spectacle rectangular region capture
kwriteconfig6 --file kglobalshortcutsrc --group "org.kde.spectacle.desktop" --key "RectangularRegion" "$(printf 'Print\tnone\tCapture Rectangular Region')"
kwriteconfig6 --file kglobalshortcutsrc --group "org.kde.spectacle.desktop" --key "_launch" "$(printf 'Meta+Print\tnone\tLaunch Spectacle')"

# Configure Task Switcher to only show current screen
kwriteconfig6 --file kwinrc --group "TabBox" --key "ShowOnlyCurrentScreen" "true"
kwriteconfig6 --file kwinrc --group "TabBox" --key "ActivitiesMode" "1"
kwriteconfig6 --file kwinrc --group "TabBox" --key "DesktopMode" "1"

# Set keyboard repeat speed and delay
kwriteconfig6 --file kcminputrc --group "Keyboard" --key "RepeatDelay" "300"
kwriteconfig6 --file kcminputrc --group "Keyboard" --key "RepeatRate" "30"

# Set screen lock idle timeout to 20 minutes
kwriteconfig6 --file kscreenlockerrc --group "Daemon" --key "Timeout" "20"
kwriteconfig6 --file kscreenlockerrc --group "Daemon" --key "Autolock" "true"

# Reload configs dynamically
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
dbus-send --session --dest=org.kde.keyboard --type=method_call /Layouts org.kde.KeyboardLayouts.reloadConfig || true
dbus-send --session --dest=org.kde.KWin --type=method_call /KWin org.kde.KWin.reconfigure || true
