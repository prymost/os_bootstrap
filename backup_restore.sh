#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

# List of files and directories in $HOME to backup/restore.
# Excludes flatpaks (e.g. .var) and directories managed by this repo (e.g. stow links like .zshrc, .vimrc).
TARGETS=(
    ".ssh"
    ".kube"
    ".gitconfig"
    ".zsh_history"
    ".gnupg"
)

# Color codes for status output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_err() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

show_usage() {
    cat << EOF
Usage: $0 [options] [backup|restore] [backup_directory]

Arguments:
  backup_directory   The directory where backup data is or will be stored.
                     Can be a local path or a path to a mounted drive/USB.

Options:
  -d, --dry-run      Show what would be done without making any changes.
  -c, --copy         Force use copy mode (default for backup).
  -m, --move         Force use move mode (default for restore).
  -h, --help         Show this help message.

Examples:
  # Dry-run a default backup (copies)
  $0 --dry-run backup /media/boris/DataDrive/Backup/dotfiles

  # Run a default restore (moves)
  $0 restore /media/boris/DataDrive/Backup/dotfiles

  # Force move files during a backup
  $0 --move backup /media/boris/DataDrive/Backup/dotfiles
EOF
}

# ─── OPTION PARSING ─────────────────────────────────────────────────────────

DRY_RUN=false
FORCE_MODE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -c|--copy)
            FORCE_MODE="copy"
            shift
            ;;
        -m|--move)
            FORCE_MODE="move"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            log_err "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            # Stop parsing options if we hit the action argument (backup/restore)
            break
            ;;
    esac
done

if [[ $# -lt 2 ]]; then
    show_usage
    exit 1
fi

ACTION="$1"
BACKUP_DIR="${2%/}" # Remove trailing slash if any

if [[ "$ACTION" != "backup" && "$ACTION" != "restore" ]]; then
    log_err "Invalid action: '$ACTION'. Must be 'backup' or 'restore'."
    show_usage
    exit 1
fi

# Determine full absolute path of backup directory
if [[ ! "$BACKUP_DIR" =~ ^/ ]]; then
    BACKUP_DIR="$(pwd)/$BACKUP_DIR"
fi

# Determine whether we copy or move
# Default is 'copy' for backup, 'move' for restore, unless overridden
MODE="$FORCE_MODE"
if [[ -z "$MODE" ]]; then
    if [[ "$ACTION" == "backup" ]]; then
        MODE="copy"
    else
        MODE="move"
    fi
fi

# Helper to execute or just print commands based on dry-run setting.
# Returns the status of the executed command.
exec_cmd() {
    local cmd_desc="$1"
    shift # The remaining arguments form the actual command

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would run: $*"
        return 0
    else
        # Run the command and return its exit status
        "$@"
    fi
}

# ─── RUN OPERATIONS ──────────────────────────────────────────────────────────

run_backup() {
    log_info "Starting backup process to: ${BACKUP_DIR} (Mode: ${MODE}, Dry-run: ${DRY_RUN})"

    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$BACKUP_DIR"
    else
        exec_cmd "Create backup directory" mkdir -p "$BACKUP_DIR"
    fi

    for item in "${TARGETS[@]}"; do
        local src="$HOME/$item"
        local dest="$BACKUP_DIR/$item"

        if [[ ! -e "$src" ]]; then
            log_warn "Target '$item' does not exist in home directory. Skipping."
            continue
        fi

        log_info "Backing up: $item"

        # Ensure parent directories exist
        if [[ "$DRY_RUN" == "false" ]]; then
            mkdir -p "$(dirname "$dest")"
        else
            exec_cmd "Create parent directory" mkdir -p "$(dirname "$dest")"
        fi

        local status=0
        if [[ "$MODE" == "copy" ]]; then
            exec_cmd "Copy $item" cp -a "$src" "$dest" || status=$?
            if [[ $status -eq 0 ]]; then
                log_success "Successfully backed up: $item (copied)"
            else
                log_err "Failed to back up: $item (exit code $status)"
            fi
        else
            exec_cmd "Move $item" mv "$src" "$dest" || status=$?
            if [[ $status -eq 0 ]]; then
                log_success "Successfully backed up: $item (moved)"
            else
                log_err "Failed to back up: $item (exit code $status)"
            fi
        fi
    done
    log_success "Backup process complete!"
}

run_restore() {
    log_info "Starting restore process from: ${BACKUP_DIR} (Mode: ${MODE}, Dry-run: ${DRY_RUN})"

    if [[ ! -d "$BACKUP_DIR" && "$DRY_RUN" == "false" ]]; then
        log_err "Backup directory does not exist: $BACKUP_DIR"
        exit 1
    fi

    for item in "${TARGETS[@]}"; do
        local src="$BACKUP_DIR/$item"
        local dest="$HOME/$item"

        if [[ ! -e "$src" ]]; then
            log_warn "Target '$item' not found in backup directory. Skipping."
            continue
        fi

        # If it already exists in HOME, safely back it up first to prevent data loss
        if [[ -e "$dest" ]]; then
            local backup_suffix=".bak.$(date +%s)"
            log_warn "Destination '$dest' already exists. Renaming existing to '$item$backup_suffix'"
            local rename_status=0
            exec_cmd "Backup existing file" mv "$dest" "$dest$backup_suffix" || rename_status=$?
            if [[ $rename_status -ne 0 ]]; then
                log_err "Failed to rename existing '$dest' to '$dest$backup_suffix'. Aborting restore for this item."
                continue
            fi
        fi

        log_info "Restoring: $item"

        if [[ "$DRY_RUN" == "false" ]]; then
            mkdir -p "$(dirname "$dest")"
        else
            exec_cmd "Create parent directory" mkdir -p "$(dirname "$dest")"
        fi

        local status=0
        if [[ "$MODE" == "copy" ]]; then
            exec_cmd "Copy $item" cp -a "$src" "$dest" || status=$?
            if [[ $status -eq 0 ]]; then
                log_success "Successfully restored: $item (copied)"
            else
                log_err "Failed to restore: $item (exit code $status)"
            fi
        else
            exec_cmd "Move $item" mv "$src" "$dest" || status=$?
            if [[ $status -eq 0 ]]; then
                log_success "Successfully restored: $item (moved)"
            else
                log_err "Failed to restore: $item (exit code $status)"
            fi
        fi
    done
    log_success "Restore process complete!"
}

# Execute action
case "$ACTION" in
    backup)
        run_backup
        ;;
    restore)
        run_restore
        ;;
esac
