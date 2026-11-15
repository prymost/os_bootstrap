#!/usr/bin/env bash
set -u

PREDATOR_MODEL="${PREDATOR_MODEL:-XB273K GP}"
PREDATOR_INPUT_VCP="${PREDATOR_INPUT_VCP:-16}"

switch_to_input() {
    # Give macOS a moment to reinitialize external displays after wake
    sleep 2

    # Skip DarkWake / Power Nap events when the display wrangler is still asleep (CurrentPowerState < 4)
    local power_state
    power_state="$(ioreg -r -d 1 -c IODisplayWrangler 2>/dev/null | sed -nE 's/.*"CurrentPowerState"=([0-9]+).*/\1/p' | head -n 1)"
    if [ -n "$power_state" ] && [ "$power_state" -lt 4 ]; then
        echo "Skipping input switch during DarkWake (IODisplayWrangler CurrentPowerState=$power_state)"
        return 0
    fi

    if ! command -v m1ddc >/dev/null 2>&1; then
        echo "m1ddc not found in PATH=$PATH" >&2
        return 1
    fi

    local display_index=""
    local err_output=""
    for attempt in 1 2 3; do
        # Re-query display list inside retry loop in case display enumeration finishes after T+2s
        display_index="$(m1ddc display list 2>/dev/null | grep -F "$PREDATOR_MODEL" | sed -nE 's/^\[([0-9]+)\].*/\1/p' | head -n 1)"
        if [ -n "$display_index" ]; then
            if err_output="$(m1ddc display "$display_index" set input "$PREDATOR_INPUT_VCP" 2>&1 >/dev/null)"; then
                echo "Switched display $display_index ($PREDATOR_MODEL) to input $PREDATOR_INPUT_VCP (attempt $attempt)"
                return 0
            fi
        else
            if err_output="$(m1ddc set input "$PREDATOR_INPUT_VCP" 2>&1 >/dev/null)"; then
                echo "Switched default external display to input $PREDATOR_INPUT_VCP (attempt $attempt)"
                return 0
            fi
        fi
        sleep 1
    done

    echo "Failed to switch $PREDATOR_MODEL to input $PREDATOR_INPUT_VCP: $err_output" >&2
    return 1
}

last_wake=0

# Listen to macOS unified log for kernel wake events (no sleepwatcher needed)
while IFS= read -r line; do
    case "$line" in
        *"Wake reason"*|*"System Wake"*)
            now="$(date +%s)"
            if [ $((now - last_wake)) -ge 5 ]; then
                last_wake="$now"
                switch_to_input &
            fi
            ;;
    esac
done < <(/usr/bin/log stream --style compact --predicate 'process == "kernel" AND (eventMessage CONTAINS "Wake reason" OR eventMessage CONTAINS "System Wake")')

exit 1
