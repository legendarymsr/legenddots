;; Live ISO of the suckless setup on Guix: dwm (X11) with st, dmenu, slock,
;; plus dwl, all built against our config.h by ./config.scm.
;; Autologins legend on tty1 and runs startx -> dwm.
;;
;;   guix system image -t iso9660 suckless/iso.scm
;;
;; grub-mkrescue makes it hybrid: legacy BIOS (GRUB i386-pc) + UEFI.
;; Login: legend / legend.

(use-modules (gnu)
             (gnu services xorg)
             (gnu services base)
             (gnu system setuid)
             (srfi srfi-1))
(use-package-modules shells xorg xdisorg fonts)

;; Defines st-legend, slock-legend, dmenu-legend, dwm-legend, dwl-legend
;; and %suckless-packages.
(load (string-append (dirname (current-filename)) "/config.scm"))

(define xinitrc
  (plain-file "xinitrc" "exec dwm\n"))

(operating-system
  (host-name "legend-suckless")
  (timezone "Europe/Brussels")
  (locale "en_US.utf8")

  (bootloader (bootloader-configuration
               (bootloader grub-bootloader)
               (targets '("/dev/sda"))))

  (file-systems (cons (file-system
                       (device (file-system-label "Guix_image"))
                       (mount-point "/")
                       (type "ext4"))
                      %base-file-systems))

  (users (cons (user-account
                (name "legend")
                (group "users")
                (password (crypt "legend" "$6$legendiso"))
                (supplementary-groups '("wheel" "audio" "video")))
               %base-user-accounts))

  (packages (append %suckless-packages
                    (list xinit
                          font-jetbrains-mono)
                    %base-packages))

  (setuid-programs
   (cons (setuid-program (program (file-append slock-legend "/bin/slock")))
         %setuid-programs))

  (services
   (cons*
    (simple-service 'legend-xinitrc etc-service-type
                    `(("skel/.xinitrc" ,xinitrc)))
    (simple-service 'legend-startx-profile etc-service-type
                    `(("profile.d/startx.sh"
                       ,(mixed-text-file "startx.sh" "\
if [ \"$(tty)\" = /dev/tty1 ] && [ -z \"$DISPLAY\" ]; then
  [ -f ~/.xinitrc ] || cp /etc/skel/.xinitrc ~/
  exec " (xorg-start-command-xinit) "
fi
"))))
    (modify-services %base-services
      (mingetty-service-type config =>
        (if (string=? (mingetty-configuration-tty config) "tty1")
            (mingetty-configuration (inherit config) (auto-login "legend"))
            config))))))
