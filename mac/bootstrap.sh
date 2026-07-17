#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 Starting macOS bootstrap process..."
echo "📁 Script directory: $SCRIPT_DIR"

# Run compatibility check first
echo "🔍 Running compatibility check..."
"${SCRIPT_DIR}/check_compatibility.sh"

echo ""
read -p "Continue with bootstrap? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Bootstrap cancelled by user"
    exit 1
fi

# 1. Ensure Xcode Command Line Tools are installed
if ! xcode-select -p &>/dev/null; then
    echo "🛠️ Xcode Command Line Tools not found. Initiating installation..."
    xcode-select --install
    echo "⚠️ Please complete the Xcode installation dialog and then press any key to continue..."
    read -n 1 -s -r
else
    echo "✅ Xcode Command Line Tools already installed"
fi

# 2. Ensure Homebrew is installed
if ! command -v brew &>/dev/null; then
    echo "🍺 Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Configure path for the current shell session
    if [[ $(uname -m) == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo "✅ Homebrew already installed"
fi

# 3. Ensure Ansible is installed
if ! command -v ansible &>/dev/null; then
    echo "⚙️ Ansible not found. Installing via Homebrew..."
    brew install ansible
else
    echo "✅ Ansible already installed"
fi

# 4. Run Ansible Playbook
echo "🚀 Running Ansible playbook to provision workstation..."
ansible-playbook "${REPO_DIR}/ansible/local.yml"

echo "✅ Bootstrap process completed!"
echo "🔄 Please restart your computer to ensure all changes take effect."
