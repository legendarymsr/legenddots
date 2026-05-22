Rebuild the CaulkLinux ISO and launch it in QEMU/KVM. Run these steps in order:

1. `cd /home/user/legenddots/caulklinux && make clean && make iso`
2. Reset QEMU NVRAM: `cp /usr/share/edk2/x64/OVMF_VARS.4m.fd /home/user/legenddots/caulklinux/OVMF_VARS.fd`
3. Recreate blank target disk: `rm -f /home/user/legenddots/caulklinux/test.qcow2 && qemu-img create -f qcow2 /home/user/legenddots/caulklinux/test.qcow2 20G`
4. Boot the new ISO:
```
cd /home/user/legenddots/caulklinux && sudo -E qemu-system-x86_64 \
  -enable-kvm -cpu host -m 2G -smp 2 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=OVMF_VARS.fd \
  -cdrom caulklinux-*.iso \
  -drive file=test.qcow2,format=qcow2,if=virtio \
  -vga virtio -display sdl -boot d
```

Report each step as it completes and show any errors immediately.
