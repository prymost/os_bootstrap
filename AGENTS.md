# Project Overview

This project contains a set of bootstrap scripts for automating the setup of personal machines across multiple platforms: Windows 11, macOS, WSL Ubuntu, and PopOS/Debian. The scripts are designed to be platform-specific, simple, and maintainable without shared dependencies.

## Key Technologies

*   **Windows:** PowerShell, Winget
*   **macOS:** Bash, Homebrew
*   **Linux (Debian/WSL):** Bash, apt

## Building and Running

The scripts are intended to be run directly. Here are the commands for each platform:

*   **Windows 11 (as Administrator):**
    ```powershell
    PowerShell -ExecutionPolicy Bypass -File windows/bootstrap-windows11.ps1
    ```

*   **macOS:**
    ```bash
    ./mac/bootstrap.sh
    ```

*   **WSL Ubuntu:**
    ```bash
    ./windows/wsl_scripts/bootstrap.sh
    ```

*   **PopOS/Debian Linux:**
    ```bash
    ./linux/debian/bootstrap.sh
    ```

## Development Conventions

*   **Platform-Specific Scripts:** Each platform has its own set of scripts, tailored to the specific package managers and tools of that OS.
*   **Modularity:** The bootstrap scripts are broken down into smaller, modular scripts for different stages of the setup process (e.g., initial setup, package installation, OS configuration).
*   **Shared Configuration:** There is a `shared` directory that contains configuration files that are common across all platforms, such as `.zshrc`.
*   **Idempotency:** The scripts are designed to be idempotent, meaning they can be run multiple times without causing issues. They check for existing installations and configurations before making changes.
