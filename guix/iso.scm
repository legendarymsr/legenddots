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
             (gnu services guix)          ; guix-home-service-type
             (srfi srfi-1))

(define here (dirname (current-filename)))
(define legend-os (load (string-append here "/config.scm")))
;; legend's Guix Home (IceCat, Emacs, zsh, CLI/pentest tools, dotfiles),
;; activated for legend at boot so the live system matches an installed one.
(define legend-home (load (string-append here "/home-configuration.scm")))

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
  ;; installed machine. Also drop config.scm's tmpfs /tmp: with it the live
  ;; system hangs right after SSH host-key generation and never reaches a
  ;; login (bisected in QEMU; openssh/nftables/fail2ban/libvirt/GDM and the
  ;; hardening kernel args are not the cause). /tmp stays on the live root.
  ;; (The "init[1]: segfault … in guile" line is the initrd's static Guile and
  ;; harmless; the suckless ISO prints it too.)
  (file-systems
   (cons* (file-system
           (device (file-system-label "Guix_image"))
           (mount-point "/")
           (type "ext4"))
          %base-file-systems))
  (swap-devices '())

  (services
   (cons (service guix-home-service-type `(("legend" ,legend-home)))
         (operating-system-user-services legend-os)))

  (users
   (map (lambda (user)
          (if (string=? (user-account-name user) "legend")
              (user-account
               (inherit user)
               (password (crypt "legend" "$6$legendiso")))
              user))
        (operating-system-users legend-os))))
