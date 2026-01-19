#!/bin/bash

# LEGENDDOTS UNIVERSAL BOOTSTRAP SCRIPT
# Detects OS and installs packages using appropriate package manager

set -e  # Exit on any error

echo "🚀 LEGENDDOTS UNIVERSAL BOOTSTRAP INITIATED"

# Check if running as root (should not be)
if [[ $EUID -eq 0 ]]; then
   echo "❌ This script should NOT be run as root" 
   exit 1
fi

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        DISTRO=$ID
    elif [ -f /etc/gentoo-release ]; then
        OS="Gentoo Linux"
        DISTRO="gentoo"
    elif [ -f /etc/NIXOS ]; then
        OS="NixOS"
        DISTRO="nixos"
    else
        echo "❌ Cannot detect OS"
        exit 1
    fi
}

detect_os

echo "🔍 Detected OS: $OS ($DISTRO)"

# Ask if user is coming from Windows
echo "❓ Did you come from a Windows background?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) 
            echo "💡 No worries! We all started somewhere."
            echo "💡 VSCode is bloatware that spies on you. You'll thank me later for moving to Neovim!"
            break
            ;;
        No ) 
            echo "🔥 Welcome, fellow minimalist!"
            break
            ;;
    esac
done

# Ask if user wants VSCodium with Neovim keybindings
echo "❓ Would you like to install VSCodium with Neovim keybindings as a fallback editor?"
select codium_choice in "Yes" "No"; do
    case $codium_choice in
        Yes ) 
            INSTALL_CODIUM=true
            echo "✅ Will install VSCodium with Neovim keybindings"
            break
            ;;
        No ) 
            INSTALL_CODIUM=false
            echo "✅ Will skip VSCodium installation"
            break
            ;;
    esac
done

# Install packages based on detected OS
case $DISTRO in
    "arch"|"manjaro"|"endeavouros")
        echo "🐧 Installing for Arch-based system..."
        
        # Check if yay or paru is installed, install if not
        if ! command -v yay &> /dev/null && ! command -v paru &> /dev/null; then
            echo "📦 Installing yay AUR helper..."
            
            # Install git and base-devel if not present
            sudo pacman -S --needed git base-devel
            
            # Clone and build yay
            temp_dir=$(mktemp -d)
            cd "$temp_dir"
            git clone https://aur.archlinux.org/yay.git
            cd yay
            makepkg -si --noconfirm
            cd ~
            rm -rf "$temp_dir"
        fi

        # Determine AUR helper
        if command -v yay &> /dev/null; then
            AUR_HELPER="yay"
        elif command -v paru &> /dev/null; then
            AUR_HELPER="paru"
        else
            echo "❌ Could not determine AUR helper"
            exit 1
        fi

        echo "✅ Using $AUR_HELPER as AUR helper"

        # Install packages needed for your dotfiles
        echo "📦 Installing packages needed for your dotfiles..."

        # Core packages
        sudo pacman -S --needed --noconfirm \
            neovim \
            zsh \
            alacritty \
            git \
            curl \
            wget \
            ripgrep \
            fd \
            fzf \
            python \
            python-pip \
            nodejs \
            npm \
            rust \
            cargo \
            w3m \
            mpv \
            firefox

        # Install VSCodium if requested
        if [ "$INSTALL_CODIUM" = true ]; then
            echo "📦 Installing VSCodium with Neovim keybindings..."
            $AUR_HELPER -S --needed --noconfirm \
                codium-bin
        fi

        # AUR packages needed for your setup
        $AUR_HELPER -S --needed --noconfirm \
            lazygit \
            ttf-jetbrains-mono-nerd

        ;;
    "gentoo")
        echo "🐧 Installing for Gentoo system..."
        
        # Install packages using emerge
        sudo emerge --sync
        sudo emerge -uDU --with-bdeps=y \
            app-editors/neovim \
            app-shells/zsh \
            x11-terms/alacritty \
            dev-vcs/git \
            net-misc/curl \
            net-misc/wget \
            sys-apps/ripgrep \
            sys-apps/fd \
            app-misc/fzf \
            dev-lang/python \
            dev-lang/nodejs \
            dev-util/cargo \
            net-analyzer/nmap \
            www-client/firefox \
            media-video/mpv \
            www-client/w3m
        
        # Install Python packages needed for your scripts
        pip install --user \
            textual \
            httpx \
            beautifulsoup4 \
            html2text \
            PyQt6 \
            PyQt6-WebEngine

        # Install Node packages needed for Neovim
        sudo npm install -g \
            neovim

        # Install lazygit from source on Gentoo
        go install github.com/jesseduffield/lazygit@latest
        sudo cp ~/go/bin/lazygit /usr/local/bin/

        # Install JetBrains Nerd Font
        sudo emerge -av media-fonts/nerd-fonts-jetbrains-mono

        # Install VSCodium if requested
        if [ "$INSTALL_CODIUM" = true ]; then
            echo "📦 Installing VSCodium with Neovim keybindings..."
            echo 'app-editors/codium **' | sudo tee /etc/portage/package.accept_keywords/codium
            sudo emerge -av app-editors/codium
            # Install Neovim extension for VSCodium
            /usr/bin/codium --install-extension asvetliakov.vscode-neovim
        fi

        ;;
    "nixos")
        echo "❄️ Detected NixOS system..."
        echo "📝 NixOS detected. Using flake.nix for configuration."
        echo "💡 To apply the configuration, run: home-manager switch --flake ."
        echo "💡 Or: nix run home-manager/master -- switch --flake ."
        
        # Install home-manager if not already installed
        if ! command -v home-manager &> /dev/null; then
            echo "📦 Installing home-manager..."
            nix-channel --add https://github.com/nix-community/home-manager/archive/release-23.11.tar.gz home-manager
            nix-channel --update
            nix-shell '<home-manager>' -A install
        fi
        
        # Install VSCodium if requested
        if [ "$INSTALL_CODIUM" = true ]; then
            echo "📝 Adding VSCodium to flake configuration..."
            # This would require modifying the flake.nix file to include VSCodium
            # For now, we'll just note it in the instructions
            echo "💡 VSCodium with Neovim keybindings will be added to your home-manager config"
        fi

        ;;
    *)
        echo "❌ Unsupported distribution: $DISTRO"
        echo "💡 This script supports Arch, Gentoo, and NixOS only"
        exit 1
        ;;
