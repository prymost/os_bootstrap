#!/usr/bin/env bash
set -u

PREDATOR_MODEL="${PREDATOR_MODEL:-XB273K GP}"
PREDATOR_INPUT_VCP="${PREDATOR_INPUT_VCP:-16}"

if [[ "$PREDATOR_INPUT_VCP" =~ ^0[xX][0-9a-fA-F]+$ ]]; then
    printf -v TARGET_INPUT_DEC '%d' "$PREDATOR_INPUT_VCP"
elif [[ "$PREDATOR_INPUT_VCP" =~ ^[0-9]+$ ]]; then
    TARGET_INPUT_DEC=$((10#$PREDATOR_INPUT_VCP))
else
    echo "Invalid PREDATOR_INPUT_VCP: '$PREDATOR_INPUT_VCP'" >&2
    exit 1
fi

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
    local current_input=""
    local err_output=""
    local attempt
    for attempt in 1 2 3; do
        # Re-query display list inside retry loop in case display enumeration finishes after T+2s
        display_index="$(m1ddc display list 2>/dev/null | grep -F -- "$PREDATOR_MODEL" | sed -nE 's/^\[([0-9]+)\].*/\1/p' | head -n 1)"
        local -a m1ddc_args=()
        local target_desc="default external display"
        if [ -n "$display_index" ]; then
            m1ddc_args=(display "$display_index")
            target_desc="display $display_index ($PREDATOR_MODEL)"
        fi
        current_input="$(m1ddc ${m1ddc_args[@]+"${m1ddc_args[@]}"} get input 2>/dev/null | tr -d '[:space:]')"
        if [[ "$current_input" =~ ^[0-9]+$ ]] && [ "$((10#$current_input))" -eq "$TARGET_INPUT_DEC" ]; then
            echo "$target_desc already on input $PREDATOR_INPUT_VCP (attempt $attempt), skipping switch"
            return 0
        fi
        if err_output="$(m1ddc ${m1ddc_args[@]+"${m1ddc_args[@]}"} set input "$PREDATOR_INPUT_VCP" 2>&1 >/dev/null)"; then
            echo "Switched $target_desc to input $PREDATOR_INPUT_VCP (attempt $attempt)"
            return 0
        fi
        sleep 1
    done

    echo "Failed to switch $PREDATOR_MODEL to input $PREDATOR_INPUT_VCP: $err_output" >&2
    return 1
}

last_wake=0
switch_pid=0

# Listen to macOS unified log for kernel wake events (no sleepwatcher needed)
while IFS= read -r line; do
    case "$line" in
        "Filtering the log data using "*)
            ;;
        *"Wake reason"*|*"System Wake"*)
            now="$(date +%s)"
            if [ $((now - last_wake)) -ge 5 ] && { [ "$switch_pid" -eq 0 ] || ! kill -0 "$switch_pid" 2>/dev/null; }; then
                last_wake="$now"
                switch_to_input &
                switch_pid=$!
            fi
            ;;
    esac
done < <(/usr/bin/log stream --style compact --predicate 'process == "kernel" AND (eventMessage CONTAINS "Wake reason" OR eventMessage CONTAINS "System Wake")')

exit 1
