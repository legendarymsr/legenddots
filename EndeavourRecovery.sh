#!/bin/bash

# ==========================================================================
# LEGENDDOTS: ENDEAVOUR-OS RECOVERY PROTOCOL v22.2
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

# --- 3. PACMAN SWEEP (Core, Virtualization & GPU Accel) ---
echo "🏹 SYNCING SYSTEM AND INSTALLING ARSENAL..."

# Added virglrenderer and libepoxy for the VM GPU passthrough
sudo pacman -Syu --noconfirm --needed \
    neovim zsh alacritty git curl wget ripgrep fd fzf nodejs npm \
    rust python python-pip w3m mpv gcc make espeak-ng \
    qemu-desktop libvirt virt-manager dnsmasq iptables-nft \
    edk2-ovmf virglrenderer libepoxy xz \
    python-httpx python-beautifulsoup4 python-pyqt6 python-pyqt6-webengine

# --- 4. AUR HELPER ---
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
sudo virsh net-start default 2>/dev/null || true
sudo virsh net-autostart default 2>/dev/null || true

# --- 6. THE OFFENSIVE BUNKER (NETHUNTER PRO AMD64) ---
echo "📡 DEPLOYING KALI NETHUNTER PRO LAB..."
VM_DIR="$HOME/VMs/NetHunter"
mkdir -p "$VM_DIR"
IMG_XZ="kali-nethunterpro-2025.4-amd64.img.xz"
IMG_RAW="kali-nethunterpro-2025.4-amd64.img"
# Using the verified Kali image path
DOWNLOAD_URL="https://old.kali.org/nethunterpro-images/kali-2025.4/$IMG_XZ"

if [ ! -f "$VM_DIR/$IMG_RAW" ]; then
    echo "📥 Downloading NetHunter Pro image (2.2GB)..."
    wget -c "$DOWNLOAD_URL" -O "$VM_DIR/$IMG_XZ"
    echo "📦 Decompressing (Keeping backup)..."
    xz -dk "$VM_DIR/$IMG_XZ"
    echo "🏗️ Expanding virtual partition (+20GB)..."
    qemu-img resize "$VM_DIR/$IMG_RAW" +20G
fi

# Create the Yuki-certified launcher
cat <<EOF > "$VM_DIR/start-kali.sh"
#!/usr/bin/env bash
# NetHunter Pro Launcher: KVM + VirGL Accel
qemu-system-x86_64 \\
  -enable-kvm \\
  -cpu host \\
  -smp 4 \\
  -m 4G \\
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \\
  -drive file="$VM_DIR/$IMG_RAW",format=raw,if=virtio \\
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \\
  -device virtio-net-pci,netdev=net0 \\
  -device virtio-vga-gl \\
  -display gtk,gl=on \\
  -device virtio-tablet-pci \\
  -device virtio-keyboard-pci
EOF
chmod +x "$VM_DIR/start-kali.sh"

# --- 7. PYTHON EXTRACTION ---
echo "🐍 ENSURING TUI BROWSER DEPENDENCIES..."
pip install --user --break-system-packages textual html2text || echo "Textual already present."

# --- 8. IDENTITY PERSISTENCE (SYMLINKS) ---
echo "🔗 SYNCING IDENTITY TO FILESYSTEM..."
mkdir -p ~/.config/{nvim,alacritty,qutebrowser}

[[ -f ~/.zshrc ]] && mv ~/.zshrc ~/.zshrc.vanilla 2>/dev/null || true
[[ -f ~/.config/nvim/init.lua ]] && mv ~/.config/nvim/init.lua ~/.config/nvim/init.lua.vanilla 2>/dev/null || true

# Deploy Legenddots
ln -sf "$(pwd)/init.lua" ~/.config/nvim/init.lua
ln -sf "$(pwd)/.zshrc" ~/.zshrc
ln -sf "$(pwd)/alacritty.toml" ~/.config/alacritty/alacritty.toml
ln -sf "$(pwd)/legend-browsers/qute-config.py" ~/.config/qutebrowser/config.py

# --- 9. THE SPITE COMPILER (RUST) ---
if [[ -d "./fetch" ]]; then
    echo "Cr COMPILING 961-BYTE SPITE BINARY..."
    cd fetch
    rustc main.rs -o fetch-rs
    mkdir -p ../legend-browsers
    mv fetch-rs ../legend-browsers/
    cd ..
fi

# --- 10. ALIASES & PERSISTENCE ---
echo "📝 FINALIZING SHELL CONFIGURATION..."
# Ensure aliases for the new VM exist in ZSH
if ! grep -q "alias kali=" ~/.zshrc; then
    echo "" >> ~/.zshrc
    echo "# --- Red Team Lab ---" >> ~/.zshrc
    echo "alias kali='$VM_DIR/start-kali.sh'" >> ~/.zshrc
    echo "alias k-ssh='ssh -p 2222 kali@localhost'" >> ~/.zshrc
fi

# --- 11. FINAL HANDSHAKE ---
chmod +x ./legend-browsers/*

if [[ "$SHELL" != *"zsh"* ]]; then
    echo "🐚 SWITCHING DEFAULT SHELL TO ZSH..."
    sudo chsh -s /usr/bin/zsh $(whoami)
fi

echo "🎉 RECOVERY COMPLETE, LEGEND."
echo "💡 NetHunter Pro is startklar. Type 'kali' to launch."
echo "💡 Run 'nvim' to trigger Lazy.nvim plugin sync."