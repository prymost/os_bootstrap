# PopOS/Debian Setup Scripts

My personal scripts for setting up and maintaining a PopOS or Debian Linux desktop with development tools and applications.

## 🚀 Quick Start

1. **Run compatibility check** (recommended):
   ```bash
   ./check_compatibility.sh
   ```

2. **Run full bootstrap**:
   ```bash
   ./bootstrap.sh
   ```

## 📁 Script Overview

- **`bootstrap.sh`** - Main entry point that orchestrates the entire setup
- **`check_compatibility.sh`** - Validates system compatibility before setup
- **`setup/initial.sh`** - Installs essential build tools and system packages
- **`setup/my_installs.sh`** - Installs development tools, applications, and configures zsh with shared .zshrc template

## 🛠 Alternative Usage

### Running Individual Scripts
```bash
# Setup only core tools
./setup/initial.sh

# Install applications and tools only
./setup/my_installs.sh
```

## 🎯 Post-Installation

After running the bootstrap:

**Configure Git**:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

**Set up SSH key** for GitHub:
   ```bash
   ssh-keygen -t ed25519 -C "your.email@example.com"
   # add it to ssh agent
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
   ```
