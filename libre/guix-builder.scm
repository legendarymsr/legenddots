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
;;   - two 9p mounts: /mnt/repo (this repo, ro) and /mnt/work (rw scratch),
;;   - a DHCP client (libre/setup downloads sources, so it needs network),
;;   - a Shepherd service that runs libre/guest-build-guix.sh at boot and halts.
;;
;; Build an image from it with:  guix system image -t qcow2 guix-builder.scm
;; (libre/run-vm-guix.sh does that for you.)
;;
;; NOTE: this has NOT been run through `guix system image` here — no Guix in the
;; build sandbox. Module/package names and the root file-system device may need
;; a tweak on your Guix (you run Guix, so you've got this). The Debian builder in
;; run-vm.sh is the tested-path fallback.
;; =============================================================================

(use-modules (gnu)
             (gnu packages)
             (gnu services shepherd))
(use-service-modules base networking)

;; LFS host requirements, resolved by name so we don't chase module imports.
(define build-tools
  (map specification->package
       '("gcc-toolchain" "make" "bison" "m4" "texinfo"
         "parted" "dosfstools" "e2fsprogs" "util-linux"
         "perl" "python" "wget" "git" "sed" "tar"
         "gzip" "xz" "bzip2" "patch" "diffutils" "findutils" "grep"
         "gawk" "coreutils" "pkg-config" "file" "gettext"
         "which" "binutils" "bash" "guix")))

;; Run the build at boot (backgrounded, not one-shot so the console stays free),
;; then power the VM off when it finishes. Logs land on the 9p work share.
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
                           "bash /mnt/repo/libre/guest-build-guix.sh "
                           ">>/mnt/work/build.log 2>&1; "
                           "echo EXIT=$? >>/mnt/work/build.log; sync; "
                           "/run/current-system/profile/sbin/halt -p"))
                    #:log-file "/mnt/work/shepherd-build.log"))
          (stop #~(make-kill-destructor))))))

(operating-system
  (host-name "libre-builder")
  (timezone "UTC")
  (locale "en_US.utf8")
  (keyboard-layout (keyboard-layout "us"))

  (bootloader (bootloader-configuration
               (bootloader grub-bootloader)
               (targets '("/dev/vda"))))

  (file-systems
   (append
    (list (file-system (device "/dev/vda1") (mount-point "/") (type "ext4"))
          ;; this git repo, read-only
          (file-system (device "repo") (mount-point "/mnt/repo") (type "9p")
                       (flags '(read-only))
                       (options "trans=virtio,version=9p2000.L")
                       (mount? #t) (check? #f))
          ;; rw scratch: build.log + done marker go here
          (file-system (device "work") (mount-point "/mnt/work") (type "9p")
                       (options "trans=virtio,version=9p2000.L")
                       (mount? #t) (check? #f)))
    %base-file-systems))

  (packages (append build-tools %base-packages))

  (services (append (list libre-build-service
                          (service dhcp-client-service-type))
                    %base-services)))
