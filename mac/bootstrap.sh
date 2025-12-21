#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "🚀 Starting macOS bootstrap process..."
echo "📁 Script directory: $SCRIPT_DIR"

# Run compatibility check first
echo "🔍 Running compatibility check..."
"${SCRIPT_DIR}/check_compatibility.sh"

echo ""
read -p "Continue with bootstrap? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Bootstrap cancelled by user"
    exit 1
fi

echo "🔧 Running initial setup..."
"${SCRIPT_DIR}/setup/initial.sh"

echo "⚙️  Configuring macOS settings..."
"${SCRIPT_DIR}/setup/configure_osx.sh"

echo "📦 Installing applications and packages..."
"${SCRIPT_DIR}/setup/my_installs.sh"

echo "🔄 Restarting affected applications..."
# Restart affected applications
for app in "Activity Monitor" "cfprefsd" "Dock" "Finder" "SystemUIServer"; do
    killall "${app}" &> /dev/null || true
done

echo "⚙️  Setting up automations..."
"${SCRIPT_DIR}/setup/automations.sh"

echo "✅ Bootstrap process completed!"
echo "🔄 Please restart your computer to ensure all changes take effect."

# Uncomment the line below if you want to restore from backup
# "${SCRIPT_DIR}/setup/restore.sh"
