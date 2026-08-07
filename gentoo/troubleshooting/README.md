# Gentoo Troubleshooting & Maintenance Scripts

Diagnostic and repair scripts for the niri/Wayland Gentoo setup on the MacBook
Air 6,2, run *after* a system is installed and booted. The core scripts live one
level up: `../install.sh` (installer), `../resume.sh` (installer recovery),
`../niri` (session launcher), and `../setup` (post-install provisioning).

All scripts here are self-contained — copy the one-line invocation and run it.
Most are read-only diagnostics; the ones that change state say so below.

| Script | Root? | Changes the system? | Use it when |
|--------|-------|---------------------|-------------|
| `apply` | no (you) | yes (session only) | Pushing dotfile + wallpaper/audio changes into a running niri session |
| `audio-debug` | no (you) | no (read-only) | Sound isn't working and you need to see what the hardware/pipewire state is |
| `verify-boot` | no (you) | no (read-only) | About to reboot after a kernel rebuild — confirm it won't brick |
| `fix-wifi` | yes (`doas`) | yes | Broadcom WiFi dropped or the `wl` module isn't loaded |
| `i915-fix` | mixed | yes (bootloader) | Display is broken / `/dev/dri/renderD128` missing (nomodeset stuck on) |
| `check-32bit` | no (you) | no (read-only) | Auditing that the system is fully 64-bit / no multilib remnants |
| `build-rooted-lineage` | yes (`doas`) | yes | Building a rooted, GApps-free LineageOS image on Waydroid (lives in `../waygentoodroid/`) |

> `setup` (post-install provisioning) lives at `../setup`, not here — it's a core
> script alongside install/resume/niri, not a troubleshooting tool. Likewise
> `build-rooted-lineage` lives in `../waygentoodroid/` — it's a Waydroid image
> builder, listed here only so it's discoverable. See
> [`../waygentoodroid/README.md`](../waygentoodroid/README.md).

---

## `apply` — push config into a running session

```sh
bash ~/legenddots/gentoo/troubleshooting/apply
```

Run it **as yourself, from a terminal inside niri** (not root, not SSH). Pulls
the latest legenddots, refreshes all dotfile symlinks, restarts `swaybg` with
the wallpaper, and starts `pipewire`/`pipewire-pulse`/`wireplumber` if they
aren't already running. The quick way to see config changes without logging out.

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

Evicts any competing Broadcom driver (`brcmfmac`/`b43`/`bcma`/`ssb`), loads
`wl`, restarts NetworkManager, and reports device status. If it prints
`wl FAILED` (symbol/vermagic mismatch after a kernel rebuild), boot `vmlinuz.old`
at the rEFInd menu — WiFi works there — then rebuild the module for the new
kernel:

```sh
doas emerge @module-rebuild && doas depmod -a
```

If WiFi simply *dropped* after working (device shows `disconnected`/`unavailable`
in `nmcli device status`), it's usually a reconnect or rfkill issue, not the
module:

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
