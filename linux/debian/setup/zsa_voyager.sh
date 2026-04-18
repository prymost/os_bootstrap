#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

echo "⌨️  Configuring ZSA Voyager (udev rules)..."

# Ensure plugdev group exists
if ! getent group plugdev > /dev/null; then
    echo "👥 Creating plugdev group..."
    sudo groupadd plugdev
fi

# Add current user to plugdev group
if ! groups "$USER" | grep -q "\bplugdev\b"; then
    echo "👤 Adding $USER to plugdev group..."
    sudo usermod -aG plugdev "$USER"
fi

# Create udev rules for ZSA Voyager
# Based on https://github.com/zsa/wally/wiki/Linux-install
UDEV_RULES_FILE="/etc/udev/rules.d/50-zsa.rules"

echo "📝 Writing $UDEV_RULES_FILE..."
sudo tee "$UDEV_RULES_FILE" > /dev/null << 'EOF'
# Rules for Oryx web flashing and live training
KERNEL=="hidraw*", ATTRS{idVendor}=="16c0", MODE="0664", GROUP="plugdev"
KERNEL=="hidraw*", ATTRS{idVendor}=="3297", MODE="0664", GROUP="plugdev"

# Legacy rules for live training over webusb (Not needed for firmware v21+)
  # Rule for all ZSA keyboards
  SUBSYSTEM=="usb", ATTR{idVendor}=="3297", GROUP="plugdev"
  # Rule for the Moonlander
  SUBSYSTEM=="usb", ATTR{idVendor}=="3297", ATTR{idProduct}=="1969", GROUP="plugdev"
  # Rule for the Ergodox EZ
  SUBSYSTEM=="usb", ATTR{idVendor}=="feed", ATTR{idProduct}=="1307", GROUP="plugdev"
  # Rule for the Planck EZ
  SUBSYSTEM=="usb", ATTR{idVendor}=="feed", ATTR{idProduct}=="6060", GROUP="plugdev"

# Wally Flashing rules for the Ergodox EZ
ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", ENV{ID_MM_DEVICE_IGNORE}="1"
ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789A]?", ENV{MTP_NO_PROBE}="1"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789ABCD]?", MODE:="0666"
KERNEL=="ttyACM*", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", MODE:="0666"

# Keymapp / Wally Flashing rules for the Moonlander and Planck EZ
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE:="0666", SYMLINK+="stm32_dfu"
# Keymapp Flashing rules for the Voyager
SUBSYSTEMS=="usb", ATTRS{idVendor}=="3297", MODE:="0666", SYMLINK+="ignition_dfu"
EOF

echo "🔄 Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "✅ ZSA Voyager configuration completed!"
