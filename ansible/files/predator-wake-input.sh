#!/usr/bin/env bash
set -u

PREDATOR_MODEL="${PREDATOR_MODEL:-XB273K GP}"
PREDATOR_INPUT_VCP="${PREDATOR_INPUT_VCP:-0x0f}"

if ! [[ "$PREDATOR_INPUT_VCP" =~ ^0[xX][0-9a-fA-F]+$|^[0-9]+$ ]]; then
    echo "Invalid PREDATOR_INPUT_VCP: '$PREDATOR_INPUT_VCP'" >&2
    exit 1
fi

switch_to_input() {
    # Give GPU / DisplayPort link-training a moment to wake the monitor naturally, then retry if PowerDevil holds the flock.
    sleep 2
    local err_output=""
    local current_raw=""
    local power_token=""
    local power_dec=""
    local attempt
    for attempt in 1 2 3 4; do
        if current_raw="$(ddcutil --model "$PREDATOR_MODEL" getvcp d6 --brief 2>/dev/null)"; then
            power_token="$(printf '%s\n' "$current_raw" | sed -nE 's/^VCP[[:space:]]+[dD]6[[:space:]]+[A-Z]+[[:space:]]+(0?[xX][0-9a-fA-F]+|[0-9]+)[[:space:]]*$/\1/p' | head -n 1)"
            if [[ "$power_token" =~ ^[xX][0-9a-fA-F]+$ ]]; then
                printf -v power_dec '%d' "0$power_token"
            elif [[ "$power_token" =~ ^0[xX][0-9a-fA-F]+$ ]]; then
                printf -v power_dec '%d' "$power_token"
            elif [[ "$power_token" =~ ^[0-9]+$ ]]; then
                power_dec=$((10#$power_token))
            else
                power_dec=""
            fi
            if [ -n "$power_dec" ] && [ "$power_dec" -eq 1 ]; then
                echo "$PREDATOR_MODEL already active (VCP 0xD6=0x01, attempt $attempt), skipping switch"
                return 0
            fi
        fi
        # On attempt 1, give normal DisplayPort wake until attempt 2 (~3s) before forcing setvcp 60.
        if [ "$attempt" -eq 1 ]; then
            sleep 1
            continue
        fi
        if err_output="$(ddcutil --model "$PREDATOR_MODEL" setvcp 60 "$PREDATOR_INPUT_VCP" 2>&1 >/dev/null)"; then
            echo "Switched $PREDATOR_MODEL to VCP 0x60=$PREDATOR_INPUT_VCP (attempt $attempt)"
            return 0
        fi
        sleep 1
    done
    echo "Failed to switch $PREDATOR_MODEL to VCP 0x60=$PREDATOR_INPUT_VCP after 4 attempts: $err_output" >&2
    return 1
}

last_wake=0
switch_pid=0

# Listen for logind PrepareForSleep(false) events (system wake from suspend)
while IFS= read -r line; do
    case "$line" in
        *"PrepareForSleep (false,)"*)
            now="$(date +%s)"
            if [ $((now - last_wake)) -ge 5 ] && { [ "$switch_pid" -eq 0 ] || ! kill -0 "$switch_pid" 2>/dev/null; }; then
                last_wake="$now"
                switch_to_input &
                switch_pid=$!
            fi
            ;;
    esac
done < <(gdbus monitor --system --dest org.freedesktop.login1 --object-path /org/freedesktop/login1)

# If gdbus monitor exits unexpectedly (EOF), exit non-zero so systemd restarts the service
exit 1
