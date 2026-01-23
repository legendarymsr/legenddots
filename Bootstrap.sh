#!/bin/bash

# ==========================================================================
# LEGENDDOTS: RED TEAM DEPLOYMENT PROTOCOL v22.0
# "Minimalism is a defensive posture."
# ==========================================================================

set -e  # Exit on error

echo "⚡ INITIATING SYSTEM OVERRIDE: LEGENDDOTS"

# --- 1. ENVIRONMENT RECON ---
if [[ $EUID -eq 0 ]]; then
   echo "❌ ERROR: Do not run as root. Stay in userland, Operator." 
   exit 1
fi

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        DISTRO=$ID
    elif [[ -d /data/data/com.termux ]]; then
        OS="Android (Termux)"
        DISTRO="termux"
    else
        OS="Unknown/Unix"
        DISTRO="linux"
    fi
}
detect_os
echo "🔍 TARGET IDENTIFIED: $OS ($DISTRO)"

# --- 2. IDEOLOGICAL FILTER ---
echo "❓ Did you crawl here from a Windows background?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) 
            echo "💡 Recovery is possible. Nuke your partitions and never look back."
            echo "💡 Microsoft is currently recording your screen via Recall. Neovim is the cure."
            break ;;
        No ) 
            echo "🔥 Home row respect. Let's get to work."
            break ;;
    esac
done

# --- 3. THE BLOAT CHECK (VSCodium) ---
echo "❓ Install VSCodium as a 'Training Wheels' fallback?"
select codium_choice in "Yes" "No"; do
    case $codium_choice in
        Yes ) INSTALL_CODIUM=true; break ;;
        No ) INSTALL_CODIUM=false; break ;;
    esac
done

# --- 4. HARDWARE PROVISIONING ---
case $DISTRO in
    "arch"|"manjaro"|"endeavouros")
        echo "🏹 ARCH DETECTED. SYNCING PACMAN..."
        sudo pacman -Syu --noconfirm --needed \
            neovim zsh alacritty git curl wget ripgrep fd fzf nodejs npm \
            rust python python-pip w3m mpv gcc make \
            python-httpx python-beautifulsoup4 python-pyqt6 python-pyqt6-webengine

        # AUR Helper Setup
        if ! command -v yay &> /dev/null; then
            echo "📦 Compiling yay..."
            sudo pacman -S --needed base-devel
            git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
            cd /tmp/yay-bin && makepkg -si --noconfirm && cd -
        fi
        
        yay -S --noconfirm --needed lazygit ttf-jetbrains-mono-nerd
        [[ "$INSTALL_CODIUM" = true ]] && yay -S --noconfirm vscodium-bin
        ;;

    "gentoo")
        echo "🧬 GENTOO DETECTED. PREPARING COMPILATION..."
        sudo emerge --sync
        # Add required USE flags for Neovim/Python
        echo "app-editors/neovim lua" | sudo tee -a /etc/portage/package.use/neovim
        sudo emerge -uDU --with-bdeps=y \
            app-editors/neovim app-shells/zsh x11-terms/alacritty dev-vcs/git \
            sys-apps/ripgrep sys-apps/fd app-misc/fzf dev-lang/python dev-lang/nodejs \
            dev-util/cargo net-analyzer/nmap www-client/firefox media-video/mpv www-client/w3m
        ;;

    "termux")
        echo "📱 TERMUX DETECTED. HARDENING MOBILE C2..."
        pkg update && pkg upgrade -y
        pkg install -y neovim zsh git rust python nodejs-lts nmap w3m mpv termux-api espeak-ng
        ;;

    "nixos")
        echo "❄️ NIXOS DETECTED. USE FLAKE.NIX INSTEAD."
        echo "Command: nix run .#setup"
        exit 0
        ;;
esac

# --- 5. THE PYTHON RECOVERY (Fixing PEP 668) ---
echo "🐍 PROVISIONING PYTHON ARSENAL..."
PYTHON_LIBS="textual html2text httpx beautifulsoup4"
if [[ "$DISTRO" == "termux" ]]; then
    pip install $PYTHON_LIBS
else
    # We use --break-system-packages because we are Snobs who own our OS.
    # Alternatively, we tried Pacman first in the Arch block.
    pip install --user --break-system-packages $PYTHON_LIBS || echo "Skipping pip, assuming system pkgs."
fi

# --- 6. ARCHIVE LINKING ---
echo "🔗 ESTABLISHING PERSISTENCE (SYMLINKS)..."
mkdir -p ~/.config/{nvim,alacritty}

# Clean old links
rm -f ~/.zshrc
rm -rf ~/.config/nvim/*

# Atomic Symlinking
ln -sf "$(pwd)/init.lua" ~/.config/nvim/init.lua
ln -sf "$(pwd)/.zshrc" ~/.zshrc
ln -sf "$(pwd)/alacritty.toml" ~/.config/alacritty/alacritty.toml

# --- 7. COMPILE THE LUNDUKE-BUSTER (RUST) ---
if [[ -d "./fetch" ]]; then
    echo "🦀 COMPILING RUST SPITE-BINARY..."
    cd fetch
    rustc main.rs -o fetch-rs
    mkdir -p ../legend-browsers
    mv fetch-rs ../legend-browsers/
    cd ..
fi

# --- 8. FINAL INITIALIZATION ---
chmod +x ./legend-browsers/*

if [[ "$SHELL" != *"zsh"* ]]; then
    echo "🐚 SHIFTING TO ZSH..."
    chsh -s $(which zsh)
fi

echo "🎉 DEPLOYMENT COMPLETE."
echo "💡 Run 'exec zsh' to activate the Identity Profile."
echo "💡 Run 'nvim' and press 'o' to verify System Intelligence."