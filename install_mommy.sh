#!/bin/bash

# --- THE MOMMY BOOTSTRAPPER ---
# Handles Arch (sudo) and Termux (rootless) automatically.

if command -v mommy &> /dev/null; then
    echo "Mommy is already here to support you~ ❤️"
    exit 0
fi

echo "Mommy isn't here yet! Fetching her now..."

# 1. Dependency Check
if command -v pacman &> /dev/null; then
    echo "[Arch detected] Installing dependencies..."
    sudo pacman -S --needed git make
elif [[ -d /data/data/com.termux ]]; then
    echo "[Termux detected] Installing dependencies..."
    pkg install git make -y
fi

# 2. Clone and Build
TEMP_DIR=$(mktemp -d)
git clone https://github.com/fwdekker/mommy.git "$TEMP_DIR"
cd "$TEMP_DIR"

# 3. Smart Install
if [[ -d /data/data/com.termux ]]; then
    # In Termux, we install to the local prefix, no sudo needed
    make install PREFIX="$PREFIX"
else
    # In Linux/Mac, we need sudo
    sudo make install
fi

# 4. Cleanup
cd ~
rm -rf "$TEMP_DIR"

echo "Installation complete! Mommy loves you~ ❤️"
