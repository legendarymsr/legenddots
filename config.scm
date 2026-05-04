(use-modules (gnu)
             (gnu services desktop)
             (gnu services networking)
             (gnu services security)
             (gnu services virtualization))

(operating-system
  (host-name "legend-box")
  (timezone "Europe/Berlin")
  (locale "en_US.utf8")

  (bootloader (bootloader-configuration
               (bootloader grub-efi-bootloader)
               (targets '("/boot/efi"))))

  (file-systems (cons* (file-system
                        (device (file-system-label "root"))
                        (mount-point "/")
                        (type "ext4"))
                       (file-system
                        (device (uuid "YOUR-EFI-UUID" 'fat))
                        (mount-point "/boot/efi")
                        (type "vfat"))
                       %base-file-systems))

  (users (cons (user-account
                (name "legend")
                (group "users")
                (shell (file-append (specification->package "zsh") "/bin/zsh"))
                (supplementary-groups '("wheel" "netdev" "audio" "video" "libvirt" "wireshark")))
               %base-user-accounts))

  (packages (cons* (specification->package "nss-certs")
                   %base-packages))

  (services
   (append
    (list
     (service nftables-service-type
              (nftables-configuration
               (ruleset (plain-file "nft.rules" "
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state { established, related } accept;
    iif lo accept;
    ip6 nexthdr icmpv6 accept;
    ip protocol icmp accept;
  }
  chain forward { type filter hook forward priority 0; policy drop; }
  chain output  { type filter hook output priority 0; policy accept; }
}"))))
     (service apparmor-service-type)
     (service libvirt-service-type))
    %desktop-services)))
