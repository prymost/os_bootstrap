#!/usr/bin/env bash
set -u

PREDATOR_MODEL="${PREDATOR_MODEL:-XB273K GP}"
PREDATOR_INPUT_VCP="${PREDATOR_INPUT_VCP:-0x0f}"

if [[ "$PREDATOR_INPUT_VCP" =~ ^0[xX][0-9a-fA-F]+$ ]]; then
    printf -v TARGET_INPUT_DEC '%d' "$PREDATOR_INPUT_VCP"
elif [[ "$PREDATOR_INPUT_VCP" =~ ^[0-9]+$ ]]; then
    TARGET_INPUT_DEC=$((10#$PREDATOR_INPUT_VCP))
else
    echo "Invalid PREDATOR_INPUT_VCP: '$PREDATOR_INPUT_VCP'" >&2
    exit 1
fi

switch_to_input() {
    # Give the GPU / I2C bus a moment to finish resuming, then retry if PowerDevil holds the flock.
    sleep 1
    local err_output=""
    local current_raw=""
    local current_token=""
    local current_dec=""
    local attempt
    for attempt in 1 2 3 4; do
        if current_raw="$(ddcutil --model "$PREDATOR_MODEL" getvcp 60 --brief 2>/dev/null)"; then
            current_token="$(printf '%s\n' "$current_raw" | sed -nE 's/^VCP[[:space:]]+60[[:space:]]+[A-Z]+[[:space:]]+(0?[xX][0-9a-fA-F]+|[0-9]+)[[:space:]]*$/\1/p' | head -n 1)"
            if [[ "$current_token" =~ ^[xX][0-9a-fA-F]+$ ]]; then
                printf -v current_dec '%d' "0$current_token"
            elif [[ "$current_token" =~ ^0[xX][0-9a-fA-F]+$ ]]; then
                printf -v current_dec '%d' "$current_token"
            elif [[ "$current_token" =~ ^[0-9]+$ ]]; then
                current_dec=$((10#$current_token))
            else
                current_dec=""
            fi
            if [ -n "$current_dec" ] && [ "$current_dec" -eq "$TARGET_INPUT_DEC" ]; then
                echo "$PREDATOR_MODEL already on VCP 0x60=$PREDATOR_INPUT_VCP (attempt $attempt), skipping switch"
                return 0
            fi
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
