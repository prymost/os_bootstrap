#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

echo "🔄 Updating user packages..."

# Update Homebrew packages
if command -v brew &> /dev/null; then
    echo "🍺 Updating Homebrew packages..."
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    brew update && brew upgrade
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

echo "✅ All user updates completed!"