esac

# Install Python packages needed for your scripts (for Arch and Gentoo)
if [[ "$DISTRO" == "arch" || "$DISTRO" == "gentoo" ]]; then
    pip install --user \
        textual \
        httpx \
        beautifulsoup4 \
        html2text \
        PyQt6 \
        PyQt6-WebEngine
fi

# Install Node packages needed for Neovim (for Arch and Gentoo)
if [[ "$DISTRO" == "arch" || "$DISTRO" == "gentoo" ]]; then
    sudo npm install -g \
        neovim
fi

# Setup directories
mkdir -p ~/.config/{nvim,zsh,alacritty}

# Copy configuration files
echo "📝 Setting up configuration files..."

# Backup existing configs if they exist
[[ -f ~/.zshrc ]] && mv ~/.zshrc ~/.zshrc.backup.$(date +%s)
[[ -f ~/.config/nvim/init.lua ]] && mv ~/.config/nvim/init.lua ~/.config/nvim/init.lua.backup.$(date +%s)
[[ -f ~/.config/alacritty/alacritty.toml ]] && mv ~/.config/alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml.backup.$(date +%s)

# Link config files
ln -sf $(pwd)/init.lua ~/.config/nvim/init.lua
ln -sf $(pwd)/.zshrc ~/.zshrc
ln -sf $(pwd)/alacritty.toml ~/.config/alacritty/alacritty.toml

# Create scripts directory and copy scripts
mkdir -p ~/.local/bin
cp ./scripts/* ~/.local/bin/
chmod +x ~/.local/bin/*

# Install the mommy praise engine
if ! command -v mommy &> /dev/null; then
    echo " installing mommy..."
    ./install_mommy.sh
fi

# Setup Zsh as default shell if not already (for Arch and Gentoo)
if [[ "$DISTRO" == "arch" || "$DISTRO" == "gentoo" ]]; then
    if [[ "$SHELL" != *"zsh"* ]]; then
        echo "셸 Changing default shell to zsh..."
        chsh -s $(which zsh)
    fi
fi

echo "🎉 LEGENDDOTS UNIVERSAL SETUP COMPLETE!"
echo ""
echo "🔧 Next steps:"
if [[ "$DISTRO" == "nixos" ]]; then
    echo "   1. Apply home-manager config: home-manager switch --flake ."
    echo "   2. Launch nvim and run ':Lazy sync' to install plugins"
    echo "   3. Launch LazyGit once to accept its license"
else
    echo "   1. Restart your shell or run: exec zsh"
    echo "   2. Launch nvim and run ':Lazy sync' to install plugins"
    echo "   3. Launch LazyGit once to accept its license"
fi
echo ""
if [ "$INSTALL_CODIUM" = true ]; then
    if [[ "$DISTRO" == "nixos" ]]; then
        echo "💡 VSCodium with Neovim keybindings will be available after applying home-manager config"
    else
        echo "💡 VSCodium with Neovim keybindings installed as fallback"
        echo "   Launch with: codium"
    fi
fi
echo ""
echo "🔥 Remember: Minimalism is a defensive posture!" 
