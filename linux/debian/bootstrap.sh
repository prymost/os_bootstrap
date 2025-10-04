#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "🚀 Starting PopOS/Debian bootstrap process..."
echo "📁 Script directory: $SCRIPT_DIR"

# Run compatibility check first
echo "🔍 Running compatibility check..."
if [[ -x "${SCRIPT_DIR}/check_compatibility.sh" ]]; then
    "${SCRIPT_DIR}/check_compatibility.sh"
else
    echo "❌ Compatibility check script not found or not executable"
    exit 1
fi

echo ""
read -p "Continue with bootstrap? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Bootstrap cancelled by user"
    exit 1
fi

echo "🔧 Running initial setup..."
if [[ -x "${SCRIPT_DIR}/setup/initial.sh" ]]; then
    "${SCRIPT_DIR}/setup/initial.sh"
else
    echo "❌ Initial setup script not found or not executable"
    exit 1
fi

echo "⚙️  Applying OS tweaks..."
if [[ -x "${SCRIPT_DIR}/setup/os_tweaks.sh" ]]; then
    "${SCRIPT_DIR}/setup/os_tweaks.sh"
else
    echo "❌ OS tweaks script not found or not executable"
    exit 1
fi

echo "📦 Installing applications and packages..."
if [[ -x "${SCRIPT_DIR}/setup/my_installs.sh" ]]; then
    "${SCRIPT_DIR}/setup/my_installs.sh"
else
    echo "❌ Installation script not found or not executable"
    exit 1
fi

echo "🔄 Restoring configuration files..."
if [[ -x "${SCRIPT_DIR}/shared/manage_configs.sh" ]]; then
    "${SCRIPT_DIR}/shared/manage_configs.sh restore"
else
    echo "❌ Configuration management script not found or not executable"
    exit 1
fi

echo "⚙️  Setting up automations..."
if [[ -x "${SCRIPT_DIR}/setup/automations.sh" ]]; then
    "${SCRIPT_DIR}/setup/automations.sh"
else
    echo "❌ Automations script not found or not executable"
    exit 1
fi

echo "✅ Bootstrap process completed!"
echo "🔄 Please restart your session to ensure all changes take effect."
