#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

echo "📦 Installing development tools and applications..."

# Define package lists by category (only apps from apps.json)
CLI_TOOLS=(
    "git"
    "jq"
    "bat"
    "direnv"
    "micro"
    "awscli"
    "xsel"
    "pipx"
)

DEVELOPMENT_TOOLS=(
    "docker.io"      # Docker
    "rbenv"
    "ruby-build"
    "pipenv"
    "zsh"
    "zsh-autosuggestions"
    "keychain"
)

OTHER=(
    "vlc"
    "discord"
    "steam-installer"
)

# Combine all packages that can be installed via apt
ALL_PACKAGES=(
    "${CLI_TOOLS[@]}"
    "${DEVELOPMENT_TOOLS[@]}"
    "${OTHER[@]}"
)

# Install standard packages
if [[ ${#ALL_PACKAGES[@]} -gt 0 ]]; then
    echo "📦 Installing ${#ALL_PACKAGES[@]} standard packages..."
    sudo apt update -qq
    sudo apt install -y -qq "${ALL_PACKAGES[@]}"
    echo "✅ Standard package installation completed!"
else
    echo "ℹ️  No standard packages to install"
fi

# Install special packages that need additional steps
echo "🔧 Installing packages that need special setup..."

# Install VS Code
echo "📦 Installing VS Code..."
if ! command -v code &> /dev/null; then
    # Add Microsoft GPG key and repository
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    sudo apt update -qq
    sudo apt install -y -qq code
    rm packages.microsoft.gpg
    echo "✅ VS Code installed"
else
    echo "✅ VS Code already installed"
fi

# Install Brave Browser
echo "📦 Installing Brave Browser..."
if ! command -v brave-browser &> /dev/null; then
    sudo apt install -y -qq apt-transport-https curl
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
    sudo apt update -qq
    sudo apt install -y -qq brave-browser
    echo "✅ Brave Browser installed"
else
    echo "✅ Brave Browser already installed"
fi

# Install kubectl
echo "📦 Installing kubectl..."
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    echo "✅ kubectl installed"
else
    echo "✅ kubectl already installed"
fi

# Synology Drive Client
echo "📦 Installing Synology Drive Client..."
if ! dpkg -l | grep -q synology-drive-client; then
    # Create temp directory for download
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    # Download the latest Synology Drive Client .deb file
    echo "🔄 Downloading Synology Drive Client..."
    SYNOLOGY_URL="https://global.synologydownload.com/download/Utility/SynologyDriveClient/3.5.2-16111/Ubuntu/Installer/synology-drive-client-16111.x86_64.deb"
    wget -q -O synology-drive-client.deb "$SYNOLOGY_URL"

    if [[ -f synology-drive-client.deb ]]; then
        echo "📦 Installing Synology Drive Client..."
        sudo dpkg -i synology-drive-client.deb
        # Fix any dependency issues
        sudo apt-get install -f -y -qq
        echo "✅ Synology Drive Client installed"
    else
        echo "❌ Failed to download Synology Drive Client"
        echo "⚠️  Please download manually from:"
        echo "    https://www.synology.com/en-us/support/download_center"
    fi

    # Clean up temp directory
    cd -
    rm -rf "$TEMP_DIR"
else
    echo "✅ Synology Drive Client already installed"
fi

# Install Logseq
echo "📦 Installing Logseq..."
if command -v flatpak &> /dev/null
then
    echo "Flatpak is installed. Proceeding with Logseq installation..."

    # Add the Flathub repository if it's not already added
    echo "Adding Flathub repository..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    # Install Logseq from Flathub non-interactively
    echo "Installing Logseq..."
    flatpak install --noninteractive flathub com.logseq.Logseq

    echo "Logseq has been successfully installed."
else
    echo "Flatpak is not installed on your system."
    echo "To install Flatpak, run: sudo apt install flatpak"
    echo "After installation, run this script again."
    exit 1
fi

# Install Calibre
echo "📦 Installing Calibre..."
if ! command -v calibre &> /dev/null; then
    sudo apt-get install -y -qq libxcb-cursor0
    echo "🔄 Downloading and installing Calibre..."
    sudo -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin
    echo "✅ Calibre installed"
else
    echo "✅ Calibre already installed"
fi

# Configure Zsh with Oh My Zsh and shared .zshrc
if command -v zsh &> /dev/null; then
    echo "🐚 Setting up Oh My Zsh..."
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        echo "📦 Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

        # Install essential plugins
        git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

        # Copy shared .zshrc configuration
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
        SHARED_ZSHRC="${SCRIPT_DIR}/../../../shared/.zshrc"
        if [[ -f "$SHARED_ZSHRC" ]]; then
            echo "📝 Installing shared .zshrc configuration..."
            cp "$SHARED_ZSHRC" "$HOME/.zshrc"
            echo "✅ Shared .zshrc installed"
        else
            echo "⚠️  Shared .zshrc not found at $SHARED_ZSHRC, using default configuration"
            # Fallback to basic agnoster configuration
            sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' ~/.zshrc
            sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc
        fi
        # Setting ZSH as a primary shell
        chsh -s $(which zsh)
    else
        echo "✅ Oh My Zsh already installed"
        # Check if we should update to use shared .zshrc
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
        SHARED_ZSHRC="${SCRIPT_DIR}/../../../shared/.zshrc"
        if [[ -f "$SHARED_ZSHRC" ]]; then
            echo "📝 Updating to shared .zshrc configuration..."
            cp "$SHARED_ZSHRC" "$HOME/.zshrc"
            echo "✅ Shared .zshrc installed"
        fi
    fi
else
    echo "⚠️  Zsh not found, skipping Oh My Zsh setup"
fi

# Install Kinto (Mac-style shortcuts for Linux)
echo "📦 Installing Kinto..."
if ! command -v xkeysnail &> /dev/null; then
    echo "📦 Installing xkeysnail via pipx..."
    pipx install xkeysnail
    pipx ensurepath

    echo "📦 Installing Kinto..."
    /bin/bash -c "$(wget -qO- https://raw.githubusercontent.com/rbreaves/kinto/HEAD/install/linux.sh || curl -fsSL https://raw.githubusercontent.com/rbreaves/kinto/HEAD/install/linux.sh)"

    # Configure Kinto with custom shortcut
    KINTO_CONFIG="$HOME/.config/kinto/kinto.py"
    if [[ -f "$KINTO_CONFIG" ]]; then
        echo "🔧 Configuring Kinto shortcuts..."
        # Replace RC-Space mapping from Alt-F1 to Super-SLASH
        sed -i 's/K("RC-Space"): K("Alt-F1"),/K("RC-Space"): K("Super-SLASH"),/' "$KINTO_CONFIG"
        echo "✅ Kinto configuration updated"
    else
        echo "⚠️  Kinto config file not found at $KINTO_CONFIG"
        echo "⚠️  You may need to manually replace K(\"RC-Space\"): K(\"Alt-F1\"), with K(\"RC-Space\"): K(\"Super-SLASH\"), in the config"
    fi

    echo "✅ Kinto installed and configured"
else
    echo "✅ Kinto (xkeysnail) already installed"
fi

# Install Kitty Terminal
echo "📦 Installing Kitty Terminal..."
if ! command -v kitty &> /dev/null; then
    echo "🔄 Downloading and installing Kitty..."
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin

    # Create ~/.local/bin directory if it doesn't exist
    mkdir -p ~/.local/bin

    # Create symbolic links to add kitty and kitten to PATH
    echo "🔗 Creating symbolic links for kitty..."
    ln -sf ~/.local/kitty.app/bin/kitty ~/.local/bin/kitty
    ln -sf ~/.local/kitty.app/bin/kitten ~/.local/bin/kitten

    # Create ~/.local/share/applications directory if it doesn't exist
    mkdir -p ~/.local/share/applications

    # Place the kitty.desktop file somewhere it can be found by the OS
    echo "📝 Installing desktop files..."
    cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/

    # If you want to open text files and images in kitty via your file manager also add the kitty-open.desktop file
    cp ~/.local/kitty.app/share/applications/kitty-open.desktop ~/.local/share/applications/

    # Update the paths to the kitty and its icon in the kitty desktop file(s)
    echo "🔧 Updating desktop file paths..."
    sed -i "s|Icon=kitty|Icon=$(readlink -f ~)/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" ~/.local/share/applications/kitty*.desktop
    sed -i "s|Exec=kitty|Exec=$(readlink -f ~)/.local/kitty.app/bin/kitty|g" ~/.local/share/applications/kitty*.desktop

    # Make xdg-terminal-exec (and hence desktop environments that support it) use kitty
    echo "⚙️  Setting kitty as default terminal..."
    mkdir -p ~/.config
    echo 'kitty.desktop' > ~/.config/xdg-terminals.list

    echo "✅ Kitty Terminal installed and configured"
else
    echo "✅ Kitty Terminal already installed"
fi

echo "🧹 Cleaning up..."
sudo apt autoremove -y -qq
sudo apt autoclean -qq
