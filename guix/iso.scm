;; Live ISO of the main Guix setup (config.scm: ratpoison + st/slock/dmenu,
;; IceCat, hardening). Build:
;;
;;   guix system image -t iso9660 guix/iso.scm
;;
;; The iso9660 image is made with grub-mkrescue, so it's hybrid: it boots on
;; legacy BIOS (GRUB i386-pc / El Torito) and UEFI, from a DVD or dd'd to USB.
;; Log in as legend (password "legend") or root (no password).

(use-modules (gnu)
             (gnu system)
             (gnu system file-systems)
             (srfi srfi-1))

(define legend-os
  (load (string-append (dirname (current-filename)) "/config.scm")))

(operating-system
  (inherit legend-os)
  (host-name "legend-iso")

  ;; Legacy BIOS GRUB; `guix system image` swaps in grub-mkrescue's hybrid
  ;; BIOS+UEFI boot for the ISO itself.
  (bootloader (bootloader-configuration
               (bootloader grub-bootloader)
               (targets '("/dev/sda"))))

  ;; No "quiet": show the kernel booting. Drop lockdown so the live system
  ;; doesn't fight with whatever hardware it lands on.
  (kernel-arguments
   (remove (lambda (arg)
             (member arg '("quiet" "lockdown=confidentiality")))
           (operating-system-user-kernel-arguments legend-os)))

  ;; The image builder provides the root file system; drop the labelled
  ;; /home, /data and EFI partitions and the swap that only exist on the
  ;; installed machine. Keep the tmpfs /tmp.
  (file-systems
   (cons* (file-system
           (device (file-system-label "Guix_image"))
           (mount-point "/")
           (type "ext4"))
          (filter (lambda (fs)
                    (string=? (file-system-mount-point fs) "/tmp"))
                  (operating-system-file-systems legend-os))))
  (swap-devices '())

  (users
   (map (lambda (user)
          (if (string=? (user-account-name user) "legend")
              (user-account
               (inherit user)
               (password (crypt "legend" "$6$legendiso")))
              user))
        (operating-system-users legend-os))))
