#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

echo "🔧 Setting up essential system components..."

# Update package lists and system
echo "📦 Updating package lists and system..."
sudo apt update -qq
sudo apt upgrade -y -qq

# Install essential build tools and dependencies
echo "🛠️  Installing essential build tools..."
sudo apt install -y -qq \
    build-essential \
    curl \
    wget \
    git \
    jq \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install Python3 pip if missing
echo "🐍 Ensuring Python3 pip is available..."
if ! command -v pip3 &> /dev/null; then
    sudo apt install -y -qq python3-pip
    echo "✅ Python3 pip installed"
else
    echo "✅ Python3 pip already available"
fi

echo "✅ Essential system setup completed!"
