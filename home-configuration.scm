(use-modules (gnu home)
             (gnu home services)
             (gnu home services shells)
             (gnu packages)
             (guix gexp))

(home-environment
  (packages
   (map specification->package
        '(;; essentials
          "git"
          "tmux"
          "htop"
          "btop"
          "ripgrep"
          "fd"
          "fzf"
          "curl"
          "wget"
          "tree"

          ;; security tools (libre only)
          "nmap"
          "john"
          "wireshark"
          "sqlmap"
          "radare2"
          "aircrack-ng"
          "hashcat"
          "tcpdump"
          "netcat"

          ;; ratpoison utilities
          "xterm"
          "xdotool"
          "scrot"
          "xsetroot"
          "font-jetbrains-mono"

          ;; browser
          "icecat"
          "slock"

          ;; emacs
          "emacs"
          "emacs-magit"
          "emacs-org"
          "emacs-use-package"
          "emacs-evil"
          "emacs-which-key"
          "emacs-company")))

  (services
   (list
    ;; ── Environment ────────────────────────────────────────────────────────
    (service home-environment-variables-service-type
             '(("EDITOR"          . "emacs")
               ("VISUAL"          . "emacs")
               ("PAGER"           . "less")
               ("LESS"            . "-R --mouse")
               ("XDG_CACHE_HOME"  . "$HOME/.cache")
               ("XDG_CONFIG_HOME" . "$HOME/.config")
               ("XDG_DATA_HOME"   . "$HOME/.local/share")
               ("PATH"            . "$HOME/.local/bin:$HOME/bin:$HOME/.guix-profile/bin:$PATH")))

    ;; ── Zsh ────────────────────────────────────────────────────────────────
    (service home-zsh-service-type
             (home-zsh-configuration
              (zshenv
               (list "export ZDOTDIR=\"$HOME/.config/zsh\""))
              (zshrc
               (list "
# history
export HISTFILE=\"$XDG_CACHE_HOME/.zsh_history\"
export HISTSIZE=100000
export SAVEHIST=100000
setopt hist_ignore_all_dups hist_ignore_space share_history inc_append_history

# options
setopt auto_cd correct interactive_comments extended_glob

# prompt
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats ' (%b)'
setopt prompt_subst
PROMPT='%F{#7aa2f7}%n%f@%F{#bb9af7}%m%f %F{#9ece6a}%~%f%F{#e0af68}${vcs_info_msg_0_}%f %F{#7aa2f7}»%f '

# completion
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# aliases
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias grep='grep --color=auto'
alias ip='ip --color=auto'
alias diff='diff --color=auto'
alias q='exit'
alias e='emacs'
alias g='git'
alias t='tmux'

# git shortcuts
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gst='git status'
alias gd='git diff'
alias gl='git log --oneline --graph'

# security shortcuts
alias myip='curl -s ifconfig.me'
alias ports='ss -tuln'
alias pst='ps aux | grep'
"))))

    ;; ── Ratpoison ──────────────────────────────────────────────────────────
    (simple-service 'ratpoison-config
                    home-files-service-type
                    (list
                     `(".ratpoisonrc"
                       ,(plain-file "ratpoisonrc" "
# prefix key
escape C-t

# appearance (Tokyo Night)
set border 2
set barinpadding 4
set bargravity NE
set fgcolor #c0caf5
set bgcolor #1a1b26
set selectioncolor #7aa2f7
set font -misc-fixed-medium-r-normal--14-130-75-75-c-70-iso10646-1

# padding
set padding 0 0 0 0

# terminal
bind c exec alacritty
bind C-c exec alacritty
bind x exec xterm

# launcher
bind d exec dmenu_run -fn 'monospace-11' -nb '#1a1b26' -nf '#c0caf5' -sb '#7aa2f7' -sf '#1a1b26'

# apps
bind e exec emacs
bind b exec icecat

# focus
bind h focusleft
bind l focusright
bind k focusup
bind j focusdown
bind n focusnext
bind p focusprev
bind Tab focusnext

# move window
bind H exchangeleft
bind L exchangeright
bind K exchangeup
bind J exchangedown

# workspaces (groups)
bind 1 gselect 1
bind 2 gselect 2
bind 3 gselect 3
bind 4 gselect 4
bind 5 gselect 5
bind 6 gselect 6
bind 7 gselect 7
bind 8 gselect 8
bind 9 gselect 9

# move window to group
bind ! gmove 1
bind @ gmove 2
bind # gmove 3
bind $ gmove 4
bind % gmove 5
bind ^ gmove 6
bind & gmove 7
bind * gmove 8
bind ( gmove 9

# lock screen
bind Escape exec slock

# splits
bind s hsplit
bind S vsplit
bind r remove
bind R ratrestart
bind Q quit
bind q delete
bind K kill

# resize
bind Left resize -w 50
bind Right resize +w 50
bind Up resize -h 50
bind Down resize +h 50

# screenshot
bind Print exec scrot '%Y-%m-%d-%H%M%S.png' -e 'mv $f ~/Pictures/'

# startup
exec xsetroot -solid '#1a1b26'
exec emacs --daemon
"))))

    ;; ── .xinitrc ───────────────────────────────────────────────────────────
    (simple-service 'xinitrc
                    home-files-service-type
                    (list
                     `(".xinitrc"
                       ,(plain-file "xinitrc" "
#!/bin/sh
xsetroot -cursor_name left_ptr
[ -f ~/.Xresources ] && xrdb ~/.Xresources
exec ratpoison
"))))

    ;; ── Xresources (Tokyo Night) ───────────────────────────────────────────
    (simple-service 'xresources
                    home-files-service-type
                    (list
                     `(".Xresources"
                       ,(plain-file "Xresources" "
! Tokyo Night
*foreground:  #c0caf5
*background:  #1a1b26
*cursorColor: #c0caf5

*color0:  #15161e
*color1:  #f7768e
*color2:  #9ece6a
*color3:  #e0af68
*color4:  #7aa2f7
*color5:  #bb9af7
*color6:  #7dcfff
*color7:  #a9b1d6
*color8:  #414868
*color9:  #f7768e
*color10: #9ece6a
*color11: #e0af68
*color12: #7aa2f7
*color13: #bb9af7
*color14: #7dcfff
*color15: #c0caf5

! XTerm
XTerm*faceName: JetBrainsMono Nerd Font
XTerm*faceSize: 11
XTerm*scrollBar: false
XTerm*saveLines: 10000
XTerm*borderWidth: 0
XTerm*internalBorder: 8
"))))

    ;; ── Emacs ──────────────────────────────────────────────────────────────
    (simple-service 'emacs-init
                    home-files-service-type
                    (list
                     `(".emacs.d/init.el"
                       ,(plain-file "init.el" "
;; ui
(setq inhibit-startup-message t)
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(global-display-line-numbers-mode t)
(setq display-line-numbers-type 'relative)
(set-face-attribute 'default nil :font \"JetBrainsMono Nerd Font\" :height 110)

;; editing
(setq-default indent-tabs-mode nil)
(setq tab-width 2)
(setq make-backup-files nil)
(setq auto-save-default nil)
(electric-pair-mode t)

;; packages
(require 'use-package)

(use-package evil
  :init (setq evil-want-keybinding nil)
  :config (evil-mode 1))

(use-package which-key
  :config (which-key-mode))

(use-package company
  :hook (after-init . global-company-mode))

(use-package magit
  :bind (\"C-c g\" . magit-status))

(use-package org
  :config
  (setq org-startup-indented t)
  (setq org-hide-leading-stars t))
")))))))
