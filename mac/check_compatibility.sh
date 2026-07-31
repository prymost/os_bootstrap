#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

echo "🔍 macOS Setup Compatibility Check"
echo "=================================="

# Get macOS version
MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo $MACOS_VERSION | cut -d '.' -f 1)
MACOS_MINOR=$(echo $MACOS_VERSION | cut -d '.' -f 2)

echo "📱 Current macOS: $MACOS_VERSION"

# Check if running macOS 13+ (Ventura or newer)
if [[ $MACOS_MAJOR -ge 13 ]]; then
    echo "✅ macOS version is modern and supported"
else
    echo "⚠️  macOS version is older - some features may not work"
fi

# Check if SIP is enabled
SIP_STATUS=$(csrutil status 2>/dev/null | grep -o "enabled\|disabled" || echo "unknown")
echo "🔒 System Integrity Protection: $SIP_STATUS"

# Check architecture
ARCH=$(uname -m)
echo "💻 Architecture: $ARCH"

if [[ $ARCH == "arm64" ]]; then
    echo "✅ Apple Silicon - scripts are compatible"
else
    echo "✅ Intel Mac - scripts are compatible"
fi

# Check if Xcode Command Line Tools are installed
if xcode-select -p &> /dev/null; then
    echo "✅ Xcode Command Line Tools: Installed"
else
    echo "⚠️  Xcode Command Line Tools: Not installed (will be installed by script)"
fi

# Check if Homebrew is installed
if command -v brew &> /dev/null; then
    BREW_VERSION=$(brew --version | head -n1)
    echo "✅ Homebrew: $BREW_VERSION"
else
    echo "⚠️  Homebrew: Not installed (will be installed by script)"
fi

# Check shell
CURRENT_SHELL=$(basename $SHELL)
echo "🐚 Current shell: $CURRENT_SHELL"

if [[ $CURRENT_SHELL == "zsh" ]]; then
    echo "✅ Using zsh (recommended)"
else
    echo "⚠️  Not using zsh - script will configure zsh"
fi

echo ""
echo "🎯 Recommendations:"
echo "=================="

if [[ $MACOS_MAJOR -ge 15 ]]; then
    echo "✅ Your macOS version supports all modern features"
elif [[ $MACOS_MAJOR -ge 13 ]]; then
    echo "✅ Your macOS version supports most features"
    echo "💡 Consider updating to macOS 15+ for latest features"
else
    echo "⚠️  Consider updating macOS for better compatibility"
fi

echo "💡 Before running bootstrap:"
echo "   - Ensure you have admin privileges"
echo "   - Close unnecessary applications"
echo "   - Have your Apple ID ready for App Store apps"
echo "   - Consider running on AC power for laptops"

echo ""
echo "🚀 Ready to run bootstrap.sh!"
