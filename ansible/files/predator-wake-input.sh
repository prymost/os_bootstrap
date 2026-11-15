#!/usr/bin/env bash
set -u

PREDATOR_MODEL="${PREDATOR_MODEL:-XB273K GP}"
PREDATOR_INPUT_VCP="${PREDATOR_INPUT_VCP:-0x0f}"

switch_to_input() {
    # Give the GPU / I2C bus a moment to finish resuming, then retry if PowerDevil holds the flock.
    sleep 1
    local err_output=""
    for attempt in 1 2 3 4; do
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

# Listen for logind PrepareForSleep(false) events (system wake from suspend)
while IFS= read -r line; do
    case "$line" in
        *"PrepareForSleep (false,)"*)
            now="$(date +%s)"
            if [ $((now - last_wake)) -ge 5 ]; then
                last_wake="$now"
                switch_to_input &
            fi
            ;;
    esac
done < <(gdbus monitor --system --dest org.freedesktop.login1 --object-path /org/freedesktop/login1)

# If gdbus monitor exits unexpectedly (EOF), exit non-zero so systemd restarts the service
exit 1
