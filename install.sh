#!/bin/bash
set -e

# ========================================================
# KRAM 1-Line Installer for macOS
# ========================================================

BOLD="\033[1m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RESET="\033[0m"

echo -e "\n${BOLD}🐭 Installing KRAM — Keep. Rearrange. Automate. Manage.${RESET}\n"

# 1. Verify macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${YELLOW}Error: KRAM is built specifically for macOS.${RESET}"
    exit 1
fi

# 2. Check for Swift / Xcode Command Line Tools
if ! command -v swift &> /dev/null; then
    echo -e "${YELLOW}Swift is required to build KRAM.${RESET}"
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Please complete the installation popup and rerun this script."
    exit 1
fi

INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo -e "${CYAN}➤ Fetching latest KRAM source...${RESET}"
git clone --depth 1 https://github.com/adisng/Kram.git "$TEMP_DIR/Kram"

echo -e "${CYAN}➤ Building optimized release binary...${RESET}"
cd "$TEMP_DIR/Kram"
swift build -c release --disable-sandbox 2>/dev/null || swift build -c release

# Copy binary & create alias
cp -f .build/release/kram "$INSTALL_DIR/kram"
ln -sf "$INSTALL_DIR/kram" "$INSTALL_DIR/kr"
chmod +x "$INSTALL_DIR/kram"

echo -e "\n${GREEN}${BOLD}✓ KRAM installed successfully to $INSTALL_DIR!${RESET}\n"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    SHELL_PROFILE="$HOME/.zshrc"
    if [[ "$SHELL" == *"bash"* ]]; then
        SHELL_PROFILE="$HOME/.bash_profile"
    fi
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$SHELL_PROFILE"
    echo -e "${CYAN}Added $INSTALL_DIR to $SHELL_PROFILE${RESET}"
    echo -e "${YELLOW}Please restart your terminal or run:${RESET} source $SHELL_PROFILE"
fi

echo -e "You can now run:"
echo -e "  ${BOLD}${CYAN}kr${RESET}          Interactive folder picker"
echo -e "  ${BOLD}${CYAN}kr dl${RESET}       Preview Downloads"
echo -e "  ${BOLD}${CYAN}kr dl -a${RESET}    Organize Downloads"
echo -e "  ${BOLD}${CYAN}kr help${RESET}     Show all commands\n"
