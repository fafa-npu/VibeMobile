#!/bin/bash
# VibeMobile One-Click Installer
# Usage: curl -fsSL https://vibemobile.dev/install | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VIBEMOBILE_DIR="$HOME/.vibemobile"
APP_NAME="VibeMobile"
GITHUB_REPO="${GITHUB_REPO:-yourusername/VibeMobile}"  # Set via env or update here

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════╗"
echo "║       VibeMobile One-Click Install    ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}Error: VibeMobile currently only supports macOS${NC}"
    exit 1
fi

echo -e "${BLUE}[1/4]${NC} Checking system dependencies..."

# Function to install Homebrew
install_homebrew() {
    if command -v brew &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Homebrew is already installed"
        return 0
    fi

    echo -e "  ${YELLOW}→${NC} Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add to PATH for Apple Silicon
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    echo -e "  ${GREEN}✓${NC} Homebrew installed"
}

# Function to install a dependency
install_dep() {
    local name=$1
    local display=$2
    local brew_pkg=${3:-$name}

    if command -v "$name" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $display is already installed"
        return 0
    fi

    echo -e "  ${YELLOW}→${NC} Installing $display..."
    brew install "$brew_pkg" >/dev/null 2>&1
    echo -e "  ${GREEN}✓${NC} $display installed"
}

# Install dependencies (tmux/node for local server, tunnel CLIs for remote access)
install_homebrew
install_dep "tmux" "tmux"
install_dep "node" "Node.js"
install_dep "gh" "GitHub CLI"
install_dep "devtunnel" "Microsoft Dev Tunnel" "microsoft/dev-tunnels/devtunnel"

if gh copilot --help &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} GitHub Copilot CLI is already installed"
else
    echo -e "  ${YELLOW}→${NC} Installing GitHub Copilot CLI extension..."
    gh extension install github/gh-copilot >/dev/null 2>&1 || \
        echo -e "  ${YELLOW}!${NC} Could not install GitHub Copilot CLI. Run: gh extension install github/gh-copilot"
fi

echo -e "\n${BLUE}[2/4]${NC} Downloading VibeMobile..."

# Check if DMG download URL is available
DMG_URL=""
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    DMG_URL="https://github.com/$GITHUB_REPO/releases/latest/download/VibeMobile-arm64.dmg"
else
    DMG_URL="https://github.com/$GITHUB_REPO/releases/latest/download/VibeMobile-x64.dmg"
fi

# Try to download DMG
download_app() {
    local temp_dmg="/tmp/VibeMobile.dmg"

    echo -e "  ${YELLOW}→${NC} Downloading app for $ARCH..."
    if curl -fsSL -o "$temp_dmg" "$DMG_URL" 2>/dev/null; then
        echo -e "  ${YELLOW}→${NC} Mounting disk image..."
        hdiutil attach "$temp_dmg" -quiet -nobrowse -mountpoint /tmp/vibemobile-mount

        echo -e "  ${YELLOW}→${NC} Installing to /Applications..."
        rm -rf "/Applications/$APP_NAME.app" 2>/dev/null || true
        cp -R "/tmp/vibemobile-mount/$APP_NAME.app" /Applications/

        hdiutil detach /tmp/vibemobile-mount -quiet
        rm -f "$temp_dmg"

        echo -e "  ${GREEN}✓${NC} VibeMobile installed to /Applications"
        return 0
    else
        echo -e "  ${YELLOW}!${NC} Pre-built app not available, will build from source"
        return 1
    fi
}

# Try download, fall back to source build
if ! download_app 2>/dev/null; then
    echo -e "\n${BLUE}[2/4]${NC} Building from source..."

    # Clone or update repo
    REPO_DIR="$HOME/VibeMobile"
    if [[ -d "$REPO_DIR" ]]; then
        echo -e "  ${YELLOW}→${NC} Updating existing installation..."
        cd "$REPO_DIR"
        git pull --quiet
    else
        echo -e "  ${YELLOW}→${NC} Cloning repository..."
        git clone --quiet "https://github.com/$GITHUB_REPO.git" "$REPO_DIR"
        cd "$REPO_DIR"
    fi

    echo -e "\n${BLUE}[3/4]${NC} Building web server..."
    cd web
    npm install --silent
    npm run build --silent
    echo -e "  ${GREEN}✓${NC} Web server built"

    echo -e "\n${BLUE}[4/4]${NC} Build complete!"
    echo ""
    echo -e "${GREEN}Installation complete!${NC}"
    echo ""
    echo "To start VibeMobile:"
    echo -e "  ${BLUE}cd $REPO_DIR/web && npm start${NC}"
    echo ""
    echo "Or build the Desktop app:"
    echo -e "  ${BLUE}cd $REPO_DIR/desktop && flutter build macos${NC}"
    exit 0
fi

echo -e "\n${BLUE}[3/4]${NC} Creating configuration..."

# Create config directory
mkdir -p "$VIBEMOBILE_DIR"

# Create default config
CONFIG_FILE="$VIBEMOBILE_DIR/config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" << 'EOF'
{
  "setup_completed": true,
  "setup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "auto_configured": true
}
EOF
fi
echo -e "  ${GREEN}✓${NC} Configuration created"

echo -e "\n${BLUE}[4/4]${NC} Launching VibeMobile..."
open "/Applications/$APP_NAME.app"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Installation Complete!            ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo "VibeMobile is now running!"
echo ""
echo "Quick Start:"
echo "  1. Open the VibeMobile app"
echo "  2. Start the server"
echo "  3. Enable Microsoft Dev Tunnel for remote access"
echo "  4. Connect from your mobile device"
echo ""
echo -e "Documentation: ${BLUE}https://github.com/$GITHUB_REPO#readme${NC}"
