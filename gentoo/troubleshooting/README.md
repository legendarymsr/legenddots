# Gentoo Troubleshooting & Maintenance Scripts

Diagnostic and repair scripts for the niri/Wayland Gentoo setup on the MacBook
Air 6,2, run *after* a system is installed and booted. The core scripts live one
level up: `../install.sh` (installer), `../resume.sh` (installer recovery),
`../niri` (session launcher), and `../setup` (post-install provisioning).

All scripts here are self-contained — copy the one-line invocation and run it.
Most are read-only diagnostics; the ones that change state say so below.

| Script | Root? | Changes the system? | Use it when |
|--------|-------|---------------------|-------------|
| `audio-debug` | no (you) | no (read-only) | Sound isn't working and you need to see what the hardware/pipewire state is |
| `verify-boot` | no (you) | no (read-only) | About to reboot after a kernel rebuild — confirm it won't brick |
| `fix-wifi` | yes (`doas`) | yes | Broadcom WiFi dropped or the `wl` module isn't loaded |
| `i915-fix` | mixed | yes (bootloader) | Display is broken / `/dev/dri/renderD128` missing (nomodeset stuck on) |
| `check-32bit` | no (you) | no (read-only) | Auditing that the system is fully 64-bit / no multilib remnants |
| `check-virt` | yes (`sudo`) | no (read-only) | QEMU/KVM or Waydroid won't work — pinpoints whether it's the kernel config, a group, firmware VT-x, or lockdown |
| `rescue` | yes (`sudo`, from a **live USB**) | yes | System won't boot / an update was interrupted — chroot in and rebuild everything |
| `rebuild-kernel` | yes (root, in chroot) | yes | Kernel hangs at rEFInd "Starting vmlinuz" / boots blind — rebuild from the proven config |
| `build-rooted-lineage` | yes (`doas`) | yes | Building a rooted, GApps-free LineageOS image on Waydroid (lives in `../waygentoodroid/`) |

> `setup` (post-install provisioning) lives at `../setup`, not here — it's a core
> script alongside install/resume/niri, not a troubleshooting tool. Likewise
> `build-rooted-lineage` lives in `../waygentoodroid/` — it's a Waydroid image
> builder, listed here only so it's discoverable. See
> [`../waygentoodroid/README.md`](../waygentoodroid/README.md).

---

## `audio-debug` — sound diagnostics (read-only)

```sh
bash ~/legenddots/gentoo/troubleshooting/audio-debug
```

Dumps everything needed to diagnose no-sound: `aplay -l` cards, the PCI audio
device, loaded `snd` modules, `/dev/snd` nodes, group membership, ALSA mixer
mute state, which audio daemons are running, `wpctl status`, and kernel audio
messages. Changes nothing — just paste the output.

Common findings: ALSA master/speaker **muted** (CS4208 boots muted — unmute with
`amixer`/`alsamixer` then `doas alsactl store`), or `wpctl` "Could not connect
to PipeWire" which means you're on SSH/a bare TTY with no session bus (run it
from a terminal *inside* niri instead).

## `verify-boot` — pre-reboot kernel check (read-only)

```sh
bash ~/legenddots/gentoo/troubleshooting/verify-boot
```

Run **before rebooting after a kernel rebuild.** Confirms the three things that
brick a boot when they drift apart: a kernel image exists in `/boot` (reads the
version out of the unversioned `/boot/vmlinuz` with `file`), rEFInd's `initrd=`
points to an initramfs that actually exists and matches, and `wl.ko` is built
for that kernel version so WiFi survives. Ends with a clear
"safe to reboot" / "do NOT reboot" verdict. An orange `!` line is informational;
only a red `✗` blocks you.

## `fix-wifi` — Broadcom WiFi recovery

```sh
doas bash ~/legenddots/gentoo/troubleshooting/fix-wifi
```

Does the whole recovery in one command: evicts competing Broadcom drivers
(`brcmfmac`/`b43`/`bcma`/`ssb`), loads `wl`, **stops a stray `dhcpcd`** that would
grab the interface out from under NetworkManager (the cause of `wlp3s0
connected (externally)` with a stale IP + `NO-CARRIER` + dead DNS), hands the
device to NM, scans, and then **prompts you for an SSID + password and
connects** — so there's no chain of `nmcli` lines to type. Ends by confirming a
default route / DNS.

If it prints `wl FAILED` (symbol/vermagic mismatch after a kernel rebuild),
rebuild the module against the running kernel (`--usepkg=n` forces a *source*
build so `wl.ko` matches — a stale binpkg is built for a different kernel):

```sh
doas emerge --usepkg=n @module-rebuild && doas depmod -a
```

If the scan shows nothing, the radio may be blocked:

```sh
doas rfkill unblock all && doas rc-service NetworkManager restart
```

If it recurs on battery, disable TLP WiFi power-saving in `/etc/tlp.conf`:
`WIFI_PWR_ON_BAT=off`.

## `i915-fix` — display / KMS repair

