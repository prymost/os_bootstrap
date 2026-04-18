#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

echo "🎨 Configuring COSMIC desktop UI..."

# COSMIC stores all user preferences as RON files under ~/.config/cosmic/

# ── Shortcuts (Mac-style alignment) ─────────────────────────────────────────
# Launcher      → Ctrl+Space  (mirrors Cmd+Space)
# Switch windows→ Ctrl+Tab    (mirrors Cmd+Tab)
# Close window  → Ctrl+Q      (mirrors Cmd+Q)
# App switcher  → Super+Tab   (kept on Super to avoid terminal conflicts)
echo "⌨️  Writing keyboard shortcuts..."
SHORTCUTS_DIR="$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1"
mkdir -p "$SHORTCUTS_DIR"
# Format: { Binding: Action } — Binding is the map key, Action is the value.
# Modifier variants: Ctrl, Alt, Shift, Super
# Key names: xkb keysym names without the XKB_KEY_ prefix (e.g. "Tab", "space", "q")
# Action variants: Close, System(Launcher), System(WindowSwitcher), System(WindowSwitcherPrevious), …
cat > "$SHORTCUTS_DIR/custom" << 'EOF'
{
    (modifiers: [Ctrl], key: "space"): System(Launcher),
    (modifiers: [Ctrl], key: "q"): Close,
    (modifiers: [Super, Shift], key: "Tab"): Disable,
    (modifiers: [Alt], key: "F4"): Disable,
    (modifiers: [Super], key: "Tab"): Disable,
    (modifiers: [Super, Ctrl], key: "q"): System(LockScreen),
}
EOF

# ── Key repeat ───────────────────────────────────────────────────────────────
echo "⌨️  Setting key repeat rate..."
INPUT_CONF="$HOME/.config/cosmic/com.system76.CosmicSettings.Input/v1/keyboard"
mkdir -p "$(dirname "$INPUT_CONF")"
cat > "$INPUT_CONF" << 'EOF'
(
    repeat_delay: 300,
    repeat_rate: 30,
    active_sources: [],
)
EOF

# ── Screen idle / timeout ────────────────────────────────────────────────────
echo "🔋 Setting screen idle timeout (5 min dim, 20 min off)..."
IDLE_CONF="$HOME/.config/cosmic/com.system76.CosmicSettings.Idle/v1/all"
mkdir -p "$(dirname "$IDLE_CONF")"
cat > "$IDLE_CONF" << 'EOF'
(
    dim_time: (5, 0),
    off_time: (20, 0),
)
EOF

# ── Dark mode ────────────────────────────────────────────────────────────────
echo "🌙 Enabling Dark Mode..."
THEME_CONF="$HOME/.config/cosmic/com.system76.CosmicTheme.Mode/v1/is_dark"
mkdir -p "$(dirname "$THEME_CONF")"
echo "true" > "$THEME_CONF"

# ── Apply ────────────────────────────────────────────────────────────────────
echo "🔄 Restarting COSMIC settings daemon..."
killall cosmic-settings-daemon 2>/dev/null || true

echo "✅ COSMIC UI tweaks applied!"
