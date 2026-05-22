#!/usr/bin/env bash
set -e

# ── deps ─────────────────────────────────────────────────────────────────────
need() { pacman -Qi "$1" &>/dev/null || sudo pacman -S --noconfirm "$1"; }
need archiso
need qemu-desktop
need edk2-ovmf
need gcc

# ── build ─────────────────────────────────────────────────────────────────────
REPO="https://github.com/legendarymsr/legenddots.git"
DIR="$HOME/.cache/caulklinux-build"

if [ -d "$DIR/.git" ]; then
    git -C "$DIR" pull --ff-only
else
    git clone "$REPO" "$DIR"
fi

cd "$DIR/caulklinux"
make clean
make iso

# ── qemu ──────────────────────────────────────────────────────────────────────
ISO=$(ls -t caulklinux-*.iso | head -1)
VARS=/tmp/caulk-ovmf-vars.fd
DISK=/tmp/caulk-test.qcow2

cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$VARS"
qemu-img create -f qcow2 "$DISK" 20G

sudo -E qemu-system-x86_64 \
    -enable-kvm -cpu host -m 2G -smp 2 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
    -drive if=pflash,format=raw,file="$VARS" \
    -cdrom "$ISO" \
    -drive file="$DISK",format=qcow2,if=virtio \
    -vga std -display sdl -boot d