```sh
doas bash ~/legenddots/gentoo/troubleshooting/i915-fix
```

For when the display is broken or `/dev/dri/renderD128` is missing because
`nomodeset` is stuck on the kernel cmdline (blocks Intel i915 KMS and the DRI
render node niri needs). Reads `/proc/cmdline`, and if `nomodeset` is present,
strips it from `/boot/refind_linux.conf`. Reboot afterward, then start niri with
`bash ~/legenddots/gentoo/niri`.

## `check-32bit` — audit for 32-bit / multilib remnants (read-only)

```sh
bash ~/legenddots/gentoo/troubleshooting/check-32bit
```

Confirms the system is genuinely 64-bit-only after the switch to the no-multilib
profile. Checks the active profile, `ABI_X86`, `/usr/lib32` + `/lib32`, gcc's
multilib runtime libs (`gcc -print-multi-lib`), packages built with `abi_x86_32`
(from `/var/db/pkg/*/*/USE`), and any stray `ELF 32-bit` binaries in the main
bin/lib dirs. Ends `Clean` or lists what's left with the exact fix
(profile switch → `emerge --changed-use --deep @world` → `--depclean`); exits
non-zero if anything's found. Typical first run flags `/usr/lib32` and gcc's
32-bit libs — leftovers from a build made before switching profiles — which the
rebuild sweeps out.

## `check-virt` — why QEMU/KVM or Waydroid won't work (read-only)

```sh
sudo bash ~/legenddots/gentoo/troubleshooting/check-virt
```

Changes nothing — it just tells you which layer is broken so you fix the right
thing instead of guessing. It checks, in order: the **CPU** flags (`vmx`/`svm` in
`/proc/cpuinfo` → firmware VT-x), the **running kernel** via `/proc/config.gz`
(`KVM`, `KVM_INTEL`, `VHOST_NET`, `ANDROID_BINDER_IPC`/`BINDERFS`, `USER_NS`,
`BLK_DEV_LOOP`, `CGROUP_DEVICE`, `PSI`, `IP_NF_IPTABLES`), **`/dev/kvm`** and
`kvm`-group membership, **libvirtd**, the **lockdown** LSM state
(`/sys/kernel/security/lockdown`), and **Waydroid** (`/dev/loop-control`,
binderfs, `waydroid status`, the container service). Each failure prints its exact
fix, and the summary says whether you need to **rebuild the kernel**
(`rebuild-kernel`), **re-login** for a group, flip a **BIOS** switch, or **start a
service**.

