#!/usr/bin/env bash
# =============================================================================
# backup_restore.sh - Asymmetric age-encrypted backup and restore for secrets
# =============================================================================
# Supports:
#   genkey  : Generate age keypair, auto-store private key in Bitwarden, update default.yml
#   backup  : Unattended backup with deterministic SHA-256 change detection & retention (5)
#   restore : Streamed in-memory decryption via Bitwarden CLI or manual key paste
#   status  : View current status and backup archives on NAS
# =============================================================================

set -euo pipefail

# ── Paths & Defaults ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"
HOME_DIR="${HOME:-/home/boris}"

# Locate ansible/vars/default.yml (checking repo root first, then standard workspace fallback)
if [[ -f "${REPO_ROOT}/ansible/vars/default.yml" ]]; then
    DEFAULT_VARS_FILE="${REPO_ROOT}/ansible/vars/default.yml"
elif [[ -f "${HOME_DIR}/Workspace/os_bootstrap/ansible/vars/default.yml" ]]; then
    DEFAULT_VARS_FILE="${HOME_DIR}/Workspace/os_bootstrap/ansible/vars/default.yml"
else
    DEFAULT_VARS_FILE="${REPO_ROOT}/ansible/vars/default.yml"
fi

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper loggers
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_err()     { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Global temp files cleanup on exit
TMP_CLEANUP_PATHS=()
cleanup_on_exit() {
    if [[ ${#TMP_CLEANUP_PATHS[@]} -gt 0 ]]; then
        rm -rf "${TMP_CLEANUP_PATHS[@]}" 2>/dev/null || true
    fi
}
trap cleanup_on_exit EXIT

# Helper to read configuration from ansible/vars/default.yml
get_config_var() {
    local var_name="$1"
    local default_val="${2:-}"
    if [[ -f "$DEFAULT_VARS_FILE" ]]; then
        local val
        val=$(grep -E "^${var_name}:" "$DEFAULT_VARS_FILE" | head -n1 | sed -E "s/^${var_name}:[[:space:]]*[\"']?(.*)[\"']?[[:space:]]*\$/\1/" | sed 's/["'\'']//g' | xargs)
        if [[ -n "$val" ]]; then
            # Expand {{ nas_backup_base_dir }} or {{ target_home }}
            val="${val//\{\{ nas_backup_base_dir \}\}/${HOME_DIR}/Backup}"
            val="${val//\{\{ target_home \}\}/${HOME_DIR}}"
            echo "$val"
            return 0
        fi
    fi
    echo "$default_val"
}

# Helper to read targets array from ansible/vars/default.yml
get_config_targets() {
    if [[ -f "$DEFAULT_VARS_FILE" ]] && grep -q "^secrets_backup_targets:" "$DEFAULT_VARS_FILE"; then
        sed -n '/^secrets_backup_targets:/,/^[a-zA-Z_]/p' "$DEFAULT_VARS_FILE" \
            | grep -E '^[[:space:]]*-[[:space:]]*' \
            | sed -E 's/^[[:space:]]*-[[:space:]]*[\"'"'"']?([^\"'"'"']+)[\"'"'"']?/\1/' \
            | xargs -n1
    else
        echo ".ssh"
        echo ".kube"
        echo ".gitconfig"
        echo ".gnupg"
        echo ".zsh_history"
        echo "ansible/vars/secrets.yml"
    fi
}

# Helper to read required targets array from ansible/vars/default.yml
get_config_required_targets() {
    if [[ -f "$DEFAULT_VARS_FILE" ]] && grep -q "^secrets_backup_required_targets:" "$DEFAULT_VARS_FILE"; then
        sed -n '/^secrets_backup_required_targets:/,/^[a-zA-Z_]/p' "$DEFAULT_VARS_FILE" \
            | grep -E '^[[:space:]]*-[[:space:]]*' \
            | sed -E 's/^[[:space:]]*-[[:space:]]*[\"'"'"']?([^\"'"'"']+)[\"'"'"']?/\1/' \
            | xargs -n1
    else
        echo "ansible/vars/secrets.yml"
        echo ".ssh"
    fi
}

# Configuration settings (environment variables take precedence)
AGE_PUBLIC_KEY="${AGE_PUBLIC_KEY:-$(get_config_var "age_public_key" "")}"
BACKUP_DIR="${BACKUP_DIR:-$(get_config_var "secrets_backup_dir" "${HOME_DIR}/Backup/secrets_backups")}"
MAX_KEEP="${MAX_KEEP:-$(get_config_var "secrets_backup_max_keep" "5")}"
BW_ITEM_NAME="${BW_ITEM_NAME:-$(get_config_var "bitwarden_item_name" "os_setup_secrets_key")}"

# Populate targets
TARGETS=()
while IFS= read -r line; do
    [[ -n "$line" ]] && TARGETS+=("$line")
done < <(get_config_targets)

# Populate required targets (guards against degraded backups)
REQUIRED_TARGETS=()
while IFS= read -r line; do
    [[ -n "$line" ]] && REQUIRED_TARGETS+=("$line")
done < <(get_config_required_targets)

show_usage() {
    cat << EOF
${BOLD}Usage:${NC} $0 <command> [options]

${BOLD}Commands:${NC}
  ${BLUE}backup${NC}   [dir] [--force]    Run secrets backup (unattended, change-detected)
  ${BLUE}restore${NC}  [archive] [options] Restore secrets (interactive snapshot menu if archive omitted)
  ${BLUE}genkey${NC}                      Generate age keypair & save private key to Bitwarden
  ${BLUE}status${NC}                      Show backup configuration and latest backup info
  ${BLUE}help${NC}                        Show this help message

${BOLD}Backup Options:${NC}
  --force                 Proceed with backup even if required targets are missing

${BOLD}Restore Options:${NC}
  --from-bw               Fetch age private key automatically via Bitwarden CLI (bw)
  --key <key>             Provide age private key directly (or pass '-' to read from stdin)
  --dir <dir>             Specify custom backup directory (default: ${BACKUP_DIR})

${BOLD}Examples:${NC}
  $0 genkey
  $0 backup
  $0 backup --force
  $0 restore
  $0 restore --from-bw
  AGE_SECRET_KEY="AGE-SECRET-KEY-..." $0 restore
EOF
}

# ── Dependency Checks ─────────────────────────────────────────────────────────

check_tool() {
    local tool="$1"
    local install_hint="$2"
    if ! command -v "$tool" &>/dev/null; then
        log_err "Required tool '$tool' is not installed."
        log_err "$install_hint"
        return 1
    fi
    return 0
}

# ── 1. GENERATE KEYPAIR (genkey) ──────────────────────────────────────────────

cmd_genkey() {
    check_tool "age-keygen" "Install age via: sudo dnf install age (or apt install age / brew install age)" || exit 1

    echo -e "${BOLD}========================================================================${NC}"
    echo -e "${BOLD}🔑 Generating new age Keypair for Secrets Encryption${NC}"
    echo -e "${BOLD}========================================================================${NC}"

    local key_output
    key_output=$(age-keygen 2>/dev/null)
    local public_key
    public_key=$(echo "$key_output" | grep "public key:" | awk '{print $NF}')
    local secret_key
    secret_key=$(echo "$key_output" | grep -v "^#" | grep "AGE-SECRET-KEY-" | head -n1 | xargs)

    if [[ -z "$public_key" || -z "$secret_key" ]]; then
        log_err "Failed to parse generated age keypair."
        exit 1
    fi

    log_success "Generated age Public Key:  ${BLUE}${public_key}${NC}"
    log_info "Generated age Private Key: (Hidden for security)"

    # Automatically save private key to Bitwarden if bw CLI is available
    local bw_saved=false
    if command -v bw &>/dev/null; then
        check_tool "jq" "Install jq via: sudo dnf install jq (or apt install jq)" || true
        echo
        echo -e "${BOLD}🔐 Bitwarden CLI Integration${NC}"
        read -r -p "Would you like to automatically save the private key to Bitwarden item '${BW_ITEM_NAME}'? [Y/n] " bw_confirm
        bw_confirm="${bw_confirm:-Y}"
        if [[ "$bw_confirm" =~ ^[Yy]$ ]]; then
            # Ensure logged in / unlocked
            local bw_status
            bw_status=$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unauthenticated")
            local session_token="${BW_SESSION:-}"

            if [[ "$bw_status" == "unauthenticated" ]]; then
                log_info "Bitwarden is not logged in. Logging in now..."
                session_token=$(bw login --raw)
            elif [[ "$bw_status" == "locked" && -z "$session_token" ]]; then
                log_info "Bitwarden vault is locked. Unlocking now..."
                session_token=$(bw unlock --raw)
            fi

            export BW_SESSION="$session_token"

            # Check if item exists in Bitwarden
            local existing_id
            existing_id=$(bw list items --search "${BW_ITEM_NAME}" --session "$BW_SESSION" 2>/dev/null | jq -r ".[] | select(.name==\"${BW_ITEM_NAME}\") | .id" | head -n1 || true)

            if [[ -n "$existing_id" ]]; then
                log_info "Updating existing Bitwarden Secure Note '${BW_ITEM_NAME}' (ID: ${existing_id})..."
                local item_json
                item_json=$(bw get item "$existing_id" --session "$BW_SESSION" 2>/dev/null | jq --arg key "$secret_key" '.notes = $key')
                echo "$item_json" | bw encode | bw edit item "$existing_id" --session "$BW_SESSION" >/dev/null
                log_success "Updated '${BW_ITEM_NAME}' in Bitwarden vault!"
                bw_saved=true
            else
                log_info "Creating new Bitwarden Secure Note '${BW_ITEM_NAME}'..."
                local new_item_json
                new_item_json=$(jq -n --arg name "$BW_ITEM_NAME" --arg notes "$secret_key" '{type: 2, name: $name, notes: $notes}')
                echo "$new_item_json" | bw encode | bw create item --session "$BW_SESSION" >/dev/null
                log_success "Created '${BW_ITEM_NAME}' in Bitwarden vault!"
                bw_saved=true
            fi
            bw sync --session "$BW_SESSION" >/dev/null 2>&1 || true
        fi
    fi

    if [[ "$bw_saved" == "false" ]]; then
        echo
        echo -e "${YELLOW}========================================================================${NC}"
        echo -e "${YELLOW}⚠️ Manual Bitwarden Action Required:${NC}"
        echo -e "Create a Secure Note in Bitwarden named: ${BOLD}${BW_ITEM_NAME}${NC}"
        echo -e "Set Note contents to:"
        echo -e "${GREEN}${secret_key}${NC}"
        echo -e "${YELLOW}========================================================================${NC}"
    fi

    # Update ansible/vars/default.yml with public key
    if [[ -f "$DEFAULT_VARS_FILE" ]]; then
        if grep -q "^age_public_key:" "$DEFAULT_VARS_FILE"; then
            sed -i -E "s|^age_public_key:.*|age_public_key: \"${public_key}\"|" "$DEFAULT_VARS_FILE"
            log_success "Updated 'age_public_key' in ${DEFAULT_VARS_FILE}"
        fi
    fi

    echo
    log_success "Keypair setup complete! You are ready to run backups."
}

# ── 2. RUN BACKUP (backup) ───────────────────────────────────────────────────

cmd_backup() {
    # Restrict permissions for all created files/directories
    umask 077

    check_tool "age" "Install age via: sudo dnf install age (or apt install age / brew install age)" || exit 1
    check_tool "tar" "tar utility is required" || exit 1

    local dest_dir=""
    local force=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force|-f)
                force=true
                shift
                ;;
            -*)
                log_err "Unknown backup option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [[ -z "$dest_dir" ]]; then
                    dest_dir="$1"
                fi
                shift
                ;;
        esac
    done

    dest_dir="${dest_dir:-$BACKUP_DIR}"

    if [[ -z "$AGE_PUBLIC_KEY" ]]; then
        log_err "No age public key configured in ${DEFAULT_VARS_FILE} or AGE_PUBLIC_KEY environment variable."
        log_err "Run '$0 genkey' first to generate and configure your keypair."
        exit 1
    fi

    # Pre-flight check: ensure required targets exist before touching NAS archives
    local missing_required=()
    for req in "${REQUIRED_TARGETS[@]}"; do
        local req_path
        if [[ "$req" =~ ^\. ]]; then
            req_path="${HOME_DIR}/${req}"
        elif [[ "$req" =~ ^/ ]]; then
            req_path="${req}"
        else
            req_path="${REPO_ROOT}/${req}"
        fi

        if [[ ! -e "$req_path" && ! -L "$req_path" ]]; then
            missing_required+=("${req} (expected at ${req_path})")
        fi
    done

    if [[ ${#missing_required[@]} -gt 0 ]]; then
        if [[ "$force" == "true" ]]; then
            log_warn "Required backup target(s) missing, but continuing due to --force flag:"
            for m in "${missing_required[@]}"; do
                log_warn "  - $m"
            done
        else
            echo
            log_err "CRITICAL: Required secret target(s) missing from disk:"
            for m in "${missing_required[@]}"; do
                log_err "  - $m"
            done
            log_err "Aborting backup to prevent overwriting 'secrets-latest' with degraded data."
            log_err "Pass '--force' to proceed anyway if this omission is intentional."
            exit 1
        fi
    fi

    # Check that backup destination directory exists (triggers automount if applicable)
    mkdir -p "$dest_dir" 2>/dev/null || true
    if [[ ! -d "$dest_dir" ]]; then
        log_err "Backup destination directory '${dest_dir}' is not accessible. Is NAS mounted?"
        exit 1
    fi

    log_info "Starting secrets backup process to: ${dest_dir}"

    local tmp_stage
    tmp_stage=$(mktemp -d -t secrets_stage.XXXXXX)
    local tmp_tar
    tmp_tar=$(mktemp -t secrets_archive.XXXXXX.tar.gz)
    TMP_CLEANUP_PATHS+=("$tmp_stage" "$tmp_tar")

    mkdir -p "${tmp_stage}/home"
    mkdir -p "${tmp_stage}/repo"

    local found_count=0

    for item in "${TARGETS[@]}"; do
        local src_path
        local target_cat

        if [[ "$item" =~ ^\. ]]; then
            # Dotfile relative to $HOME
            src_path="${HOME_DIR}/${item}"
            target_cat="home"
        elif [[ "$item" =~ ^/ ]]; then
            # Absolute path
            src_path="${item}"
            target_cat="home"
        else
            # Repo-relative path
            src_path="${REPO_ROOT}/${item}"
            target_cat="repo"
        fi

        if [[ ! -e "$src_path" && ! -L "$src_path" ]]; then
            log_warn "Target '${item}' not found at '${src_path}'. Skipping."
            continue
        fi

        local dest_path="${tmp_stage}/${target_cat}/${item}"
        mkdir -p "$(dirname "$dest_path")"
        cp -a "$src_path" "$dest_path"
        log_info "Included target: ${item} (from ${src_path})"
        found_count=$((found_count + 1))
    done

    if [[ $found_count -eq 0 ]]; then
        log_warn "No secret targets found to back up. Aborting."
        exit 0
    fi

    # Remove any active runtime sockets (e.g. ssh-agent / gpg-agent sockets) before archiving
    find "$tmp_stage" -type s -delete 2>/dev/null || true

    # Deterministic content hash across staged files (excluding socket files)
    local current_hash
    current_hash=$(cd "$tmp_stage" && find home repo -type f ! -name "[sS].*" ! -name "*.sock" -exec sha256sum {} + 2>/dev/null | sort -k2 | sha256sum | awk '{print $1}')
    local latest_hash_file="${dest_dir}/secrets-latest.sha256"

    # Check for changes against previous backup
    if [[ -f "$latest_hash_file" ]]; then
        local prev_hash
        prev_hash=$(cat "$latest_hash_file" | awk '{print $1}')
        if [[ "$current_hash" == "$prev_hash" ]]; then
            log_success "No changes detected in secrets (SHA-256 matches latest backup: ${current_hash:0:12}...). Skipping new snapshot."
            exit 0
        fi
    fi

    # Create deterministic tarball (excluding runtime sockets from gnupg/ssh)
    tar --exclude='*/[sS].*' --exclude='*.sock' --exclude='*/agent/*' -czf "$tmp_tar" -C "$tmp_stage" home repo

    # Encrypt tarball with age public key
    local timestamp
    timestamp=$(date +"%Y-%m-%d_%H%M%S")
    local out_archive="${dest_dir}/secrets-${timestamp}.tar.gz.age"
    local latest_archive="${dest_dir}/secrets-latest.tar.gz.age"

    log_info "Encrypting archive with age public key (${AGE_PUBLIC_KEY:0:16}...)..."
    age -r "$AGE_PUBLIC_KEY" -o "$out_archive" "$tmp_tar"

    # Update latest pointer and sha256 hash
    cp -f "$out_archive" "$latest_archive"
    echo "$current_hash" > "$latest_hash_file"

    log_success "Created encrypted backup: $(basename "$out_archive")"
    log_success "Updated latest pointer:    $(basename "$latest_archive")"

    # Retention management: retain only the N most recent backups
    log_info "Managing retention (keeping ${MAX_KEEP} most recent snapshots)..."
    local old_backups
    old_backups=$(find "$dest_dir" -maxdepth 1 -name "secrets-[0-9]*.tar.gz.age" -type f | sort -r | tail -n +"$((MAX_KEEP + 1))" || true)
    if [[ -n "$old_backups" ]]; then
        while IFS= read -r file; do
            if [[ -n "$file" ]]; then
                log_info "Pruning old snapshot: $(basename "$file")"
                rm -f "$file"
            fi
        done <<< "$old_backups"
    fi

    log_success "Secrets backup complete!"
}

# ── 3. RUN RESTORE (restore) ─────────────────────────────────────────────────

cmd_restore() {
    # Restrict permissions for all restored files
    umask 077

    check_tool "age" "Install age via: sudo dnf install age (or apt install age / brew install age)" || exit 1
    check_tool "tar" "tar utility is required" || exit 1

    local archive_file=""
    local custom_dir="${BACKUP_DIR}"
    local from_bw=false
    local direct_key="${AGE_SECRET_KEY:-}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --from-bw)
                from_bw=true
                shift
                ;;
            --key)
                if [[ "$2" == "-" ]]; then
                    direct_key=$(cat)
                else
                    direct_key="$2"
                fi
                shift 2
                ;;
            --dir)
                custom_dir="$2"
                shift 2
                ;;
            -*)
                log_err "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [[ -z "$archive_file" ]]; then
                    archive_file="$1"
                fi
                shift
                ;;
        esac
    done

    # Resolve archive to restore (interactive selection if multiple snapshots exist and stdin is a TTY)
    if [[ -z "$archive_file" ]]; then
        local latest_file="${custom_dir}/secrets-latest.tar.gz.age"
        local snapshots=()
        if [[ -d "$custom_dir" ]]; then
            while IFS= read -r f; do
                [[ -n "$f" ]] && snapshots+=("$f")
            done < <(find "$custom_dir" -maxdepth 1 -name "secrets-[0-9]*.tar.gz.age" -type f 2>/dev/null | sort -r)
        fi

        if [[ -t 0 && ${#snapshots[@]} -gt 0 ]]; then
            echo -e "${BOLD}========================================================================${NC}"
            echo -e "${BOLD}📦 Backup Snapshot Selection (${custom_dir})${NC}"
            echo -e "${BOLD}========================================================================${NC}"
            echo -e "  [1] ${GREEN}$(basename "$latest_file")${NC} (Latest Pointer - $(du -h "$latest_file" 2>/dev/null | awk '{print $1}' || echo '?')) ${BOLD}[Default]${NC}"
            local idx=2
            for s in "${snapshots[@]}"; do
                local s_time
                s_time=$(stat -c '%y' "$s" 2>/dev/null || stat -f '%Sm' "$s" 2>/dev/null || echo "")
                echo -e "  [${idx}] $(basename "$s") ($(du -h "$s" 2>/dev/null | awk '{print $1}' || echo '?'), ${s_time:0:19})"
                idx=$((idx + 1))
            done
            echo
            read -r -p "Select snapshot to restore [1-$((idx - 1))] (default: 1): " choice
            choice="${choice:-1}"
            if [[ "$choice" == "1" ]]; then
                archive_file="$latest_file"
            elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 2 && "$choice" -lt "$idx" ]]; then
                archive_file="${snapshots[$((choice - 2))]}"
            else
                log_warn "Invalid selection '$choice'. Defaulting to latest snapshot."
                archive_file="$latest_file"
            fi
        else
            archive_file="$latest_file"
        fi
    fi

    # Trigger automount / verify existence
    ls "$archive_file" >/dev/null 2>&1 || true
    if [[ ! -f "$archive_file" ]]; then
        log_err "Backup archive not found at: '${archive_file}'"
        log_err "Please verify the NAS is mounted and reachable."
        exit 1
    fi

    log_info "Found backup archive: ${archive_file}"

    # Determine age private key
    local secret_key="$direct_key"

    if [[ -z "$secret_key" ]]; then
        if [[ "$from_bw" == "true" ]]; then
            # Bitwarden automated flow
            check_tool "bw" "Bitwarden CLI ('bw') is required for --from-bw. Install via: brew install bitwarden-cli" || exit 1
            
            local bw_status
            bw_status=$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unauthenticated")
            local session_token="${BW_SESSION:-}"

            if [[ "$bw_status" == "unauthenticated" ]]; then
                echo -e "${BOLD}🔐 Logging into Bitwarden CLI...${NC}"
                session_token=$(bw login --raw)
            elif [[ "$bw_status" == "locked" && -z "$session_token" ]]; then
                echo -e "${BOLD}🔐 Unlocking Bitwarden Vault...${NC}"
                session_token=$(bw unlock --raw)
            fi

            export BW_SESSION="$session_token"
            log_info "Fetching key '${BW_ITEM_NAME}' from Bitwarden..."
            secret_key=$(bw get notes "$BW_ITEM_NAME" --session "$BW_SESSION" 2>/dev/null || true)

            if [[ -z "$secret_key" ]]; then
                log_err "Failed to retrieve '${BW_ITEM_NAME}' note from Bitwarden."
                log_err "Falling back to manual key prompt..."
            fi
        fi
    fi

    # Interactive prompt if key still not found
    if [[ -z "$secret_key" ]]; then
        echo -e "${BOLD}========================================================================${NC}"
        echo -e "${BOLD}🔓 Secrets Decryption Key Required${NC}"
        echo -e "${BOLD}========================================================================${NC}"
        echo "Choose key retrieval method:"
        echo "  [1] Fetch from Bitwarden CLI (bw)"
        echo "  [2] Paste age Private Key manually"
        read -r -p "Select option [1/2] (default: 1): " key_choice
        key_choice="${key_choice:-1}"

        if [[ "$key_choice" == "1" ]]; then
            check_tool "bw" "Bitwarden CLI ('bw') is required. Install via: brew install bitwarden-cli" || exit 1
            local bw_status
            bw_status=$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unauthenticated")
            local session_token="${BW_SESSION:-}"

            if [[ "$bw_status" == "unauthenticated" ]]; then
                session_token=$(bw login --raw)
            elif [[ "$bw_status" == "locked" && -z "$session_token" ]]; then
                session_token=$(bw unlock --raw)
            fi
            export BW_SESSION="$session_token"
            secret_key=$(bw get notes "$BW_ITEM_NAME" --session "$BW_SESSION" 2>/dev/null || true)
        fi

        if [[ -z "$secret_key" ]]; then
            read -r -s -p "Enter age Private Key (AGE-SECRET-KEY-1...): " secret_key
            echo
        fi
    fi

    secret_key=$(echo "$secret_key" | xargs)

    if [[ -z "$secret_key" || ! "$secret_key" =~ ^AGE-SECRET-KEY- ]]; then
        log_err "Invalid age private key format. Must start with 'AGE-SECRET-KEY-'."
        exit 1
    fi

    # Decrypt and unpack in-memory via pipe without writing plaintext key to disk
    local tmp_tar
    tmp_tar=$(mktemp -t secrets_restore.XXXXXX.tar.gz)
    local tmp_extract
    tmp_extract=$(mktemp -d -t secrets_extract.XXXXXX)
    TMP_CLEANUP_PATHS+=("$tmp_extract" "$tmp_tar")

    log_info "Decrypting archive..."
    if ! printf '%s\n' "$secret_key" | age -d -i - -o "$tmp_tar" "$archive_file" 2>/dev/null; then
        log_err "Decryption failed. Please check that the private key matches the public key used during backup."
        exit 1
    fi

    tar -xzf "$tmp_tar" -C "$tmp_extract"

    # Restore home targets safely preserving directory hierarchies
    if [[ -d "${tmp_extract}/home" ]]; then
        shopt -s dotglob
        for item in "${tmp_extract}/home"/*; do
            [[ -e "$item" || -L "$item" ]] || continue
            local base_name
            base_name=$(basename "$item")
            local target_dest="${HOME_DIR}/${base_name}"

            if [[ -e "$target_dest" || -L "$target_dest" ]]; then
                local backup_suffix=".bak.$(date +%s)"
                log_warn "Existing '${target_dest}' found. Renaming to '${base_name}${backup_suffix}'"
                mv "$target_dest" "${target_dest}${backup_suffix}"
            fi

            mkdir -p "$(dirname "$target_dest")"
            cp -a "$item" "$target_dest"
            log_success "Restored: ${target_dest}"
        done
        shopt -u dotglob
    fi

    # Restore repo targets safely
    if [[ -d "${tmp_extract}/repo" ]]; then
        shopt -s globstar dotglob
        pushd "${tmp_extract}/repo" >/dev/null
        find . -type f | while read -r rel_file; do
            rel_file="${rel_file#./}"
            local target_dest="${REPO_ROOT}/${rel_file}"

            if [[ -e "$target_dest" || -L "$target_dest" ]]; then
                local backup_suffix=".bak.$(date +%s)"
                log_warn "Existing repo file '${target_dest}' found. Renaming to '${rel_file}${backup_suffix}'"
                mv "$target_dest" "${target_dest}${backup_suffix}"
            fi

            mkdir -p "$(dirname "$target_dest")"
            cp -a "$rel_file" "$target_dest"
            log_success "Restored repo file: ${target_dest}"
        done
        popd >/dev/null
        shopt -u globstar dotglob
    fi

    # Granular permissions for sensitive credentials
    if [[ -d "${HOME_DIR}/.ssh" ]]; then
        chmod 700 "${HOME_DIR}/.ssh"
        find "${HOME_DIR}/.ssh" -type d -exec chmod 700 {} +
        find "${HOME_DIR}/.ssh" -type f -exec chmod 600 {} +
        chmod 644 "${HOME_DIR}/.ssh"/*.pub 2>/dev/null || true
    fi

    if [[ -d "${HOME_DIR}/.gnupg" ]]; then
        chmod 700 "${HOME_DIR}/.gnupg"
        find "${HOME_DIR}/.gnupg" -type d -exec chmod 700 {} +
        find "${HOME_DIR}/.gnupg" -type f -exec chmod 600 {} +
    fi

    if [[ -d "${HOME_DIR}/.kube" ]]; then
        chmod 700 "${HOME_DIR}/.kube"
        [[ -f "${HOME_DIR}/.kube/config" ]] && chmod 600 "${HOME_DIR}/.kube/config" 2>/dev/null || true
    fi

    [[ -f "${REPO_ROOT}/ansible/vars/secrets.yml" ]] && chmod 600 "${REPO_ROOT}/ansible/vars/secrets.yml" 2>/dev/null || true

    # Restore SELinux contexts on Fedora / RHEL
    if command -v restorecon &>/dev/null; then
        restorecon -R "${HOME_DIR}/.ssh" "${HOME_DIR}/.gnupg" "${HOME_DIR}/.kube" 2>/dev/null || true
    fi

    # Post-restore verification of required targets
    local missing_critical=()
    for req in "${REQUIRED_TARGETS[@]}"; do
        local check_path
        if [[ "$req" =~ ^\. ]]; then
            check_path="${HOME_DIR}/${req}"
        elif [[ "$req" =~ ^/ ]]; then
            check_path="${req}"
        else
            check_path="${REPO_ROOT}/${req}"
        fi

        if [[ ! -e "$check_path" && ! -L "$check_path" ]]; then
            missing_critical+=("${req} (${check_path})")
        fi
    done

    if [[ ${#missing_critical[@]} -gt 0 ]]; then
        echo
        echo -e "${YELLOW}========================================================================${NC}"
        echo -e "${YELLOW}⚠️  WARNING: Critical Secret(s) Missing After Restore!${NC}"
        echo -e "${YELLOW}========================================================================${NC}"
        echo -e "The restored archive did not contain the following expected target(s):"
        for mc in "${missing_critical[@]}"; do
            echo -e "  - ${BOLD}${RED}${mc}${NC}"
        done
        echo
        echo -e "Consider restoring from an earlier snapshot using:"
        echo -e "  ${BLUE}$0 restore <archive_file>${NC}"
        echo -e "${YELLOW}========================================================================${NC}"
    else
        log_success "All required secret targets verified present on disk."
    fi

    log_success "All secrets successfully restored!"
}

# ── 4. STATUS (status) ────────────────────────────────────────────────────────

cmd_status() {
    echo -e "${BOLD}========================================================================${NC}"
    echo -e "${BOLD}📊 Secrets Backup Status & Configuration${NC}"
    echo -e "${BOLD}========================================================================${NC}"
    echo -e "${BOLD}Age Public Key:${NC}      ${AGE_PUBLIC_KEY:-${RED}Not Configured (run ./backup_restore.sh genkey)${NC}}"
    echo -e "${BOLD}Backup Destination:${NC}  ${BACKUP_DIR}"
    echo -e "${BOLD}Bitwarden Note Item:${NC} ${BW_ITEM_NAME}"
    echo -e "${BOLD}Retention Limit:${NC}     Keep ${MAX_KEEP} latest backups"
    echo
    echo -e "${BOLD}Targets Configured:${NC}"
    for t in "${TARGETS[@]}"; do
        echo "  - $t"
    done
    echo
    echo -e "${BOLD}Required Targets (Must exist for backup to proceed):${NC}"
    for r in "${REQUIRED_TARGETS[@]}"; do
        echo -e "  - ${GREEN}${r}${NC}"
    done
    echo

    if [[ -d "$BACKUP_DIR" ]]; then
        local latest_archive="${BACKUP_DIR}/secrets-latest.tar.gz.age"
        local latest_hash="${BACKUP_DIR}/secrets-latest.sha256"
        if [[ -f "$latest_archive" ]]; then
            echo -e "${BOLD}Latest Backup Archive:${NC} ${GREEN}$(basename "$latest_archive")${NC}"
            echo -e "  Size:      $(du -h "$latest_archive" | awk '{print $1}')"
            echo -e "  Modified:  $(stat -c '%y' "$latest_archive" 2>/dev/null || stat -f '%Sm' "$latest_archive")"
            [[ -f "$latest_hash" ]] && echo -e "  SHA-256:   $(cat "$latest_hash")"
        else
            echo -e "${YELLOW}No backups found in destination directory.${NC}"
        fi

        echo
        echo -e "${BOLD}Available Snapshots in Backup Dir:${NC}"
        find "$BACKUP_DIR" -maxdepth 1 -name "secrets-[0-9]*.tar.gz.age" -type f | sort -r | while read -r f; do
            echo "  - $(basename "$f") ($(du -h "$f" | awk '{print $1}'))"
        done
    else
        echo -e "${YELLOW}Backup directory is currently not accessible / mounted.${NC}"
    fi
}

# ── Entrypoint ────────────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
    show_usage
    exit 1
fi

ACTION="$1"
shift

case "$ACTION" in
    genkey)
        cmd_genkey "$@"
        ;;
    backup)
        cmd_backup "$@"
        ;;
    restore)
        cmd_restore "$@"
        ;;
    status)
        cmd_status "$@"
        ;;
    -h|--help|help)
        show_usage
        exit 0
        ;;
    *)
        log_err "Unknown action: '$ACTION'"
        show_usage
        exit 1
        ;;
esac


