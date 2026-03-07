;; Legend's Cybersec & Gentoo-inspired Guix System Config
;; Load essentials—pure FSF libre, no non-free cruft
(use-modules (gnu)
             (gnu services desktop)
             (gnu services networking)
             (gnu services security-token)
             (srfi srfi-1))  ;; For list ops

(operating-system
  (host-name "legend-box")
  (timezone "America/New_York")  ;; Adjust to your opsec locale
  (locale "en_US.utf8")

  ;; Bootloader: GRUB EFI for that libre boot flex
  (bootloader (bootloader-configuration
               (bootloader grub-efi-bootloader)
               (targets '("/boot/efi"))))

  ;; File systems: Root on ext4, EFI vfat—keep it simple, no ZFS bloat
  (file-systems (cons* (file-system
                        (device (file-system-label "my-root"))
                        (mount-point "/")
                        (type "ext4"))
                       (file-system
                        (device (uuid "1234-ABCD" 'fat))  ;; Your EFI UUID
                        (mount-point "/boot/efi")
                        (type "vfat"))
                       %base-file-systems))

  ;; Users: Legend as sudoer, zsh shell, groups for virt pivots and packet sniffs
  (users (cons (user-account
                (name "legend")
                (group "users")
                (shell (file-append (specification->package "zsh") "/bin/zsh"))
                (supplementary-groups '("wheel" "netdev" "audio" "video" "libvirt" "wireshark")))
               %base-user-accounts))

  ;; Packages: System-wide libre tools—minimal, for that ratpoison vibe
  (packages (cons* (specification->package "nss-certs")  ;; For HTTPS opsec
                   %base-packages))

  ;; Services: Desktop basics + networking, firewall, hardening
  (services (append (list (service gdm-service-type)  ;; Login manager, or slim if lighter
                          (service network-manager-service-type)
                          (service nftables-service-type  ;; Firewall: Lock it down, poke holes for exploits
                                   (nftables-configuration
                                    (ruleset (plain-file "nft.rules"
                                                         "table inet filter {
  chain input { type filter hook input priority 0; policy drop; }  ;; Deny by default
  chain forward { type filter hook forward priority 0; policy drop; }
  chain output { type filter hook output priority 0; policy accept; }
}"))))
                          (service libvirt-service-type)  ;; For qemu/kvm red team labs
                          (service fail2ban-service-type))  ;; Swat brute-forcers
                    %desktop-services)))  ;; Xorg, etc., for graphical recon