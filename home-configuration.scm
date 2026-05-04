(use-modules (gnu home)
             (gnu home services)
             (gnu home services shells)
             (gnu packages)
             (guix gexp))

(home-environment
  (packages
   (map specification->package
        '("git"
          "tmux"
          "htop"
          "btop"
          "ripgrep"
          "fd"
          "fzf"

          ;; security tools (libre)
          "nmap"
          "john"
          "wireshark"
          "sqlmap"
          "radare2"
          "aircrack-ng"
          "hashcat"

          ;; editor
          "emacs"
          "emacs-magit"
          "emacs-org"
          "emacs-use-package")))

  (services
   (list
    (service home-zsh-service-type
             (home-zsh-configuration
              (zshrc (list "export HISTFILE=\"$XDG_CACHE_HOME/.zsh_history\""
                           "export HISTSIZE=50000"
                           "export SAVEHIST=50000"
                           "setopt hist_ignore_dups share_history"))))

    (simple-service 'emacs-init
                    home-files-service-type
                    (list `(".emacs.d/init.el"
                            ,(plain-file "init.el" "
(setq-default indent-tabs-mode nil)
(setq tab-width 2)
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(global-display-line-numbers-mode t)
(require 'use-package)
(use-package magit)
")))))))
