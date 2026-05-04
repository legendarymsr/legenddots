(use-modules (gnu)
             (gnu services desktop)
             (gnu services networking)
             (gnu services security)
             (gnu services ssh)
             (gnu services virtualization))

(operating-system
  (host-name "legend-box")
  (timezone "Europe/Berlin")
  (locale "en_US.utf8")

  ;; Kernel hardening
  (kernel-arguments
   '("quiet"
     "loglevel=3"
     "slab_nomerge"
     "page_alloc.shuffle=1"
     "init_on_alloc=1"
     "init_on_free=1"
     "vsyscall=none"
     "debugfs=off"
     "lockdown=confidentiality"
     "randomize_kstack_offset=on"))

  (bootloader (bootloader-configuration
               (bootloader grub-efi-bootloader)
               (targets '("/boot/efi"))))

  (file-systems
   (cons* (file-system
           (device (file-system-label "root"))
           (mount-point "/")
           (type "ext4")
           (options "noatime,nodiratime"))
          (file-system
           (device (uuid "YOUR-EFI-UUID" 'fat))
           (mount-point "/boot/efi")
           (type "vfat"))
          %base-file-systems))

  (swap-devices
   (list (swap-space
          (target (uuid "YOUR-SWAP-UUID")))))

  (users
   (cons (user-account
          (name "legend")
          (group "users")
          (comment "Legend")
          (shell (file-append (specification->package "zsh") "/bin/zsh"))
          (home-directory "/home/legend")
          (supplementary-groups
           '("wheel" "netdev" "audio" "video" "libvirt" "wireshark" "kvm")))
         %base-user-accounts))

  (packages
   (cons* (specification->package "nss-certs")
          ;; ratpoison stack
          (specification->package "ratpoison")
          (specification->package "alacritty")
          (specification->package "dmenu")
          (specification->package "xwallpaper")
          (specification->package "xclip")
          (specification->package "maim")
          %base-packages))

  (services
   (append
    (list
     (service openssh-service-type
              (openssh-configuration
               (permit-root-login #f)
               (password-authentication? #f)
               (challenge-response-authentication? #f)
               (port-number 22)
               (extra-content "
MaxAuthTries 3
LoginGraceTime 20
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers legend")))

     (service nftables-service-type
              (nftables-configuration
               (ruleset (plain-file "nft.rules" "
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state invalid drop;
    ct state { established, related } accept;
    iif lo accept;
    ip6 nexthdr icmpv6 limit rate 10/second accept;
    ip protocol icmp limit rate 10/second accept;
    tcp dport 22 ct state new limit rate 5/minute accept;
  }
  chain forward { type filter hook forward priority 0; policy drop; }
  chain output  { type filter hook output priority 0; policy accept; }
}"))))

     (service apparmor-service-type)
     (service libvirt-service-type))

    (modify-services %desktop-services
      (guix-service-type config =>
        (guix-configuration
         (inherit config)
         (substitute-urls '("https://ci.guix.gnu.org"))))))))
