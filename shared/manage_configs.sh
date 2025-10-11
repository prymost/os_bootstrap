#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Define source and destination paths for config files
declare -A CONFIG_FILES
CONFIG_FILES=(
    ["$HOME/.vimrc"]="$SCRIPT_DIR/.vimrc"
    ["$HOME/.zshrc"]="$SCRIPT_DIR/.zshrc"
    ["$HOME/.config/kinto/kinto.py"]="$SCRIPT_DIR/kinto.py"
    ["$HOME/.config/kitty/kitty.conf"]="$SCRIPT_DIR/kitty.conf"
)

# Backup function: copies files from system to repo
backup() {
    echo "Backing up config files to the repository..."
    for src in "${!CONFIG_FILES[@]}"; do
        dest="${CONFIG_FILES[$src]}"
        if [[ -f "$src" ]]; then
            echo "  -> Backing up $src to $dest"
            cp "$src" "$dest"
        else
            echo "  -> Source file not found, skipping: $src"
        fi
done
    echo "Backup complete!"
}

# Restore function: copies files from repo to system
restore() {
    echo "Restoring config files from the repository..."
    for dest in "${!CONFIG_FILES[@]}"; do
        src="${CONFIG_FILES[$dest]}"
        if [[ -f "$src" ]]; then
            # Create directory if it doesn't exist
            mkdir -p "$(dirname "$dest")"
            echo "  -> Restoring $src to $dest"
            cp "$src" "$dest"
        else
            echo "  -> Source file not found, skipping: $src"
        fi
done
    echo "Restore complete!"
}

# Main script logic
if [[ -z "${1-}" ]]; then
    echo "Please select an option:"
    select opt in backup restore quit; do
        case $opt in
            backup)
                backup
                break
                ;;
            restore)
                read -p "This will overwrite existing system configurations. Are you sure? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    restore
                else
                    echo "Restore cancelled."
                fi
                break
                ;;
            quit)
                echo "Exiting."
                break
                ;;
            *)
                echo "Invalid option $REPLY"
                ;;
        esac
    done
else
    if [[ "${1-}" == "backup" ]]; then
        backup
    elif [[ "${1-}" == "restore" ]]; then
        read -p "This will overwrite existing system configurations. Are you sure? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            restore
        else
            echo "Restore cancelled."
        fi
    else
        echo "Usage: $0 {backup|restore}"
        exit 1
    fi
fi
