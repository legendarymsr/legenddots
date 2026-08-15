;; -*- mode: elisp; lexical-binding: t -*-
;; LegendOS Bunker: Red Team Edition v5.0 — GPL-3.0
;;
;; This configuration is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; LegendOS Bunker: A Fortress of Digital Freedom
;; Freedom is not granted — it is taken and defended.
;; Software belongs to its users, not corporations.
;; If you use or modify this code, you must keep it free for all.
;; The GNU Project lit the fire in 1985. We keep it burning.
;; — Legend

;; --- CHANGE THIS TO YOUR ACTUAL OBSIDIAN VAULT PATH ---
(setq obsidian-vault-path "\~/Obsidian")  ;; ← EDIT THIS LINE

;; --- 0. PRELIMINARIES ---
(setq inhibit-startup-message t)

(if (display-graphic-p)
    (progn
      (menu-bar-mode -1)
      (tool-bar-mode -1)
      (scroll-bar-mode -1)
      (fringe-mode 0))
  (menu-bar-mode -1))

(setq display-line-numbers-type 'relative)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'text-mode-hook #'display-line-numbers-mode)

(setq-default indent-tabs-mode nil)
(setq-default tab-width 2)

;; --- 1. PACKAGE MANAGEMENT + Termux fix ---
(require 'package)
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("gnu" . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")))

(setq gnutls-algorithm-priority "NORMAL:-VERS-TLS1.3")

(package-initialize)
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(eval-when-compile (require 'use-package))
(setq use-package-always-ensure t)

;; --- 2. EVIL MODE ---
(use-package evil
  :init
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  :config
  (evil-mode 1))

(use-package evil-collection
  :after evil
  :config
  (evil-collection-init))

;; --- 3. SPC LEADER KEY ---
(use-package general
  :config
  (general-evil-setup t)
  (general-create-definer leader
    :states '(normal visual insert emacs)
    :prefix "SPC"
    :non-normal-prefix "C-SPC")

  (leader
    "SPC" '(execute-extended-command :which-key "M-x")
    "ff"  '(find-file :which-key "Find file")
    "bb"  '(consult-buffer :which-key "Buffers")
    "gg"  '(magit-status :which-key "Magit")
    "tt"  '(eshell :which-key "Open terminal")
    "bn"  '(centaur-tabs-forward :which-key "Next tab")
    "bp"  '(centaur-tabs-backward :which-key "Prev tab")
    "/"   '(consult-ripgrep :which-key "Search project (rg)")
    "sb"  '(consult-line :which-key "Search buffer")
    "fr"  '(consult-recent-file :which-key "Recent files")
    "ou"  '((lambda () (interactive) (eww "https://www.gnu.org/software/emacs/")) :which-key "GNU Emacs website")
    "vv"  '((lambda () (interactive) (dired obsidian-vault-path)) :which-key "Open Obsidian vault")
    "hm"  '(man :which-key "man page")
    "hi"  '(info :which-key "Info reader")
    "ss"  '(legend-show-splash :which-key "Show splash")))

;; --- 4. BASIC COMPLETION ---
(use-package vertico
  :init (vertico-mode)
  :config (setq vertico-cycle t))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package marginalia
  :init (marginalia-mode))

;; --- 5. MAGIT + AUTO-GIT COMMIT ---
(use-package magit
  :bind ("C-x g" . magit-status))

(defun legend-auto-git-commit ()
  (when (and (buffer-file-name)
             (or (string-prefix-p (expand-file-name "\~/org") (buffer-file-name))
                 (string-prefix-p (expand-file-name obsidian-vault-path) (buffer-file-name))))
    (let ((default-directory (file-name-directory (buffer-file-name))))
      (shell-command "git add . && git commit -m \"auto: save $(date +%Y-%m-%d_%H-%M-%S)\" 2>/dev/null"))))

(add-hook 'after-save-hook #'legend-auto-git-commit)

;; --- 6. THEME + MODELINE ---
;; doom-tokyo-night = the same Tokyo Night "night" palette neovim uses
;; (folke/tokyonight, style "night") — bg #1a1b26, so the two editors match.
(use-package doom-themes
  :config
  (setq doom-themes-enable-bold t doom-themes-enable-italic t)
  (load-theme 'doom-tokyo-night t)
  (doom-themes-org-config))

(use-package doom-modeline
  :init (doom-modeline-mode 1))

(use-package which-key
  :init (which-key-mode)
  :config (setq which-key-idle-delay 0.3))

;; --- 7. BACKUPS & ESHELL ---
(setq backup-directory-alist `(("." . ,(expand-file-name "backups" user-emacs-directory))))
(setq auto-save-file-name-transforms `((".*" ,(expand-file-name "auto-save" user-emacs-directory) t)))

(make-directory (expand-file-name "backups" user-emacs-directory) t)
(make-directory (expand-file-name "auto-save" user-emacs-directory) t)

(add-hook 'eshell-mode-hook (lambda () (evil-normal-state)))

;; --- 8. SEXY TOKYO NIGHT CENTERED DASHBOARD (forced colors) ---
(defun legend-dismiss-splash ()
  "Dismiss splash and return to work."
  (interactive)
  (kill-buffer "*LegendOS Splash*")
  (switch-to-buffer (or (other-buffer) "*scratch*")))

(defun legend-show-splash ()
  "Sexy centered Tokyo Night dashboard."
  (interactive)
  (let ((splash (get-buffer-create "*LegendOS Splash*")))
    (with-current-buffer splash
      (read-only-mode -1)
      (erase-buffer)
      ;; Force Tokyo Night colors
      (set-face-attribute 'default nil :background "#1a1b26" :foreground "#c0caf5")
      (set-face-attribute 'header-line nil :background "#1a1b26" :foreground "#7dcfff")
      (set-face-attribute 'region nil :background "#292e42" :foreground "#c0caf5")

      (insert "\n\n")
      (insert "                           Legend Emacs\n\n")
      (insert "             Emacs: 30.2 | OS: gnu/linux | User: legend\n")
      (insert (format "             Startup: %s seconds\n" (emacs-init-time)))
      (insert (format "             Time: %s\n" (format-time-string "%Y-%m-%d %H:%M")))
      (insert (format "             Packages: %d\n\n" (length package-activated-list)))

      (insert "╔════════════════════════════════════════════════════════════╗\n")
      (insert "║               2-Letter Clicks (Spacebar + keys)            ║\n")
      (insert "╠════════════════════════════════════════════════════════════╣\n")
      (insert "║  ff: Find File         rr: Recent Files                    ║\n")
      (insert "║  bb: Board             gg: Magit                           ║\n")
      (insert "║  tt: Terminal          ou: GNU Emacs site                  ║\n")
      (insert "║  vv: Obsidian Vault    ss: Show splash                     ║\n")
      (insert "╚════════════════════════════════════════════════════════════╝\n\n")

      (insert "Freedom is not granted — it is taken and defended.\n")
      (insert "Libre software gives you the four essential freedoms:\n")
      (insert "  • To run the program as you wish\n")
      (insert "  • To study and change it\n")
      (insert "  • To redistribute copies\n")
      (insert "  • To improve and release improvements\n\n")
      (insert "In the red team arena, this is your ultimate weapon.\n")
      (insert "You control the code, the exfil paths, the C2, the keys.\n")
      (insert "No backdoors. No telemetry. No corporate overlords.\n")
      (insert "True cybersecurity begins with owning the stack.\n")
      (insert "This bunker runs on GNU principles — and it will stay free.\n\n")

      (insert "Press q to dismiss | SPC ss to summon again\n")
      (special-mode)
      (read-only-mode 1)
      (local-set-key (kbd "q") #'legend-dismiss-splash))
    (switch-to-buffer splash)))

;; Auto-show on startup
(add-hook 'emacs-startup-hook #'legend-show-splash)

;; --- 9. STARTUP MESSAGE ---
(add-hook 'emacs-startup-hook
          (lambda ()
            (message "LegendOS Bunker Online v5.0 — GPL-3.0 & Free")))

;; --- 10. GUI-LIKE TUI EYE CANDY ---
;; Make TERMINAL emacs feel like a graphical IDE — no GUI/EXWM, everything below
;; renders in the terminal. Icons need a Nerd Font in the terminal, which this
;; system has (JetBrainsMono Nerd Font in alacritty). Same spirit as init.lua.

;; Icons everywhere (terminal, via the Nerd Font)
(use-package nerd-icons)
(use-package nerd-icons-completion
  :after (marginalia nerd-icons)
  :config
  (nerd-icons-completion-mode)
  (add-hook 'marginalia-mode-hook #'nerd-icons-completion-marginalia-setup))
(use-package nerd-icons-dired
  :hook (dired-mode . nerd-icons-dired-mode))
(setq doom-modeline-icon t)   ; icons in the modeline too

;; GUI-style buffer tabs across the top (renders as text tabs in the terminal)
(use-package centaur-tabs
  :demand t
  :config
  (setq centaur-tabs-style "bar"
        centaur-tabs-height 28
        centaur-tabs-set-icons t
        centaur-tabs-icon-type 'nerd-icons
        centaur-tabs-set-bar 'left
        centaur-tabs-set-modified-marker t
        centaur-tabs-modified-marker "●")
  (centaur-tabs-mode t))

;; In-buffer completion popup (IDE-style), rendered in the terminal by corfu-terminal
(use-package corfu
  :init
  (setq corfu-auto t corfu-auto-delay 0.15 corfu-auto-prefix 2 corfu-cycle t)
  (global-corfu-mode))
(use-package corfu-terminal
  :after corfu
  :config (unless (display-graphic-p) (corfu-terminal-mode +1)))
(use-package nerd-icons-corfu
  :after (corfu nerd-icons)
  :config (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))
(use-package cape
  :init
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  (add-to-list 'completion-at-point-functions #'cape-file))

;; Command palette / better search — vertico (minibuffer) is already loaded above;
;; consult adds the "fuzzy everything" commands (bound under SPC / , SPC sb , …).
(use-package consult)
(use-package embark
  :bind (("C-." . embark-act)))
(use-package embark-consult :after (embark consult))

;; Git gutter — margin mode, because fringes are graphical-only
(use-package diff-hl
  :hook ((prog-mode . diff-hl-mode)
         (dired-mode . diff-hl-dired-mode))
  :config
  (unless (display-graphic-p) (diff-hl-margin-mode 1))
  (diff-hl-flydiff-mode 1))

;; Indentation guides (character-based so they show in the terminal)
(use-package indent-bars
  :hook (prog-mode . indent-bars-mode)
  :config (setq indent-bars-prefer-character t))

;; Colored nested brackets
(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

;; Nicer, navigable help buffers
(use-package helpful
  :bind (("C-h f" . helpful-callable)
         ("C-h v" . helpful-variable)
         ("C-h k" . helpful-key)))

;; Built-in polish: highlight the current line + show column in the modeline
(global-hl-line-mode 1)
(column-number-mode 1)