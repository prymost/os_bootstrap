#!/usr/bin/env bash
# Check status of systemd timers and services for system updates and backups.
# Comments explain why decisions were made.

set -euo pipefail

# ANSI color codes for clear terminal visual hierarchy
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Track if any check failed to return non-zero exit code at the end
ANY_FAILED=0

# Helper to inspect a systemd service and its associated timer
check_service() {
    local name="$1"
    local scope="$2" # "system" or "user"
    local timer_name="$3"
    
    local sysctl_cmd="systemctl"
    local journal_cmd="journalctl"
    if [ "$scope" = "user" ]; then
        sysctl_cmd="systemctl --user"
        journal_cmd="journalctl --user"
    fi

    echo -e "${BOLD}========================================================================${NC}"
    echo -e "${BOLD}🔍 Task: ${BLUE}${name}${NC} (${scope}-level)"
    echo -e "${BOLD}========================================================================${NC}"

    # Query service status properties from systemd dbus
    local service_status
    service_status=$($sysctl_cmd show -p ActiveState -p SubState -p Result -p ExecMainStatus -p StateChangeTimestamp "${name}.service")
    
    local active_state=$(echo "$service_status" | grep "ActiveState=" | cut -d= -f2)
    local sub_state=$(echo "$service_status" | grep "SubState=" | cut -d= -f2)
    local result=$(echo "$service_status" | grep "Result=" | cut -d= -f2)
    local exit_code=$(echo "$service_status" | grep "ExecMainStatus=" | cut -d= -f2)
    local last_change=$(echo "$service_status" | grep "StateChangeTimestamp=" | cut -d= -f2)

    # Query timer status properties from systemd dbus
    local timer_status
    timer_status=$($sysctl_cmd show -p ActiveState -p LastTriggerUSec -p NextElapseUSecRealtime "${timer_name}")
    
    local timer_active=$(echo "$timer_status" | grep "ActiveState=" | cut -d= -f2)
    local last_run=$(echo "$timer_status" | grep "LastTriggerUSec=" | cut -d= -f2)
    local next_run=$(echo "$timer_status" | grep "NextElapseUSecRealtime=" | cut -d= -f2)

    # Print timer status
    echo -e "${BOLD}Timer:${NC} ${timer_name}"
    if [ "$timer_active" = "active" ]; then
        echo -e "  Status: ${GREEN}Active${NC}"
    else
        echo -e "  Status: ${RED}Inactive (${timer_active})${NC}"
        ANY_FAILED=1
    fi
    echo -e "  Last Run: ${last_run:-N/A}"
    echo -e "  Next Run: ${next_run:-N/A}"
    echo

    # Print service execution status
    echo -e "${BOLD}Service:${NC} ${name}.service"
    if [ "$active_state" = "failed" ] || { [ "$result" != "success" ] && [ "$result" != "none" ]; }; then
        echo -e "  Status:    ${RED}FAILED (${active_state}/${sub_state})${NC}"
        echo -e "  Result:    ${RED}${result}${NC}"
        echo -e "  Exit Code: ${RED}${exit_code}${NC}"
        echo -e "  Finished:  ${last_change}"
        echo
        echo -e "${RED}${BOLD}⚠️ Errors / Logs (Last 15 lines):${NC}"
        $journal_cmd -u "${name}.service" -n 15 --no-pager | sed 's/^/  /'
        ANY_FAILED=1
    else
        echo -e "  Status:    ${GREEN}Success (inactive/dead)${NC}"
        echo -e "  Result:    ${GREEN}${result:-success}${NC}"
        echo -e "  Exit Code: ${GREEN}${exit_code:-0}${NC}"
        echo -e "  Finished:  ${last_change}"
    fi
    echo
}

# 1. System Updates (System-level)
check_service "system-update" "system" "system-update.timer"

# 2. User Updates (User-level)
check_service "update" "user" "update.timer"

# 3. Borg Backups (User-level)
check_service "borg-backup" "user" "borg-backup.timer"

# Print high-level overview summary
echo -e "${BOLD}========================================================================${NC}"
if [ $ANY_FAILED -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✅ All automated tasks ran successfully!${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}❌ Some tasks failed or are not active. See details above.${NC}"
    exit 1
fi
