;; Legend's Emacs Bunker: Red Team Edition v2.0
;; Now with LSP sorcery—dissect code like gdb on a core dump
;; Sections for modularity: Load 'em like modules in a Nix flake

;; --- 0. Preliminaries: Purge bloat, set fonts ---
(menu-bar-mode -1)                ;; No menu cruft
(tool-bar-mode -1)                ;; Toolbars for normies
(scroll-bar-mode -1)              ;; Scroll like a pro, not a rodent
(fringe-mode 0)                   ;; Trim fringes like /etc/shadow
(set-face-attribute 'default nil :font "JetBrains Mono" :height 120) ;; Nerd font zen

;; Basics: Line numbers like :set nu relativenumber
(global-display-line-numbers-mode t)
(setq display-line-numbers-type 'relative)

;; Indentation: 2 spaces, no tabs—clean as a chroot
(setq-default indent-tabs-mode nil)
(setq tab-width 2)

;; --- 1. Package Management: Use-package as your pacman -S ---
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))
(require 'use-package)
(setq use-package-always-ensure t) ;; Auto-install like yay

;; --- 2. Completion & Lint: Company and Flycheck foundation ---
(use-package company
  :hook (after-init . global-company-mode)) ;; Autocomplete like CoC

(use-package flycheck
  :init (global-flycheck-mode)) ;; Lint on the fly, ALE vibes

;; --- 3. LSP Core: The red team analyzer implant ---
(use-package lsp-mode
  :init
  (setq lsp-keymap-prefix "C-c l") ;; Prefix like i3 mod+l
  :hook
  ((lsp-mode . lsp-enable-which-key-integration)) ;; Key hints for noobs
  :commands (lsp lsp-deferred)
  :config
  (setq lsp-auto-guess-root t) ;; Auto-detect projects like projectile
  (setq lsp-log-io nil) ;; Quiet logs, opsec first
  ;; Hook to modes: Add your langs here, e.g., for Python/Rust
  (add-hook 'python-mode-hook 'lsp-deferred)
  (add-hook 'rust-mode-hook 'lsp-deferred)
  ;; More hooks as needed—modular AF
  )

;; LSP UI: Popups for diagnostics, like Neovim's floating windows
(use-package lsp-ui
  :after lsp-mode
  :config
  (setq lsp-ui-doc-enable t) ;; Hover docs
  (setq lsp-ui-sideline-enable t) ;; Sideline hints
  (setq lsp-ui-flycheck-enable t)) ;; Integrate with flycheck

;; --- 4. Git & Projects: Magit and Projectile for repo recon ---
(use-package magit
  :bind ("C-x g" . magit-status)) ;; Git like lazygit

(use-package projectile
  :config (projectile-mode +1)
  :bind-keymap ("C-c p" . projectile-command-map))

;; --- 5. File Navigation: Treemacs for / traversal ---
(use-package treemacs
  :bind ("C-x t t" . treemacs))

;; --- 6. Org-mode: Op logs encrypted for deniability ---
(use-package org
  :config
  (setq org-agenda-files '("\~/ops.org"))
  (setq org-startup-indented t))

;; --- 7. Evil-mode: Vim refugee kit—because old habits die hard ---
(use-package evil
  :init
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  :config (evil-mode 1))

(use-package evil-collection
  :after evil
  :config (evil-collection-init))

;; --- 8. Theme: Doom-one for dark mode cybersecurity aesthetic ---
(use-package doom-themes
  :config (load-theme 'doom-one t))

;; --- 9. Custom Hacks: Auto-save and shell tweaks ---
(setq auto-save-default t)
(setq backup-directory-alist '(("." . "\~/.emacs.d/backups")))

(add-hook 'eshell-mode-hook (lambda () (evil-normal-state))) ;; Vim in eshell

;; --- 10. Startup Hook: Motd like a red team banner ---
(add-hook 'emacs-startup-hook
          (lambda () (message "Emacs bunker LSP-pwned. M-x lsp-install-server for lang servers.")))

;; Pro tip: For ultimate modularity, split sections into files like \~/.emacs.d/lsp.el
;; Then (load "\~/.emacs.d/lsp.el") here—chroot your config like /etc/modules!