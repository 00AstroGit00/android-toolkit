#!/data/data/com.termux/files/usr/bin/bash
#
# INSTALL.sh — Android Toolkit single-command installer
#
# Usage:
#   bash INSTALL.sh
#
# This script installs dependencies and launches the TUI.
# It is the verbose version of the one-liner below.
#
# One-liner (copy-paste into Termux):
# pkg update -y && pkg install -y git dialog && git clone https://github.com/00AstroGit00/android-toolkit.git 2>/dev/null; cd android-toolkit 2>/dev/null && chmod +x toolkit.sh lib/*.sh modules/*.sh && ./toolkit.sh --tui

set -euo pipefail

echo "=== Android Toolkit Installer ==="
echo ""

# Update package list
echo "[1/4] Updating package list..."
pkg update -y

# Install dependencies
echo "[2/4] Installing dependencies (git, dialog)..."
pkg install -y git dialog

# Clone or detect existing
if [[ -d "$HOME/android-toolkit" ]]; then
    echo "[3/4] Existing installation found at ~/android-toolkit"
    cd "$HOME/android-toolkit"
elif [[ -d "$(dirname "$0")/toolkit.sh" ]]; then
    echo "[3/4] Running from existing checkout"
    cd "$(dirname "$0")"
else
    echo "[3/4] Cloning repository..."
    git clone https://github.com/00AstroGit00/android-toolkit.git "$HOME/android-toolkit"
    cd "$HOME/android-toolkit"
fi

# Make executable
echo "[4/4] Setting permissions..."
chmod +x toolkit.sh lib/*.sh modules/*.sh

# Launch TUI
echo ""
echo "=== Launching Android Toolkit TUI ==="
exec ./toolkit.sh --tui
