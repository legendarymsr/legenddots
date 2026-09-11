#!/bin/bash

# ==========================================================================
# LEGENDDOTS: MINIMALIST RECOVERY PROTOCOL v22.2
# "Zero Bloat. Zero Browsers. Pure Performance."
# ==========================================================================

set -e 

echo "⚡ INITIATING SYSTEM RECOVERY: LEGENDDOTS"

# --- 1. ENVIRONMENT RECON ---
if [[ $EUID -eq 0 ]]; then
   echo "❌ ERROR: Stay in userland, Root access is for payloads only." 
   exit 1
fi

# Distro check
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
fi

echo "🔍 TARGET DISTRO: $DISTRO"

# --- 2. PACMAN SWEEP (Core Arsenal) ---
echo "🏹 SYNCING SYSTEM AND INSTALLING CORE ARSENAL..."

# Removed all GUI browser bloat. Keeping only the essentials.
sudo pacman -Syu --noconfirm --needed \
    neovim zsh alacritty git curl wget ripgrep fd fzf nodejs npm \
    rust rust-src make gcc \
    qemu-desktop libvirt virt-manager dnsmasq iptables-nft \
    espeak-ng 

# --- 3. AUR HELPER SETUP ---
if ! command -v yay &> /dev/null; then
    echo "📦 Yay missing. Compiling the AUR bridge..."
    sudo pacman -S --needed base-devel
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    cd /tmp/yay-bin && makepkg -si --noconfirm && cd -
fi

# Tactical AUR payloads
yay -S --noconfirm --needed lazygit ttf-jetbrains-mono-nerd

# --- 4. VIRTUALIZATION PRIVESC ---
echo "🛡️ HARDENING HYPERVISOR ACCESS..."
sudo usermod -aG libvirt $(whoami)
sudo systemctl enable --now libvirtd
sudo virsh net-define /etc/libvirt/qemu/networks/default.xml 2>/dev/null || true
sudo virsh net-start default 2>/dev/null || true
sudo virsh net-autostart default 2>/dev/null || true

# --- 5. IDENTITY PERSISTENCE (SYMLINKS) ---
echo "🔗 SYNCING IDENTITY TO FILESYSTEM..."
mkdir -p ~/.config/{nvim,alacritty}

# Clean out fresh install debris
rm -f ~/.zshrc
rm -rf ~/.config/nvim/*

# Atomic Symlinking
ln -sf "$(pwd)/init.lua" ~/.config/nvim/init.lua
ln -sf "$(pwd)/.zshrc" ~/.zshrc
ln -sf "$(pwd)/alacritty.toml" ~/.config/alacritty/alacritty.toml

# --- 6. THE SPITE COMPILER (RUST) ---
# The manifesto, in Rust: installs as 'fetch'.
if [[ -f "./fetch.rs" ]]; then
    echo "🦀 COMPILING RUST LUNDUKE-BUSTER..."
    rustc fetch.rs -o fetch-rs
    sudo mv fetch-rs /usr/local/bin/fetch
fi

# --- 6b. THE SPITE COMPILER (C) ---
# Reject Electron. Return to C. The same manifesto in C installs as 'fetch-c',
# alongside 'legendstatus' (the status line). Both go to /usr/local/bin.
if [[ -d "./c" ]]; then
    echo "🔧 COMPILING C LUNDUKE-BUSTER..."
    make -C c
    sudo make -C c install
fi

# --- 7. FINAL HANDSHAKE ---
if [[ "$SHELL" != *"zsh"* ]]; then
    echo "🐚 SHIFTING TO ZSH..."
    sudo chsh -s /usr/bin/zsh $(whoami)
fi

echo "🎉 CORE RECOVERY COMPLETE."
echo "💡 Restart i3 ($mod+Shift+e) to finalize permissions."
echo "💡 Type 'fetch' to verify your 17-line manifesto."