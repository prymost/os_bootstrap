#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

# Install packages and applications using Brewfile
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BREWFILE_PATH="${SCRIPT_DIR}/../Brewfile"

echo "📦 Installing packages and applications..."

# Install from Brewfile
if [[ -f "$BREWFILE_PATH" ]]; then
    echo "📦 Installing packages from Brewfile..."
    brew bundle install --file="${BREWFILE_PATH}"
else
    echo "❌ No Brewfile found."
fi

# Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Copy custom .zshrc configuration
SHARED_ZSHRC="${SCRIPT_DIR}/../../shared/.zshrc"
if [[ -f "$SHARED_ZSHRC" ]]; then
    echo "📝 Installing custom .zshrc configuration..."
    cp "$SHARED_ZSHRC" "$HOME/.zshrc"
    echo "✅ Custom .zshrc installed"
else
    echo "⚠️  Shared .zshrc not found at $SHARED_ZSHRC"
fi

echo "Cleaning up..."
brew cleanup

# TWEAK SOME APP SETTINGS

# Don’t display the annoying prompt when quitting iTerm
defaults write com.googlecode.iterm2 PromptOnQuit -bool false

# Use VSCode to edit git prompts
git config --global push.autoSetupRemote true
git config --global push.default current
git config --global core.editor "code -n -w"
git config --global remote.origin.prune true
