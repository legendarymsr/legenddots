#!/bin/bash

# ==========================================================================
# LEGENDDOTS: ENDEAVOUR-OS RECOVERY PROTOCOL v22.1
# "Target acquired. Re-establishing sovereignty."
# ==========================================================================

set -e 

echo "⚡ INITIATING SYSTEM RECOVERY: LEGENDDOTS"

# --- 1. ENVIRONMENT RECON ---
if [[ $EUID -eq 0 ]]; then
   echo "❌ ERROR: Do not run as root." 
   exit 1
fi

# EndeavourOS check
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
fi

if [[ "$DISTRO" != "endeavouros" && "$DISTRO" != "arch" ]]; then
    echo "⚠️ WARNING: Distro detected as $DISTRO. This script is tuned for Endeavour/Arch."
fi

# --- 2. THE BLOATWARE FILTER ---
echo "❓ Install VSCodium as a 'last resort' backup editor?"
select codium_choice in "Yes" "No"; do
    case $codium_choice in
        Yes ) INSTALL_CODIUM=true; break ;;
        No ) INSTALL_CODIUM=false; break ;;
    esac
done

# --- 3. PACMAN SWEEP (Core & Virtualization) ---
echo "🏹 SYNCING SYSTEM AND INSTALLING ARSENAL..."

# We install the Python libs via Pacman to bypass the PEP 668 'Externally Managed' error
sudo pacman -Syu --noconfirm --needed \
    neovim zsh alacritty git curl wget ripgrep fd fzf nodejs npm \
    rust python python-pip w3m mpv gcc make espeak-ng \
    qemu-desktop libvirt virt-manager dnsmasq iptables-nft \
    python-httpx python-beautifulsoup4 python-pyqt6 python-pyqt6-webengine

# --- 4. AUR HELPER (Endeavour usually has yay, but let's be sure) ---
if ! command -v yay &> /dev/null; then
    echo "📦 Yay missing. Compiling now..."
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    cd /tmp/yay-bin && makepkg -si --noconfirm && cd -
fi

# Install tactical AUR packages
echo "📦 FETCHING AUR PAYLOADS..."
yay -S --noconfirm --needed \
    lazygit \
    ttf-jetbrains-mono-nerd \
    fastfetch-git

[[ "$INSTALL_CODIUM" = true ]] && yay -S --noconfirm vscodium-bin

# --- 5. VIRTUALIZATION PRIVESC ---
echo "🛡️ CONFIGURING HYPERVISOR ACCESS..."
sudo usermod -aG libvirt $(whoami)
sudo systemctl enable --now libvirtd
# Start the virtual network bridge we fixed earlier
sudo virsh net-start default 2>/dev/null || true
sudo virsh net-autostart default 2>/dev/null || true

# --- 6. PYTHON EXTRACTION (The Fallback) ---
echo "🐍 ENSURING TUI BROWSER DEPENDENCIES..."
# If pacman missed any, we force them. We are the root user of this house.
pip install --user --break-system-packages textual html2text || echo "Textual already present via system."

# --- 7. IDENTITY PERSISTENCE (SYMLINKS) ---
echo "🔗 SYNCING IDENTITY TO FILESYSTEM..."
mkdir -p ~/.config/{nvim,alacritty,qutebrowser}

# Backup any fresh install defaults
[[ -f ~/.zshrc ]] && mv ~/.zshrc ~/.zshrc.vanilla
[[ -f ~/.config/nvim/init.lua ]] && mv ~/.config/nvim/init.lua ~/.config/nvim/init.lua.vanilla

# Deploy Legenddots
ln -sf "$(pwd)/init.lua" ~/.config/nvim/init.lua
ln -sf "$(pwd)/.zshrc" ~/.zshrc
ln -sf "$(pwd)/alacritty.toml" ~/.config/alacritty/alacritty.toml
ln -sf "$(pwd)/legend-browsers/qute-config.py" ~/.config/qutebrowser/config.py

# --- 8. THE SPITE COMPILER (RUST) ---
if [[ -d "./fetch" ]]; then
    echo "🦀 COMPILING 961-BYTE SPITE BINARY..."
    cd fetch
    rustc main.rs -o fetch-rs
    mkdir -p ../legend-browsers
    mv fetch-rs ../legend-browsers/
    cd ..
fi

# --- 9. FINAL HANDSHAKE ---
chmod +x ./legend-browsers/*

if [[ "$SHELL" != *"zsh"* ]]; then
    echo "🐚 SWITCHING DEFAULT SHELL TO ZSH..."
    sudo chsh -s /usr/bin/zsh $(whoami)
fi

echo "🎉 RECOVERY COMPLETE, LEGEND."
echo "💡 Restart i3 ($mod+Shift+e) to apply group changes."
echo "💡 Run 'nvim' to trigger Lazy.nvim plugin sync."