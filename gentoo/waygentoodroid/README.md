# waygentoodroid

Build a **rooted, GApps-free LineageOS** image on Waydroid — one command.

Waydroid's stock image already **is** LineageOS (the official images are built
straight from Lineage). So this doesn't fetch a different OS — it takes the
**VANILLA** (no-GApps) Lineage image and layers on the three things that make it
useful and yours:

| Layer | What | Why |
|-------|------|-----|
| **Magisk (Delta)** | root | The container-friendly Magisk fork; gives you `su` inside Android. |
| **ARM translation** | `libhoudini` (Intel) / `libndk` (AMD) | Most Play-Store apps ship ARM-only; without this they won't install/run on your x86 Air. Auto-picked from `/proc/cpuinfo`. |
| **microG** | FOSS Play-Services stand-in | You said **no GApps** — microG fills the gap (push, location, SafetyNet-lite) without Google's binary blobs. |

All of it is done by [`casualsnek/waydroid_script`](https://github.com/casualsnek/waydroid_script),
which patches the system image in place. This wrapper just drives it idempotently
and picks the right ARM layer for your CPU.

---

## Prerequisites

1. **Waydroid installed** — `gentoo/setup` builds it from source.
2. **A kernel with binder** — `ANDROID_BINDER_IPC` + `ANDROID_BINDERFS`
   (the `REBUILD_KERNEL` step sets these; verify with `ls /dev/binderfs`).
   The image will *build* without binder, but Waydroid won't *start* until you
   boot a binder-enabled kernel. The script warns if it's missing.

## Run it

```sh
doas bash gentoo/waygentoodroid/build-rooted-lineage
```

First run downloads ~1 GB (the Lineage system + vendor images). Then start it
**from inside your niri Wayland session, as your user** (not root):

```sh
waydroid session start &
waydroid show-full-ui
```

**Verify root:** open the **Magisk** app inside Android, or:

```sh
waydroid shell        # then, inside:
su                    # Magisk should grant it
```

## Options (all env-overridable)

| Var | Default | Meaning |
|-----|---------|---------|
| `SYSTEM_TYPE` | `VANILLA` | `VANILLA` = **no GApps**. `GAPPS` if you ever want the opposite. |
| `INSTALL_MAGISK` | `true` | Root. |
| `INSTALL_ARM` | `true` | ARM→x86 translation (auto: houdini on Intel, ndk on AMD). |
| `INSTALL_MICROG` | `true` | microG. Set `false` for a truly bare AOSP-ish image. |
| `INSTALL_WIDEVINE` | `false` | L3 DRM (Netflix/Spotify web-tier). Off by default. |
| `REINIT` | `false` | `true` re-downloads a **clean** image first (`waydroid init -f`) — **wipes your patches and data**. |
| `SYSTEM_CHANNEL` / `VENDOR_CHANNEL` | *(unset)* | Point at a non-default OTA server (see Android versions below). |

Examples:

```sh
# add Widevine to an already-built image (re-run is safe)
INSTALL_WIDEVINE=true doas bash gentoo/waygentoodroid/build-rooted-lineage

# start over from a clean Lineage image
REINIT=true doas bash gentoo/waygentoodroid/build-rooted-lineage

# rooted but nothing else — no microG, no ARM
INSTALL_MICROG=false INSTALL_ARM=false doas bash gentoo/waygentoodroid/build-rooted-lineage
```

The script is **idempotent** — re-run it to add a module or repair the tree. It
only re-inits the image if there isn't one yet, or you pass `REINIT=true`.

---

## Side-load a working Magisk app + Termux (`install-apks`)

`waydroid_script`'s bundled **Magisk app (Delta) sometimes won't launch** — root
still works (that's the `magiskd` daemon, separate from the manager app), it's just
the UI. `install-apks` swaps the app for a fresh APK and preinstalls Termux.

Unlike the builder, this runs **as your user, inside niri, with Waydroid running**
(it uses `waydroid app install`, which goes through the live session):

```sh
waydroid session start &        # if it isn't already
bash ~/legenddots/gentoo/waygentoodroid/install-apks
```

It removes any existing Magisk app package, installs the latest official Magisk APK
(`topjohnwu/Magisk`), and installs the x86_64 Termux build (native to the container).
Options: `MAGISK_REPO=HuskyDG/magisk-files` for Magisk Delta (matches the daemon
`waydroid_script` installs, if the official app misbehaves), `INSTALL_TERMUX=false`,
`INSTALL_MAGISK=false`. Reopen the app drawer afterward; verify root is intact with
`waydroid shell su -c id` (want `uid=0`).

## "Can I get Android 16 running?"

**Short answer: not realistically yet — Android 11 or 13 is the ceiling today.**

Here's the honest why. Waydroid can't boot a normal phone ROM or a generic GSI.
It needs a **specially-built system + vendor image** adapted for the Waydroid
target: it runs Android's HALs over your *host* kernel's binder and talks to your
host GPU through a Halium-style gralloc/Mesa path. So the Android version you can
run is **whatever the image server publishes for the Waydroid target**, not
whatever LineageOS version exists.

What actually exists:

- **Android 11 (LineageOS 18.1)** — the long-standing, rock-solid default. This
  is what you get out of the box, and it's where root + houdini + microG are most
  reliable.
- **Android 13 (LineageOS 20)** — available on newer channels; works but is less
  battle-tested, and each Android bump can temporarily break a `waydroid_script`
  module until casualsnek updates it.
- **Android 14/15/16 (LineageOS 21/22/23)** — **no maintained Waydroid images**
  as of early 2026. LineageOS itself trails each Android release by months, and
  then someone has to build + host a *Waydroid-target* image on top. Android 16
  (Lineage 23) isn't there.

**If** a trustworthy Android 13+ (or, later, higher) Waydroid image appears, you
point this script at it without changing anything else:

```sh
SYSTEM_CHANNEL="https://some.ota.server/system" \
VENDOR_CHANNEL="https://some.ota.server/vendor" \
REINIT=true doas bash gentoo/waygentoodroid/build-rooted-lineage
```

(The channels are just OTA URLs; Waydroid stores them in `/var/lib/waydroid/waydroid.cfg`.)
Vet any third-party image server before trusting it with a rooted Android — you're
running its binaries with a `su` inside. Stick to Android 11/13 from the official
`ota.waydro.id` unless you have a specific reason not to.

---

## Caveats

- **Play Integrity / hardware attestation** — Magisk + microG can pass *basic*
  checks, but **hardware-backed attestation fails inside a container.** Some
  banking/DRM apps will still refuse regardless of root. That's a Waydroid limit,
  not something root fixes.
- **`REINIT=true` wipes everything** — clean image means your apps, data, and
  patches are gone. It's the "start fresh" button, not "update".
- **GPU on the Air** — Waydroid renders through the host GPU (your Intel HD 5000 /
  i915). If you get a black UI, it's usually a gralloc/rendering issue, not this
  script — check `waydroid log` and the
  [Waydroid FAQ](https://docs.waydro.id/). Software rendering
  (`waydroid prop set persist.waydroid.multi_windows true`, or the GPU props in
  the docs) is the usual workaround.
- **microG needs signature spoofing**, which `waydroid_script` sets up in the
  image — but not every app tolerates it. If one misbehaves, that's the tradeoff
  for skipping GApps.
- Everything the script installs is a `waydroid_script` module — you can also
  `remove` them: `sudo /opt/waydroid_script/venv/bin/python3 /opt/waydroid_script/main.py remove magisk`.
