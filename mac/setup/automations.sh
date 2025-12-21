#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
UPDATE_SCRIPT="${SCRIPT_DIR}/../update_tools.sh"
PLIST_TEMPLATE="${SCRIPT_DIR}/../configs/com.user.os_bootstrap.update.plist"
LOG_FILE="${HOME}/Library/Logs/os_bootstrap_update.log"
DEST_PLIST="${HOME}/Library/LaunchAgents/com.user.os_bootstrap.update.plist"

echo "⚙️  Setting up macOS automation..."

# Resolve absolute path for the update script
# Using python for reliable absolute path resolution if realpath is not available (common on minimal macOS)
if command -v realpath &> /dev/null; then
    UPDATE_SCRIPT_ABS=$(realpath "$UPDATE_SCRIPT")
else
    UPDATE_SCRIPT_ABS="$(cd "$(dirname "$UPDATE_SCRIPT")" && pwd)/$(basename "$UPDATE_SCRIPT")"
fi

if [[ ! -f "$UPDATE_SCRIPT_ABS" ]]; then
    echo "❌ Error: Update script not found at $UPDATE_SCRIPT_ABS"
    exit 1
fi

echo "-> Preparing LaunchAgent plist..."
if [[ ! -d "${HOME}/Library/LaunchAgents" ]]; then
    mkdir -p "${HOME}/Library/LaunchAgents"
fi

# Read template and replace placeholders
# We use | as delimiter to avoid issues with / in paths
sed -e "s|{{SCRIPT_PATH}}|$UPDATE_SCRIPT_ABS|g" \
    -e "s|{{LOG_PATH}}|$LOG_FILE|g" \
    "$PLIST_TEMPLATE" > "$DEST_PLIST"

echo "-> Unloading existing task (if any)..."
# We try to bootout the service. If it's not loaded, it might fail, so we ignore errors.
# We use the plist path for bootout service target specification
launchctl bootout "gui/$(id -u)" "$DEST_PLIST" 2>/dev/null || true

echo "-> Loading new task..."
launchctl bootstrap "gui/$(id -u)" "$DEST_PLIST"

echo "✅ macOS automation enabled."
echo "   - Script: $UPDATE_SCRIPT_ABS"
echo "   - Schedule: Daily at 12:00 PM"
echo "   - Log: $LOG_FILE"
