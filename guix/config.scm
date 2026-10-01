(use-modules (gnu)
             (gnu services desktop)
             (gnu services networking)
             (gnu services security)
             (gnu services ssh)
             (gnu services virtualization)
             (gnu packages suckless)      ; st, slock, dmenu
             (gnu system setuid)          ; setuid slock so it can lock
             (guix packages)              ; package / inherit
             (guix gexp))                 ; local-file, gexps

;; st (suckless terminal) built from our custom, trimmed config.h
;; (suckless/st/config.h): Tokyo Night, JetBrains Mono, no F13–F35, no keypad,
;; no mouse shortcuts. config.def.h -> config.h happens only if config.h is
;; absent, so dropping ours in before the build makes st compile against it.
(define st-tokyonight
  (package
    (inherit st)
    (name "st-tokyonight")
    (arguments
     (substitute-keyword-arguments (package-arguments st)
       ((#:phases phases '%standard-phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'legend-config
              (lambda _
                (copy-file #$(local-file "../suckless/st/config.h") "config.h")))))))))

;; slock (screen locker) with our Tokyo Night lock colors baked in.
(define slock-tokyonight
  (package
    (inherit slock)
    (name "slock-tokyonight")
    (arguments
     (substitute-keyword-arguments (package-arguments slock)
       ((#:phases phases '%standard-phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'legend-config
              (lambda _
                (copy-file #$(local-file "../suckless/slock/config.h") "config.h")))))))))

;; dmenu (launcher) with our Tokyo Night colors + font baked in.
(define dmenu-tokyonight
  (package
    (inherit dmenu)
    (name "dmenu-tokyonight")
    (arguments
     (substitute-keyword-arguments (package-arguments dmenu)
       ((#:phases phases '%standard-phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'legend-config
              (lambda _
                (copy-file #$(local-file "../suckless/dmenu/config.h") "config.h")))))))))

(operating-system
  (host-name "legend-box")
  (timezone "Europe/Brussels")
  (locale "en_US.utf8")

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
          (file-system
           (device (file-system-label "home"))
           (mount-point "/home")
           (type "ext4")
           (options "noatime,noexec,nosuid"))
          (file-system
           (device (file-system-label "data"))
           (mount-point "/data")
           (type "ext4")
           (options "noatime,nodiratime,noexec"))
          (file-system
           (device "none")
           (mount-point "/tmp")
           (type "tmpfs")
           (check? #f)
           (options "mode=1777,noexec,nosuid,nodev,size=2G"))
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

  ;; X desktop: ratpoison WM + st terminal (custom build) + slock lock + dmenu.
  (packages
   (cons* (specification->package "nss-certs")
          (specification->package "ratpoison")
          st-tokyonight                          ; st + suckless/st/config.h
          slock-tokyonight                       ; screen locker (setuid below)
          dmenu-tokyonight                        ; launcher (ratpoison `bind d`)
          (specification->package "xdotool")
          (specification->package "scrot")
          (specification->package "xsetroot")
          (specification->package "xwallpaper")
          (specification->package "xclip")
          (specification->package "maim")
          (specification->package "font-jetbrains-mono")
          %base-packages))

  ;; slock must be setuid-root to authenticate on unlock.
  (setuid-programs
   (cons (setuid-program (program (file-append slock-tokyonight "/bin/slock")))
         %setuid-programs))

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
AllowUsers legend
KexAlgorithms curve25519-sha256
Ciphers chacha20-poly1305@openssh.com
MACs hmac-sha2-512-etm@openssh.com")))

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

     (service fail2ban-service-type)
     (service apparmor-service-type)
     (service libvirt-service-type))

    (modify-services %desktop-services
      (guix-service-type config =>
        (guix-configuration
         (inherit config)
         (substitute-urls '("https://ci.guix.gnu.org"
                            "https://bordeaux.guix.gnu.org"))))))))
