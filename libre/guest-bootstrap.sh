#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# =============================================================================
# libre/guest-bootstrap.sh — runs INSIDE a builder VM at boot, before the build:
#   Debian builder: embedded into the cloud-init seed by run-vm.sh
#   Guix builder:   baked into the image by guix-builder.scm (local-file)
#
# It gets this repo into the guest and a log channel back out to the host, then
# runs the real build script (libre/guest-build.sh or guest-build-guix.sh).
# Two transports, picked at runtime from what the host QEMU attached:
#
#   9p    (host QEMU has virtfs)  /mnt/repo = the host repo, read-only, live
#                                 /mnt/work = host $VM_DIR/work (build.log, done)
#   copy  (host QEMU lacks 9p)    the repo arrives as a raw tar on a read-only
#                                 virtio disk (found by ro + tar magic) -> unpacked into
#                                 /mnt/repo; the log streams to the host over the
#                                 virtio-serial port "libre.log"; "done" is a
#                                 LIBRE-BUILD-DONE line in that log.
#
# Checkpoints are unaffected: they live on the builder disk and the target.
# usage: guest-bootstrap.sh <build script, relative to the repo>
# env:   JOBS=N  -> MAKEFLAGS=-jN for both phases (unset = libre/setup defaults)
# =============================================================================
BUILD="${1:-libre/guest-build.sh}"
DONE_TAG="LIBRE-BUILD-DONE"
export PATH="/run/current-system/profile/bin:/run/current-system/profile/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
# Guix's kmod looks for modules here (there is no /lib/modules on Guix System)
[ -d /run/booted-system/kernel/lib/modules ] && export LINUX_MODULE_DIRECTORY=/run/booted-system/kernel/lib/modules
[ -n "${JOBS:-}" ] && export MAKEFLAGS="-j$JOBS"

say() { echo "== $(date '+%F %T') :: bootstrap: $*"; }
find_repo_disk() {   # read-only virtio disk that starts with a tar header
  for b in /sys/block/vd*; do
    [ "$(cat "$b/ro" 2>/dev/null)" = 1 ] || continue
    magic="$(dd if="/dev/${b##*/}" bs=512 count=1 2>/dev/null | tail -c +258 | head -c 5)"
    [ "$magic" = ustar ] && { echo "/dev/${b##*/}"; return 0; }
  done; return 1
}
find_port() {        # virtio-serial port named $1
  for p in /sys/class/virtio-ports/*; do
    [ "$(cat "$p/name" 2>/dev/null)" = "$1" ] && { echo "/dev/${p##*/}"; return 0; }
  done; return 1
}

mkdir -p /mnt/repo /mnt/work
for m in 9pnet_virtio 9p virtio_console; do modprobe "$m" 2>/dev/null; done

if mountpoint -q /mnt/repo \
   || mount -t 9p -o trans=virtio,version=9p2000.L,ro repo /mnt/repo 2>/dev/null; then
  # ── 9p: exactly the original behaviour ─────────────────────────────────────
  mountpoint -q /mnt/work || mount -t 9p -o trans=virtio,version=9p2000.L work /mnt/work
  LOG=/mnt/work/build.log
  say "repo shared over 9p (read-only)" | tee -a "$LOG" >/dev/console 2>&1
  { bash "/mnt/repo/$BUILD"; echo "EXIT=$?"; } >>"$LOG" 2>&1
else
  # ── copy: repo tarball on a virtio disk, log over virtio-serial ────────────
  # wait briefly for the devices (udev/modules may still be settling)
  i=0; while [ $i -lt 30 ]; do
    DEV="$(find_repo_disk)" && PORT="$(find_port libre.log)" && break
    i=$((i+1)); sleep 1
  done
  DEV="$(find_repo_disk)"; PORT="$(find_port libre.log)" || PORT=/dev/console
  if [ -z "$DEV" ]; then
    say "FATAL: no 9p share and no read-only repo tar disk — nothing to build from" >"$PORT" 2>&1
    echo "EXIT=97" >"$PORT" 2>/dev/null
    exit 97
  fi
  say "no mountable 9p share (none offered, or no 9p in this kernel) — unpacking repo snapshot from $DEV (log -> $PORT)" >"$PORT" 2>&1
  if mountpoint -q /mnt/repo; then :; else rm -rf /mnt/repo; mkdir -p /mnt/repo; fi
  if ! tar -xf "$DEV" -C /mnt/repo >"$PORT" 2>&1; then
    say "FATAL: could not unpack the repo tarball from $DEV" >"$PORT" 2>&1
    echo "EXIT=98" >"$PORT" 2>/dev/null
    exit 98
  fi
  rm -f /mnt/work/done                    # local scratch on the builder disk
  LOG=/mnt/work/build.log                 # local copy too, handy inside the VM
  say "repo snapshot unpacked ($(du -sh /mnt/repo 2>/dev/null | cut -f1)); starting $BUILD" | tee -a "$LOG" >"$PORT" 2>&1
  {
    bash "/mnt/repo/$BUILD"; echo "EXIT=$?"
    [ -f /mnt/work/done ] && echo "$DONE_TAG"
  } 2>&1 | tee -a "$LOG" >"$PORT"
fi
sync
