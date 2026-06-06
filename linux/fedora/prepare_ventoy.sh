#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
KS_FILE="${SCRIPT_DIR}/ks.cfg"

echo "=========================================================="
echo "🔧 Ventoy Kickstart Automated Preparer"
echo "=========================================================="
echo ""

# Ask user if they want to format a new drive first
VENTOY_DIR=""
read -rp "❓ Do you want to format a new USB drive with Ventoy first? (y/N): " PREP_CHOICE
if [[ "$PREP_CHOICE" =~ ^[yY](es)?$ ]]; then
    echo "🔍 Scanning for disk devices..."
    mapfile -t BLK_DEVS < <(lsblk -d -n -o NAME,MODEL,SIZE,TRAN | grep -v "zram" || true)

    if [[ ${#BLK_DEVS[@]} -eq 0 ]]; then
        echo "❌ No disk devices found."
        exit 1
    fi

    echo ""
    echo "💾 Available Disk Devices:"
    for i in "${!BLK_DEVS[@]}"; do
        clean_dev=$(echo "${BLK_DEVS[i]}" | xargs)
        echo "   [$((i+1))] $clean_dev"
    done
    echo ""

    while true; do
        read -rp "❓ Select the device number to format with Ventoy: " DEV_NUM
        if [[ "$DEV_NUM" =~ ^[0-9]+$ ]] && (( DEV_NUM >= 1 && DEV_NUM <= ${#BLK_DEVS[@]} )); then
            SELECTED_DEV_LINE="${BLK_DEVS[DEV_NUM-1]}"
            SELECTED_DEV=$(echo "$SELECTED_DEV_LINE" | awk '{print $1}')
            break
        else
            echo "❌ Invalid selection. Please enter a number between 1 and ${#BLK_DEVS[@]}."
        fi
    done

    DEV_PATH="/dev/${SELECTED_DEV}"
    echo ""
    echo "⚠️  WARNING: ALL DATA ON $DEV_PATH WILL BE PERMANENTLY ERASED!"
    read -rp "❓ To confirm, please type the device name EXACTLY as '$SELECTED_DEV': " CONFIRM_NAME
    if [[ "$CONFIRM_NAME" != "$SELECTED_DEV" ]]; then
        echo "❌ Confirmation failed. Aborting."
        exit 1
    fi

    echo "🌐 Querying latest Ventoy release from GitHub..."
    VENTOY_URL=$(python3 -c '
import urllib.request, json
try:
    req = urllib.request.Request(
        "https://api.github.com/repos/ventoy/Ventoy/releases/latest",
        headers={"User-Agent": "Mozilla/5.0"}
    )
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
    for asset in data.get("assets", []):
        if "linux.tar.gz" in asset.get("name", ""):
            print(asset.get("browser_download_url"))
            break
except Exception:
    pass
' 2>/dev/null || true)

    if [[ -z "$VENTOY_URL" ]]; then
        VENTOY_URL="https://github.com/ventoy/Ventoy/releases/download/v1.1.12/ventoy-1.1.12-linux.tar.gz"
        echo "   ⚠️ Failed to query GitHub API. Using fallback: $VENTOY_URL"
    else
        echo "   ✅ Found Ventoy release: $(basename "$VENTOY_URL")"
    fi

    TEMP_DIR=$(mktemp -d -t vnt-prep-XXXXXX)
    echo "🌐 Downloading Ventoy package..."
    if command -v wget &> /dev/null; then
        wget -q --show-progress -O "${TEMP_DIR}/ventoy.tar.gz" "$VENTOY_URL"
    elif command -v curl &> /dev/null; then
        curl -L -o "${TEMP_DIR}/ventoy.tar.gz" "$VENTOY_URL"
    else
        echo "❌ Neither wget nor curl is installed. Please install one of them."
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    echo "📦 Extracting Ventoy..."
    tar -xzf "${TEMP_DIR}/ventoy.tar.gz" -C "$TEMP_DIR"
    VENTOY_EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d -name "ventoy-*" | head -n 1)

    if [[ -z "$VENTOY_EXTRACTED_DIR" ]]; then
        echo "❌ Failed to locate extracted Ventoy directory."
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Unmount any mounted partitions on the selected device first, as Ventoy2Disk
    # will fail if the device is in use (such as mounts with spaces in paths).
    echo "🔍 Checking for mounted partitions on $DEV_PATH..."
    mapfile -t MOUNTED_PARTS < <(lsblk -pln -o NAME,MOUNTPOINT "$DEV_PATH" | awk '$2 != "" {print $1}')
    for part in "${MOUNTED_PARTS[@]}"; do
        echo "   🚚 Unmounting partition $part..."
        if ! udisksctl unmount -b "$part" 2>/dev/null; then
            sudo umount "$part" || sudo umount -l "$part" || true
        fi
    done

    echo "🔧 Running Ventoy2Disk to format $DEV_PATH..."
    echo "🔒 Root privileges (sudo) are required to format the drive."
    pushd "${VENTOY_EXTRACTED_DIR}" >/dev/null
    # Run Ventoy2Disk from its own directory so its internal paths resolve correctly.
    # We run it interactively (-i) so the user can review Ventoy's own confirmation prompts.
    if ! sudo ./Ventoy2Disk.sh -i "$DEV_PATH"; then
        echo "❌ Ventoy installation script failed."
        popd >/dev/null
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    popd >/dev/null
    rm -rf "$TEMP_DIR"

    # Force a partition table reload and wait for udev to settle
    sudo partprobe "$DEV_PATH" || true
    sudo udevadm settle || true

    PARTITION=""
    PART2=""
    if [[ "$SELECTED_DEV" =~ ^(nvme|mmcblk|loop) ]]; then
        PARTITION="${DEV_PATH}p1"
        PART2="${DEV_PATH}p2"
    else
        PARTITION="${DEV_PATH}1"
        PART2="${DEV_PATH}2"
    fi

    # Verify that the Ventoy EFI partition actually exists to confirm successful formatting
    if [[ ! -b "$PART2" ]]; then
        echo "❌ Ventoy installation failed (EFI partition $PART2 not found)."
        exit 1
    fi

    echo "📂 Ventoy installation complete."
    echo "🚚 Mounting the new Ventoy partition..."
    sleep 3

    echo "🔗 Mounting $PARTITION..."
    MOUNT_OUT=$(udisksctl mount -b "$PARTITION" 2>/dev/null || true)
    
    if [[ -n "$MOUNT_OUT" ]]; then
        VENTOY_DIR=$(echo "$MOUNT_OUT" | awk -F ' at ' '{print $2}' | xargs)
        echo "   ✅ Ventoy mounted at: $VENTOY_DIR"
    else
        sleep 2
        VENTOY_PATHS=( $(find /media/boris -maxdepth 2 -name "Ventoy" -type d 2>/dev/null) )
        if [[ ${#VENTOY_PATHS[@]} -gt 0 ]]; then
            VENTOY_DIR="${VENTOY_PATHS[0]}"
            echo "   ✅ Found Ventoy drive at: $VENTOY_DIR"
        else
            echo "❌ Failed to auto-mount Ventoy drive. Please enter the mount path manually."
            read -rp "❓ Mount path (e.g. /media/boris/Ventoy): " VENTOY_DIR
        fi
    fi
else
    # Find mounted Ventoy USB drives in /media/boris
    echo "🔍 Searching for mounted Ventoy drives..."
    VENTOY_PATHS=( $(find /media/boris -maxdepth 2 -name "Ventoy" -type d 2>/dev/null) )
    if [[ ${#VENTOY_PATHS[@]} -eq 0 ]]; then
        # Fallback to any directory containing "ventoy" (case-insensitive)
        VENTOY_PATHS=( $(find /media/boris -maxdepth 2 -iname "*ventoy*" -type d 2>/dev/null) )
    fi

    if [[ ${#VENTOY_PATHS[@]} -eq 1 ]]; then
        VENTOY_DIR="${VENTOY_PATHS[0]}"
        DF_INFO=$(df -h "$VENTOY_DIR" 2>/dev/null | tail -n 1 | awk '{print "("$1 ", " $2 " total, " $4 " avail)"}')
        echo "   ✅ Found Ventoy drive at: $VENTOY_DIR $DF_INFO"
    elif [[ ${#VENTOY_PATHS[@]} -gt 1 ]]; then
        echo "   ⚠️ Multiple matching Ventoy drives found:"
        for i in "${!VENTOY_PATHS[@]}"; do
            DF_INFO=$(df -h "${VENTOY_PATHS[i]}" 2>/dev/null | tail -n 1 | awk '{print "("$1 ", " $2 " total, " $4 " avail)"}')
            echo "   [$((i+1))] ${VENTOY_PATHS[i]} $DF_INFO"
        done
        while true; do
            read -rp "❓ Please select a drive by number (1-${#VENTOY_PATHS[@]}): " CHOICE
            if [[ "$CHOICE" =~ ^[0-9]+$ ]] && (( CHOICE >= 1 && CHOICE <= ${#VENTOY_PATHS[@]} )); then
                VENTOY_DIR="${VENTOY_PATHS[CHOICE-1]}"
                break
            else
                echo "❌ Invalid selection. Please enter a number between 1 and ${#VENTOY_PATHS[@]}."
            fi
        done
        DF_INFO=$(df -h "$VENTOY_DIR" 2>/dev/null | tail -n 1 | awk '{print "("$1 ", " $2 " total, " $4 " avail)"}')
        echo "   ✅ Selected Ventoy drive: $VENTOY_DIR $DF_INFO"
    else
        read -rp "❓ Ventoy drive mount path not found. Please enter it manually (e.g. /media/boris/Ventoy): " VENTOY_DIR
    fi
fi

if [[ ! -d "$VENTOY_DIR" ]]; then
    echo "❌ Directory does not exist: $VENTOY_DIR"
    exit 1
fi

# Final confirmation step
echo ""
echo "👉 Target Ventoy Directory: $VENTOY_DIR"
DF_INFO_CONFIRM=$(df -h "$VENTOY_DIR" 2>/dev/null | tail -n 1 | awk '{print "Device: "$1 " | Size: " $2 " | Avail: " $4}')
if [[ -n "$DF_INFO_CONFIRM" ]]; then
    echo "👉 Target Storage Info:     $DF_INFO_CONFIRM"
fi
echo ""

read -rp "⚠️ Are you sure you want to write to this drive? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY](es)?$ ]]; then
    echo "❌ Execution cancelled by user."
    exit 1
fi

echo "📂 Copying ks.cfg to root of Ventoy drive..."
cp "$KS_FILE" "${VENTOY_DIR}/ks.cfg"

# Find Fedora Everything netinst ISOs on the Ventoy drive
echo "🔍 Scanning Ventoy drive for Fedora Everything ISOs..."
ISO_FILES=( $(find "$VENTOY_DIR" -maxdepth 2 -name "Fedora-Everything-netinst-x86_64-*.iso" 2>/dev/null) )

ISO_NAME=""
if [[ ${#ISO_FILES[@]} -gt 0 ]]; then
    ISO_NAME=$(basename "${ISO_FILES[0]}")
    echo "   ✅ Found ISO on Ventoy: $ISO_NAME"
else
    echo "   ⚠️ No Fedora Everything Netinstall ISO found on the Ventoy drive."
    echo "   Checking for a local ISO in the current directory..."
    LOCAL_ISOS=( $(find . -maxdepth 1 -name "Fedora-Everything-netinst-x86_64-*.iso" 2>/dev/null) )
    if [[ ${#LOCAL_ISOS[@]} -gt 0 ]]; then
        LOCAL_ISO="${LOCAL_ISOS[0]}"
        ISO_NAME=$(basename "$LOCAL_ISO")
        echo "   📂 Found local ISO: $LOCAL_ISO"
        echo "   🚚 Copying to Ventoy drive..."
        cp "$LOCAL_ISO" "${VENTOY_DIR}/${ISO_NAME}"
    else
        echo "   🔍 Querying latest Fedora Everything netinstall release info..."
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

        FEDORA_VER="44"
        DEFAULT_ISO_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/44/Everything/x86_64/iso/Fedora-Everything-netinst-x86_64-44-1.7.iso"

        if [[ -n "$LATEST_INFO" ]]; then
            FEDORA_VER=$(echo "$LATEST_INFO" | cut -d' ' -f1)
            DEFAULT_ISO_URL=$(echo "$LATEST_INFO" | cut -d' ' -f2)
            echo "   ✅ Detected latest stable Fedora release: Version $FEDORA_VER"
        else
            echo "   ⚠️ Failed to resolve latest Fedora release info. Falling back to default version $FEDORA_VER"
        fi

        ISO_NAME=$(basename "$DEFAULT_ISO_URL")
        TARGET_ISO_PATH="${VENTOY_DIR}/${ISO_NAME}"

        echo "   🌐 Downloading Fedora $FEDORA_VER Everything Netinstall ISO directly to Ventoy drive..."
        if command -v wget &> /dev/null; then
            wget -c -O "$TARGET_ISO_PATH" "$DEFAULT_ISO_URL"
        elif command -v curl &> /dev/null; then
            curl -C - -o "$TARGET_ISO_PATH" -L "$DEFAULT_ISO_URL"
        else
            echo "❌ Neither wget nor curl is installed. Please install one of them."
            exit 1
        fi
    fi
fi

# Ensure ventoy directory exists
mkdir -p "${VENTOY_DIR}/ventoy"

# Generate ventoy.json
echo "📝 Generating ${VENTOY_DIR}/ventoy/ventoy.json..."
cat <<EOF > "${VENTOY_DIR}/ventoy/ventoy.json"
{
    "auto_install": [
        {
            "image": "/${ISO_NAME}",
            "template": "/ks.cfg"
        }
    ]
}
EOF

echo ""
echo "=========================================================="
echo "✅ Ventoy drive prepared successfully!"
echo "=========================================================="
