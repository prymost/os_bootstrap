#!/usr/bin/env bash
#
# mount_nas.sh - Keep the NAS SMB share mounted in the home directory.
#
# Deployed by Ansible (ansible/tasks/mac_mounts.yml) and driven by the
# com.user.nas.mount LaunchAgent, which fires this script on:
#   - login (RunAtLoad)
#   - network changes (WatchPaths: resolv.conf + network identification plist)
#   - every 5 minutes as a retry/insurance (StartInterval)
#
# Authentication: the password lives ONLY in the login keychain. It is read
# with `security find-internet-password` and passed to mount_smbfs as a
# percent-encoded URL (jq @uri, password piped via stdin). The password is
# never written to disk, logged, or exported; it does appear briefly in the
# argv of the mount_smbfs process while mounting (unavoidable without -N,
# whose silent keychain lookup fails for items mount_smbfs cannot read).
#
# On a fresh install (no keychain entry yet) a native dialog asks for the
# password once and stores it with an ACL trusting `security` (and
# mount_smbfs for convenience). No secrets are ever logged.

set -u

# --- Config (overridable via env for testing; normally injected by plist) ---
NAS_HOST="${NAS_HOST:-HomeCloud}"
NAS_USER="${NAS_USER:-Boris}"
NAS_SHARE="${NAS_SHARE:-SharedLand}"
MOUNT_POINT="${MOUNT_POINT:-$HOME/NAS}"
MAX_WAIT_TRIES="${MAX_WAIT_TRIES:-12}"   # x 5s sleep => up to 1 min for network
LOCK_DIR="/tmp/com.user.nas.mount.lock"

# Bonjour service name form; matches the keychain "srvr" attribute Finder uses.
NAS_SRV="${NAS_HOST}._smb._tcp.local"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

# --- Single-instance guard (multiple launchd triggers may overlap) ----------
acquire_lock() {
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        return 0
    fi
    # Steal a stale lock (older than 2 minutes).
    if [ -n "$(find "$LOCK_DIR" -maxdepth 0 -mmin +2 2>/dev/null)" ] && rmdir "$LOCK_DIR" 2>/dev/null; then
        mkdir "$LOCK_DIR" 2>/dev/null && return 0
    fi
    return 1
}
if ! acquire_lock; then
    log "another instance is running, exiting"
    exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

# --- Helpers -----------------------------------------------------------------

is_mounted() {
    mount | grep -F " on ${MOUNT_POINT} (" >/dev/null 2>&1
}

# Server reachable on SMB port 445? Does not touch the (possibly hung) mount.
nas_reachable() {
    nc -z -G 3 "${NAS_HOST}.local" 445 >/dev/null 2>&1
}

# Read the password from the login keychain. Captured in a local variable so
# it is never printed to stdout/stderr (which launchd captures into the log).
# Caller must keep stdout redirected.
keychain_get_password() {
    local pass
    pass=$(security find-internet-password -s "$NAS_SRV" -a "$NAS_USER" -w 2>/dev/null) || return 1
    [ -n "$pass" ] || return 1
    unset pass
    return 0
}

# Prompt once and store the password in the login keychain with an ACL that
# lets `security` (the script's reader) and mount_smbfs read it back without
# prompting. The password appears briefly in the argv of
# `security add-internet-password`; this happens once per fresh machine.
prompt_and_store_password() {
    local pass
    pass=$(osascript \
        -e "display dialog \"Password for NAS share ${NAS_USER}@${NAS_HOST}:\" with title \"NAS Auto-Mount\" default answer \"\" with hidden answer buttons {\"Cancel\", \"OK\"} default button \"OK\"" \
        -e "text returned of result" 2>/dev/null) || {
        log "password dialog cancelled or failed"
        return 1
    }
    [ -n "$pass" ] || { log "empty password entered"; return 1; }

    security add-internet-password \
        -s "$NAS_SRV" -a "$NAS_USER" -r smbx \
        -l "$NAS_HOST" \
        -T /sbin/mount_smbfs -T /usr/bin/security \
        -w "$pass" 2>/dev/null || {
        log "failed to store password in keychain"
        unset pass
        return 1
    }
    unset pass
    return 0
}

# --- 1. Wait for the NAS to appear on the network ----------------------------
tries=0
until nas_reachable; do
    tries=$((tries + 1))
    if [ "$tries" -ge "$MAX_WAIT_TRIES" ]; then
        log "NAS ${NAS_HOST} unreachable after ${MAX_WAIT_TRIES} tries"
        # If we hold a mount while unreachable it is stale: drop it so a later
        # trigger can remount cleanly instead of leaving a hanging handle.
        if is_mounted; then
            log "force unmounting stale mount at ${MOUNT_POINT}"
            /sbin/diskutil unmount force "$MOUNT_POINT" >/dev/null 2>&1
        fi
        exit 0
    fi
    sleep 5
done

# --- 2. Already mounted and server reachable => healthy ----------------------
if is_mounted; then
    log "mount healthy at ${MOUNT_POINT}"
    exit 0
fi

# --- 3. Ensure mount point and credentials -----------------------------------
mkdir -p "$MOUNT_POINT"

if ! keychain_get_password >/dev/null 2>&1; then
    log "no keychain entry for ${NAS_USER}@${NAS_HOST}, prompting once"
    prompt_and_store_password || exit 1
fi

# --- 4. Mount -----------------------------------------------------------------
# Read the password and percent-encode it for the mount URL. The encoded value
# is passed as an argument to mount_smbfs (brief argv exposure, see header).
pass=$(security find-internet-password -s "$NAS_SRV" -a "$NAS_USER" -w 2>/dev/null)
if [ -z "$pass" ]; then
    log "could not read password from keychain"
    exit 1
fi
enc=$(printf '%s' "$pass" | jq -sRr @uri 2>/dev/null)
unset pass
if [ -z "$enc" ]; then
    log "jq not available for password encoding"
    unset enc
    exit 1
fi

if /sbin/mount_smbfs "//${NAS_USER}:${enc}@${NAS_SRV}/${NAS_SHARE}" "$MOUNT_POINT"; then
    log "mounted //${NAS_USER}@${NAS_SRV}/${NAS_SHARE} at ${MOUNT_POINT}"
    unset enc
    exit 0
else
    log "mount failed for //${NAS_USER}@${NAS_SRV}/${NAS_SHARE}"
    unset enc
    exit 1
fi
