;; Legend's Guix Home Config: Emacs Fortress Edition
(use-modules (gnu home)
             (gnu home services)
             (gnu home services shells)
             (gnu services)
             (gnu packages admin)
             (gnu packages emacs)
             (gnu packages emacs-xyz)  ;; For extensions
             (guix gexp))

(home-environment
  (user "legend")

  ;; Packages: Libre red team arsenal + essentials—no non-free spies
  (packages (list (specification->package "git")
                  (specification->package "tmux")
                  (specification->package "htop")
                  (specification->package "btop")
                  (specification->package "ripgrep")
                  (specification->package "fd")
                  (specification->package "fzf")
                  (specification->package "nmap")
                  (specification->package "hashcat")
                  (specification->package "john")  ;; john-the-ripper
                  (specification->package "wireshark")
                  (specification->package "ghidra")
                  (specification->package "sqlmap")
                  (specification->package "ffuf")
                  (specification->package "radare2")
                  (specification->package "bettercap")
                  (specification->package "aircrack-ng")
                  (specification->package "responder")  ;; python-responder
                  (specification->package "android-udev-rules")  ;; For adb pivots
                  (specification->package "emacs")))  ;; The one true editor

  ;; Services: ZSH config + Emacs service for that M-x zen
  (services
   (list (service home-zsh-service-type
                  (home-zsh-configuration
                   (zshrc (list "export HISTFILE=\"$XDG_CACHE_HOME\"/.zsh_history"
                                "export HISTSIZE=50000"))))
         (service home-emacs-service-type
                  (home-emacs-configuration
                   (emacs-packages (list (specification->package "emacs-magit")  ;; Git fu
                                         (specification->package "emacs-org")  ;; Notes for op logs
                                         (specification->package "emacs-use-package")))  ;; For extensions
                   (init-el `(;; Basic Emacs tweaks—like vim, but better ;)
                              (setq-default indent-tabs-mode nil)
                              (setq tab-width 2)
                              (menu-bar-mode -1)
                              (tool-bar-mode -1)
                              (scroll-bar-mode -1)
                              (global-display-line-numbers-mode t)
                              (use-package magit
                                :ensure t)
                              ;; Add more M-x redpills here
                              ))))))
