#!/bin/bash
# VibeMobile Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/fafa-npu/VibeMobile/main/install.sh | bash

set -e

echo "================================"
echo "  VibeMobile Installer"
echo "================================"
echo ""

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: VibeMobile only supports macOS"
    exit 1
fi

# Check and install dependency
check_and_install() {
    local cmd=$1
    local brew_pkg=$2

    if command -v "$cmd" &> /dev/null; then
        local version
        case "$cmd" in
            tmux)
                version=$(tmux -V 2>&1)
                ;;
            cloudflared)
                version=$(cloudflared --version 2>&1 | head -1)
                ;;
            *)
                version=$($cmd --version 2>&1 | head -1)
                ;;
        esac
        echo "✓ $cmd ($version)"
        return 0
    else
        echo "Installing $cmd..."
        brew install "$brew_pkg"
    fi
}

# Check Homebrew
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "✓ Homebrew installed"
fi

# Install dependencies (only if missing)
echo ""
echo "Checking dependencies..."
check_and_install node node
check_and_install tmux tmux
check_and_install cloudflared cloudflare/cloudflare/cloudflared
echo ""

# Download latest release
echo "Downloading VibeMobile..."
RELEASE_URL=$(curl -s https://api.github.com/repos/fafa-npu/VibeMobile/releases/latest | grep "browser_download_url.*dmg" | cut -d '"' -f 4)

if [[ -z "$RELEASE_URL" ]]; then
    echo "Error: Could not find release. Please download manually from:"
    echo "https://github.com/fafa-npu/VibeMobile/releases"
    exit 1
fi

DMG_PATH="/tmp/VibeMobile.dmg"
curl -L -o "$DMG_PATH" "$RELEASE_URL"

# Mount and install
echo "Installing VibeMobile..."
hdiutil attach "$DMG_PATH" -mountpoint /tmp/vibemobile_dmg -quiet

# Remove old version if exists
rm -rf /Applications/VibeMobile.app 2>/dev/null || true

# Copy to Applications
cp -R /tmp/vibemobile_dmg/VibeMobile.app /Applications/

# Unmount
hdiutil detach /tmp/vibemobile_dmg -quiet

# Remove quarantine
xattr -cr /Applications/VibeMobile.app

# Cleanup
rm -f "$DMG_PATH"

# Setup vibemobile command
setup_vibemobile_command() {
    local shell_rc=""
    local current_shell=$(basename "$SHELL")

    case "$current_shell" in
        zsh)
            shell_rc="$HOME/.zshrc"
            ;;
        bash)
            shell_rc="$HOME/.bashrc"
            ;;
        *)
            echo "Note: Unknown shell ($current_shell). Add this to your shell config:"
            echo '  alias vibemobile="open /Applications/VibeMobile.app"'
            return
            ;;
    esac

    # Check if alias already exists
    if grep -q 'alias vibemobile=' "$shell_rc" 2>/dev/null; then
        echo "✓ vibemobile command already configured"
    else
        echo "" >> "$shell_rc"
        echo '# VibeMobile' >> "$shell_rc"
        echo 'alias vibemobile="open /Applications/VibeMobile.app"' >> "$shell_rc"
        echo "✓ Added vibemobile command to $shell_rc"
    fi
}

setup_vibemobile_command

echo ""
echo "================================"
echo "  Installation Complete!"
echo "================================"
echo ""
echo "To start VibeMobile:"
echo "  1. Run: source ~/.zshrc  (or restart Terminal)"
echo "  2. Then: vibemobile"
echo ""

# Ask to launch
read -p "Launch VibeMobile now? [Y/n] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    open /Applications/VibeMobile.app
    echo "VibeMobile is starting..."
fi
