#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "🚀 Starting PopOS/Debian bootstrap process..."
echo "📁 Script directory: $SCRIPT_DIR"

# ── Desktop detection ────────────────────────────────────────────────────────
# Reads XDG_CURRENT_DESKTOP if available; falls back to an interactive prompt.
detect_desktop() {
    local desktop="${XDG_CURRENT_DESKTOP:-}"

    if [[ "$desktop" == *"COSMIC"* ]]; then
        echo "cosmic"
    elif [[ "$desktop" == *"GNOME"* ]]; then
        echo "gnome"
    else
        echo "" # unknown — caller will prompt
    fi
}

DESKTOP=$(detect_desktop)

if [[ -z "$DESKTOP" ]]; then
    echo ""
    echo "ℹ️  Could not auto-detect desktop (XDG_CURRENT_DESKTOP='${XDG_CURRENT_DESKTOP:-unset}')."
    echo "   Select which desktop to configure:"
    select opt in "cosmic" "gnome"; do
        case $opt in
            cosmic|gnome)
                DESKTOP="$opt"
                break
                ;;
            *)
                echo "Invalid choice, please select 1 or 2."
                ;;
        esac
    done
fi

echo ""
echo "🖥️  Configuring for desktop: $DESKTOP"

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

# ── Shared setup ─────────────────────────────────────────────────────────────
run_script() {
    local script="$1"
    if [[ -x "$script" ]]; then
        "$script"
    else
        echo "❌ Script not found or not executable: $script"
        exit 1
    fi
}

echo "🔧 Running initial setup..."
run_script "${SCRIPT_DIR}/setup/initial.sh"

echo "⚙️  Applying system tweaks..."
run_script "${SCRIPT_DIR}/setup/system_tweaks.sh"

echo "📦 Installing common applications and packages..."
run_script "${SCRIPT_DIR}/setup/my_installs.sh"

# ── Desktop-specific setup ───────────────────────────────────────────────────
echo "📦 Installing $DESKTOP-specific packages..."
run_script "${SCRIPT_DIR}/setup/${DESKTOP}/packages.sh"

echo "⚙️  Applying $DESKTOP UI tweaks..."
run_script "${SCRIPT_DIR}/setup/${DESKTOP}/ui_tweaks.sh"

# ── Finalise ─────────────────────────────────────────────────────────────────
echo "🔄 Restoring configuration files..."
if [[ -x "${SCRIPT_DIR}/../../shared/manage_configs.sh" ]]; then
    "${SCRIPT_DIR}/../../shared/manage_configs.sh" restore
else
    echo "❌ Configuration management script not found or not executable"
    exit 1
fi

echo "⚙️  Setting up automations..."
run_script "${SCRIPT_DIR}/setup/automations.sh"

echo "✅ Bootstrap process completed!"
echo "🔄 Please restart your session to ensure all changes take effect."

