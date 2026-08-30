;; Guix — the legenddots suckless tools, each rebuilt against our own config.h.
;;
;; Use it as a manifest (installs the tools into a profile / shell):
;;     guix shell   -m suckless/config.scm
;;     guix package -m suckless/config.scm
;;
;; Or `(load ...)`-free: copy the `with-config` helper + the package defs into
;; your operating-system and add `%suckless-packages` to its (packages ...).
;;
;; suckless configs live one dir up per tool: suckless/<tool>/config.h.

(use-modules (guix packages)
             (guix gexp)
             (guix profiles)
             (gnu packages suckless)   ; st, slock, dmenu, dwm
             (gnu packages wm)         ; dwl
             (gnu packages screen)     ; screen (stock — configured via ~/.screenrc)
             (gnu packages nvi))       ; nvi   (stock — configured via ~/.exrc)

;; Rebuild BASE (a suckless package) so it compiles against CONFIG (a local-file).
;; config.def.h -> config.h only happens when config.h is absent, so dropping
;; ours in after unpack makes the build pick it up — no patch needed.
(define (with-config base new-name config)
  (package
    (inherit base)
    (name new-name)
    (arguments
     (substitute-keyword-arguments (package-arguments base)
       ((#:phases phases '%standard-phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'legend-config
              (lambda _
                (copy-file #$config "config.h")))))))))

(define st-legend    (with-config st    "st-legend"    (local-file "st/config.h")))
(define slock-legend (with-config slock "slock-legend" (local-file "slock/config.h")))
(define dmenu-legend (with-config dmenu "dmenu-legend" (local-file "dmenu/config.h")))
(define dwm-legend   (with-config dwm   "dwm-legend"   (local-file "dwm/config.h")))
(define dwl-legend   (with-config dwl   "dwl-legend"   (local-file "dwl/config.h")))

;; NOTE: surf is not packaged in Guix — build it from source (see README deps).
(define %suckless-packages
  (list st-legend slock-legend dmenu-legend dwm-legend dwl-legend))

;; screen + nvi are stock Guix packages (not rebuilt) — the dotfiles that
;; configure them (~/.screenrc, ~/.exrc) are placed by home-configuration.scm.
;; Returned value: a manifest, so this file works directly with `guix shell -m`.
(packages->manifest (append %suckless-packages (list screen nvi)))
