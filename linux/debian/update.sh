#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

HOMEBREW_PATH="/home/linuxbrew/.linuxbrew/bin/brew"

echo "🔄 Updating user packages..."

# Update Homebrew packages
if command -v "$HOMEBREW_PATH" &> /dev/null; then
    echo "🍺 Updating Homebrew packages..."
    eval "$($HOMEBREW_PATH shellenv)"
    "$HOMEBREW_PATH" update && "$HOMEBREW_PATH" upgrade
    echo "✅ Homebrew packages updated!"
else
    echo "ℹ️ Homebrew not found, skipping."
fi

# Update Flatpak packages
if command -v flatpak &> /dev/null; then
    echo "📦 Updating Flatpak packages..."
    flatpak update -y
    echo "✅ Flatpak packages updated!"
else
    echo "ℹ️ Flatpak not found, skipping."
fi

# Update Oh My Zsh
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    echo "🐚 Updating Oh My Zsh..."
    omz update
    echo "✅ Oh My Zsh updated!"
else
    echo "ℹ️ Oh My Zsh not found, skipping."
fi

# Update Kitty
if command -v kitty &> /dev/null; then
    echo "🐱 Updating Kitty Terminal..."
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
    echo "✅ Kitty Terminal updated!"
else
    echo "ℹ️ Kitty not found, skipping."
fi

# Update pibox docker container
if command -v docker &> /dev/null; then
    echo "🐳 Updating pibox docker container..."
    docker build --pull -t pibox:latest /home/boris/Workspace/os_bootstrap/linux/pibox
    echo "✅ pibox docker container updated!"
else
    echo "ℹ️ Docker not found, skipping pibox update."
fi

echo "✅ All user updates completed!"

