;; Guix Home — install the legenddots suckless tools into your user profile,
;; each rebuilt against our own config.h.
;;
;;     guix home reconfigure suckless/home-configuration.scm
;;
;; This is a standalone home-environment for just the suckless tools; to fold
;; them into an existing one, lift `%suckless-packages` into its (packages ...).
;; suckless configs live one dir up per tool: suckless/<tool>/config.h.

(use-modules (gnu home)
             (gnu home services)
             (guix packages)
             (guix gexp)
             (gnu packages suckless)   ; st, slock, dmenu, dwm
             (gnu packages wm))        ; dwl

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

;; surf is not packaged in Guix — build from source (see README deps).
(define %suckless-packages
  (list st-legend slock-legend dmenu-legend dwm-legend dwl-legend))

(home-environment
  (packages %suckless-packages))
