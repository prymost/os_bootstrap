#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
KS_FILE="${SCRIPT_DIR}/ks.cfg"
WORK_DIR=$(mktemp -d -t fedora-iso-build-XXXXXX)

# Cleanup on exit
cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "=========================================================="
echo "💿 Fedora Custom Automated ISO Builder"
echo "=========================================================="
echo ""

# Ensure we are running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "❌ This script must be run on Linux."
    exit 1
fi

# Ensure xorriso is installed
if ! command -v xorriso &> /dev/null; then
    echo "🔧 xorriso is not installed. Attempting to install it..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y xorriso
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y xorriso
    else
        echo "❌ Could not auto-install xorriso. Please install xorriso manually first."
        exit 1
    fi
fi

# Check for ks.cfg existence
if [[ ! -f "$KS_FILE" ]]; then
    echo "❌ Kickstart file not found at: $KS_FILE"
    exit 1
fi

# Download/Find original ISO
ORIGINAL_ISO=""
if [[ $# -gt 0 ]]; then
    ORIGINAL_ISO="$1"
else
    # Look for existing Everything netinst ISOs in current directory
    EXISTING_ISOS=( $(find . -maxdepth 1 -name "Fedora-Everything-netinst-x86_64-*.iso") )
    if [[ ${#EXISTING_ISOS[@]} -gt 0 ]]; then
        ORIGINAL_ISO="${EXISTING_ISOS[0]}"
        echo "📂 Found existing ISO: $ORIGINAL_ISO"
    else
        # Try to dynamically resolve the latest Fedora release URL
        echo "🔍 Querying latest Fedora Everything netinstall release info..."
        LATEST_INFO=$(python3 -c '
import urllib.request, json
try:
    with urllib.request.urlopen("https://fedoraproject.org/releases.json") as response:
        data = json.loads(response.read().decode())
    netinsts = [r for r in data if r.get("variant") == "Everything" and r.get("subvariant") == "Everything" and r.get("arch") == "x86_64" and r.get("version", "").isdigit()]
    if netinsts:
        latest = max(netinsts, key=lambda r: int(r["version"]))
        print(latest["version"] + " " + latest["link"])
except Exception:
    pass
' 2>/dev/null || true)

        FEDORA_VER="40"
        DEFAULT_ISO_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/40/Everything/x86_64/iso/Fedora-Everything-netinst-x86_64-40-1.14.iso"

        if [[ -n "$LATEST_INFO" ]]; then
            FEDORA_VER=$(echo "$LATEST_INFO" | cut -d' ' -f1)
            DEFAULT_ISO_URL=$(echo "$LATEST_INFO" | cut -d' ' -f2)
            echo "   ✅ Detected latest stable Fedora release: Version $FEDORA_VER"
        else
            echo "   ⚠️ Failed to resolve latest Fedora release info. Falling back to default version $FEDORA_VER"
        fi

        ORIGINAL_ISO=$(basename "$DEFAULT_ISO_URL")
        echo "🌐 No local ISO found. Downloading Fedora $FEDORA_VER Everything Netinstall ISO..."
        wget -c -O "$ORIGINAL_ISO" "$DEFAULT_ISO_URL"
    fi
fi

if [[ ! -f "$ORIGINAL_ISO" ]]; then
    echo "❌ ISO file not found: $ORIGINAL_ISO"
    exit 1
fi

OUTPUT_ISO="Fedora-Everything-KDE-Automated.iso"
echo "📂 Source ISO: $ORIGINAL_ISO"
echo "📂 Target ISO: $OUTPUT_ISO"
echo "📂 Workspace:  $WORK_DIR"
echo ""

# Step 1: Extract boot configs from source ISO
echo "🔍 Extracting original boot configurations..."
xorriso -osirrox on -indev "$ORIGINAL_ISO" \
    -extract /EFI/BOOT/grub.cfg "${WORK_DIR}/grub.cfg" \
    -extract /isolinux/isolinux.cfg "${WORK_DIR}/isolinux.cfg" \
    2>/dev/null || {
        echo "❌ Failed to extract boot configs from ISO."
        exit 1
    }

# Step 2: Modify boot configs to automate kickstart loading
echo "🔧 Modifying bootloader configurations..."

# Python inline helper to modify boot files safely using regex
python3 -c "
import re
import sys

# 1. Modify grub.cfg
with open('${WORK_DIR}/grub.cfg', 'r') as f:
    grub = f.read()

# Add kickstart and change label to FEDORA_KDE_AUTO
grub = re.sub(r'inst\.stage2=hd:LABEL=\S+', 'inst.stage2=hd:LABEL=FEDORA_KDE_AUTO inst.ks=hd:LABEL=FEDORA_KDE_AUTO:/ks.cfg', grub)
# Set default timeout to 2 seconds
grub = re.sub(r'set timeout=\d+', 'set timeout=2', grub)

with open('${WORK_DIR}/grub.cfg', 'w') as f:
    f.write(grub)

# 2. Modify isolinux.cfg
with open('${WORK_DIR}/isolinux.cfg', 'r') as f:
    iso_cfg = f.read()

# Add kickstart and change label to FEDORA_KDE_AUTO
iso_cfg = re.sub(r'inst\.stage2=hd:LABEL=\S+', 'inst.stage2=hd:LABEL=FEDORA_KDE_AUTO inst.ks=hd:LABEL=FEDORA_KDE_AUTO:/ks.cfg', iso_cfg)
# Set timeout to 20 (2 seconds)
iso_cfg = re.sub(r'timeout \d+', 'timeout 20', iso_cfg)

with open('${WORK_DIR}/isolinux.cfg', 'w') as f:
    f.write(iso_cfg)
"

# Step 3: Package new ISO by overlaying our modified files
echo "📦 Building custom bootable ISO (this may take a minute)..."
xorriso -indev "$ORIGINAL_ISO" \
    -outdev "$OUTPUT_ISO" \
    -volid "FEDORA_KDE_AUTO" \
    -map "$KS_FILE" /ks.cfg \
    -map "${WORK_DIR}/grub.cfg" /EFI/BOOT/grub.cfg \
    -map "${WORK_DIR}/isolinux.cfg" /isolinux/isolinux.cfg \
    -boot_image any replay \
    2>/dev/null

echo ""
echo "=========================================================="
echo "✅ Success! Automated ISO created: $OUTPUT_ISO"
echo "👉 Flash this ISO to your USB using Rufus, Ventoy, or dd:"
echo "   sudo dd if=$OUTPUT_ISO of=/dev/sdX bs=4M status=progress oflag=sync"
echo "=========================================================="