The hardening angle: basic KVM VMs and Waydroid are *not* blocked by this system's
lockdown LSM (it's not enforced unless you add `lockdown=` to the cmdline) — the
usual real blockers are the kernel missing `USER_NS`/`BLK_DEV_LOOP` for Waydroid's
container, or the `kvm` group not yet applied to your session. `check-virt` tells
you which.

## `rescue` — finish an interrupted update + rebuild the kernel (in place)

Runs **inside your Gentoo system** — either booted normally, or after you've
chrooted in from a live USB. It does *not* mount or chroot anything itself (that
was more trouble than help); it just runs the repair against the current root:

```sh
bash rescue                 # do everything
SKIP_WORLD=1  bash rescue    # kernel rebuild only
SKIP_KERNEL=1 bash rescue    # finish @world only
```

It: (1) finishes `@world` unattended (`--autounmask-continue --keep-going
--backtrack=100`) + `--depclean`, (2) rebuilds out-of-tree modules (`wl.ko`),
(3) rebuilds the kernel with its *existing* `.config` (`make olddefconfig &&
make -j3 && make modules_install && make install`) + regenerates the initramfs,
(4) repoints rEFInd's `initrd=`, (5) runs `verify-boot`. Idempotent — if it
stops on something, fix that and re-run.

**Don't pipe it through `tee`** — that buffers the output so it looks frozen.
Redirect instead if you want a log:
```sh
bash rescue &> /tmp/rescue.log &
tail -f /tmp/rescue.log
```

> Why it rebuilds the kernel: after `make install` runs twice, both `vmlinuz`
> and `vmlinuz.old` can end up being the *same* freshly-built kernel — so a bad
> build leaves no working fallback and both rEFInd entries freeze identically.
> Rebuilding against the finished toolchain + a matching initramfs is what gets
> you booting again.

### Full recovery from a live USB (EndeavourOS) — copy-paste

Boot a 64-bit live USB (EndeavourOS is handy — it has NetworkManager + a real
desktop). Assumes the standard layout (`sda1` EFI, `sda2` swap, `sda3` root) —
run `lsblk -f` first and swap device names if the USB grabbed `sda`.

**1. Become root, get network, and stop the live env sabotaging the recovery:**
```sh
sudo -i                                 # ← become root FIRST (prompt turns to #)
nmtui                                   # connect to WiFi
iw dev wlan0 set power_save off         # Broadcom drops under load otherwise
# STOP it suspending on idle/lid-close — this is what kills long builds + SSH:
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
ip -4 addr show wlan0                    # note the IP if you'll SSH in from a phone
```

**(optional) SSH in from your phone** for a real keyboard:
```sh
passwd                                   # set a password for 'liveuser'
systemctl start sshd
#   then on the phone:   ssh liveuser@<that IP>
#   stale host key from a previous boot?   ssh-keygen -R <that IP>
```

**2. Mount your Gentoo system with a sane `/dev`:**
```sh
lsblk -f                                 # confirm sda1/sda2/sda3
mount /dev/sda3 /mnt
mount /dev/sda1 /mnt/boot/efi
mount -t proc /proc /mnt/proc
mount --rbind /sys /mnt/sys && mount --make-rslave /mnt/sys
mount --rbind /dev /mnt/dev && mount --make-rslave /mnt/dev
mount --rbind /run /mnt/run && mount --make-rslave /mnt/run
echo nameserver 1.1.1.1 > /mnt/etc/resolv.conf
```

**3. chroot in and run the repair:**
```sh
chroot /mnt /bin/bash
source /etc/profile
ls -l /dev/fd                            # must show -> /proc/self/fd (portage needs it)
[ -d /root/legenddots ] || git clone https://github.com/legendarymsr/legenddots.git /root/legenddots
bash /root/legenddots/gentoo/troubleshooting/rescue
```
To watch it without depending on the SSH link staying up (never `tee` — it
buffers the output into silence):
```sh
bash /root/legenddots/gentoo/troubleshooting/rescue &> /tmp/rescue.log &
tail -f /tmp/rescue.log
```

**4. When `verify-boot` is green, leave and reboot:**
```sh
exit                                     # out of the chroot
umount -R /mnt
reboot                                   # then pick your kernel in rEFInd
```

Gotchas this flow works around:
- **Don't use `arch-chroot`** — it sometimes leaves `/dev/fd` broken and portage
  refuses to run (`Failed to validate a sane '/dev'`). The explicit `mount -t proc`
  + plain `chroot` above avoids it.
- **Don't `pacman -S tmux`** on the EndeavourOS live env — its Arch mirrors are
  often unconfigured (`no servers configured for repository: extra`). `nohup` /
  backgrounding (above) gives the same "survives a WiFi drop" resilience.
- **If the USB took `sda`**, your disk is `sdb`/`sdc`/… — read `lsblk -f` and swap
  the device names throughout.

### Kernel freezes at rEFInd "Starting vmlinuz" — `rebuild-kernel`

**Symptom:** rEFInd shows `Starting vmlinuz` / `Using load options …` and hangs
there with **no kernel output at all**. The image loads but never executes (or
boots *blind* with no display / can't mount root). This is a `REBUILD_KERNEL`
that fell back to bare `make defconfig` — no `/proc/config.gz` on the running
kernel and no saved `/boot/config-*` — and so **dropped the Apple EFI display
stack** (`DRM_SIMPLEDRM`, `SYSFB_SIMPLEFB`, `FRAMEBUFFER_CONSOLE`) and the
built-in root drivers (`EXT4_FS`, `SATA_AHCI`, `BLK_DEV_SD`). The cmdline is fine;
the *config* is the problem.

There is **no saved good `.config`** to reuse (`/boot/config-*` doesn't exist —
`make install` never saved one, and depclean deleted the source tree's copy). So
the fix rebuilds from `install.sh`'s **proven recipe** — `make defconfig` + every
hardware/display/driver/hardening tweak. It's ~50 config lines, so it's a script,
not a paste. Boot the live USB, mount + chroot in (blocks 1–3 above), then **one
line**:

```sh
bash /root/legenddots/gentoo/troubleshooting/rebuild-kernel
```

It re-emerges `gentoo-sources` if the tree is gone, applies the full config,
**verifies the display + root drivers are `=y` before the long build**, rebuilds
the kernel + initramfs + `wl.ko`, repoints rEFInd's `initrd=`, and runs
`verify-boot`. When it's green:

```sh
exit && umount -R /mnt && reboot
```

**If `verify-boot` flags `✗ wl.ko MISSING`** (a stale broadcom-sta *binary*
package got used instead of a source build — `@module-rebuild` without
`--usepkg=n`), fix just the WiFi module without rebuilding the whole kernel.
This derives the version from `/usr/src/linux`, so it's copy-paste-safe:

```sh
emerge --usepkg=n @module-rebuild
depmod -a "$(make -s -C /usr/src/linux kernelrelease)"
bash /root/legenddots/gentoo/troubleshooting/verify-boot
```

`--usepkg=n` forces a source compile of `wl.ko` against the kernel you just built.
Re-run `verify-boot` until it's all green, then `exit && umount -R /mnt && reboot`.

> Do **not** use `rescue`'s auto-config-restore for this failure — it grabs the
> *newest* `/boot/config-*` (the broken build). `rebuild-kernel` builds the config
> from scratch instead, which is what you want when no good config survives.
