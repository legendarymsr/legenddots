;; SPDX-License-Identifier: GPL-3.0-or-later
;; =============================================================================
;; guix-builder.scm — a Guix System "builder" VM image for libre/run-vm-guix.sh.
;;
;; The joke that's also correct: bootstrap a 100%-free GNU/Linux-libre system
;; from an *FSF-endorsed, fully-free* distro (Guix System) instead of Debian.
;; Guix's default kernel is already Linux-libre — libre building libre.
;;
;; What this declares:
;;   - the LFS host build toolchain in the system profile (so the build runs
;;     with everything in PATH; Guix provides /bin/sh and /usr/bin/env too),
;;   - a DHCP client (libre/setup downloads sources, so it needs network),
;;   - a Shepherd service that, at boot, runs libre/guest-bootstrap.sh (baked
;;     into the image): it mounts the 9p shares /mnt/repo (ro) + /mnt/work (rw)
;;     if the host QEMU has virtfs, or else unpacks the repo from a tar disk and
;;     logs over virtio-serial — then runs libre/guest-build-guix.sh and halts.
;;     (The 9p mounts are NOT in file-systems: a missing share would fail the
;;     'file-systems' Shepherd service and with it the whole boot.)
;;
;; Build an image from it with:  guix system image -t qcow2 guix-builder.scm
;; (libre/run-vm-guix.sh does that for you.)
;;
;; Guix API notes (checked against guix master, Oct 2026):
;;   - dhcp-client-service-type was deprecated 2025-05 and REMOVED 2026-05-16
;;     (commit 3e713ae41c); dhcpcd-service-type (added 2025-03) replaces it.
;;     We look it up at runtime so this works on old and new Guix alike.
;;   - `-t qcow2` images are MBR-hybrid: vda1 = ESP, vda2 = root. So root is
;;     mounted by its label "Guix_image", not /dev/vda1 (which is the vfat ESP).
;;   - Shepherd's `halt` takes no -p (it always powers off; unknown args fail).
;;
;; Tested (Oct 2026, QEMU/TCG): `guix system image -t qcow2` with Guix 1.5.0,
;; 620ce4ff16 (2026-07-28) and 1a1ebcc9b7 (2026-10-01); the image boots, the
;; bootstrap finds the repo (9p and tar-disk) and libre/setup starts compiling.
;; =============================================================================

(use-modules (gnu)
             (gnu packages)
             (gnu services shepherd)
             (guix gexp)
             (srfi srfi-1))           ; append-map
(use-service-modules base networking)

;; DHCP client: dhcpcd-service-type on Guix >= 2025-03 (the only one left since
;; 2026-05); fall back to the old dhcp-client-service-type on older Guix.
;; Resolved at runtime so neither name is an "unbound variable" on either side.
(define %dhcp-client-service
  (let ((networking (resolve-interface '(gnu services networking))))
    (cond ((module-variable networking 'dhcpcd-service-type)
           => (lambda (var) (service (variable-ref var))))
          ((module-variable networking 'dhcp-client-service-type)
           => (lambda (var) (service (variable-ref var))))
          (else (error "guix-builder.scm: no DHCP client service type in \
(gnu services networking) — expected dhcpcd-service-type")))))

;; LFS host requirements, resolved by name so we don't chase module imports.
(define build-tools
  (map specification->package
       '("gcc-toolchain" "make" "bison" "flex" "m4" "texinfo"
         "parted" "dosfstools" "e2fsprogs" "util-linux"
         "perl" "python" "wget" "git" "sed" "tar"
         "gzip" "xz" "bzip2" "patch" "diffutils" "findutils" "grep"
         "gawk" "coreutils" "pkg-config" "file" "gettext"
         "which" "bash" "guix")))   ; no "binutils": gcc-toolchain ships
                                    ; them (+ the ld-wrapper) already

;; Optional extras, only if this Guix has them (no "unknown package" error on
;; older Guix): refind provides refind-install for libre/setup's bootloader step.
(define optional-tools
  (append-map (lambda (name)
                (let ((found (find-packages-by-name name)))
                  (if (null? found) '() (list (car found)))))
              '("refind")))

;; Run the build at boot (backgrounded, not one-shot so the console stays free),
;; then power the VM off when it finishes. Logs land on the 9p work share, or
;; stream to the host over virtio-serial when the host QEMU has no 9p.
(define libre-bootstrap (local-file "guest-bootstrap.sh"))

(define libre-build-service
  (simple-service
   'libre-build shepherd-root-service-type
   (list (shepherd-service
          (documentation "Build the GNU/Linux-libre system onto /dev/vdb.")
          (provision '(libre-build))
          (requirement '(user-processes networking file-systems))
          (respawn? #f)
          (start #~(make-forkexec-constructor
                    (list "/run/current-system/profile/bin/bash" "-c"
                          (string-append
                           "/run/current-system/profile/bin/bash "
                           #$libre-bootstrap " libre/guest-build-guix.sh; "
                           "sync; /run/current-system/profile/sbin/halt"))
                    #:log-file "/var/log/libre-build.log"))
          (stop #~(make-kill-destructor))))))

(operating-system
  (host-name "libre-builder")
  (timezone "UTC")
  (locale "en_US.utf8")
  (keyboard-layout (keyboard-layout "us"))

  ;; Headless VM (-display none -serial mon:stdio): send the console to the
  ;; serial port so boot + Shepherd messages show up in the launcher's terminal.
  (kernel-arguments (cons "console=ttyS0,115200" %default-kernel-arguments))

  (bootloader (bootloader-configuration
               (bootloader grub-bootloader)
               (targets '("/dev/vda"))))

  ;; Root by label: `guix system image -t qcow2` writes an MBR-hybrid image
  ;; (vda1 = ESP, vda2 = root labelled "Guix_image"). /mnt/repo + /mnt/work are
  ;; mounted by guest-bootstrap.sh, not here (see the header).
  (file-systems
   (cons (file-system
           (device (file-system-label "Guix_image"))
           (mount-point "/")
           (type "ext4"))
         %base-file-systems))

  ;; libre/setup builds the cross-toolchain as an unprivileged "lfs" user. It
  ;; useradd's one itself, but Guix regenerates /etc/passwd from this list at
  ;; every boot, so an imperatively added user would vanish on a resume.
  (groups (cons (user-group (name "lfs")) %base-groups))
  (users (cons (user-account
                (name "lfs")
                (group "lfs")
                (comment "LFS cross-toolchain builder")
                (home-directory "/home/lfs")
                (shell (file-append (specification->package "bash") "/bin/bash")))
               %base-user-accounts))

  (packages (append build-tools optional-tools %base-packages))

  (services (append (list libre-build-service
                          %dhcp-client-service)
                    %base-services)))
