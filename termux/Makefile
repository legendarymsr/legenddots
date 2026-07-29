# pocketwl — build against Termux's native wlroots.
#
# wlroots' own <wlr/types/wlr_xdg_shell.h> does #include "xdg-shell-protocol.h",
# a header that is NOT shipped — every downstream compositor must generate it
# from the xdg-shell protocol XML with wayland-scanner. So we do that here and
# put it on the include path (-I.), exactly like upstream tinywl's Makefile.
#
# wlroots has no stable API and a versioned pkg-config name (wlroots-0.18, ...);
# discover the actual installed name rather than guessing the suffix.
WLROOTS := $(shell pkg-config --list-all 2>/dev/null | awk '/^wlroots/{print $$1; exit}')
PKGS = $(WLROOTS) wayland-server xkbcommon

# wayland-scanner: prefer the pkg-config variable, fall back to $PATH.
WAYLAND_SCANNER := $(shell pkg-config --variable=wayland_scanner wayland-scanner 2>/dev/null)
ifeq ($(WAYLAND_SCANNER),)
WAYLAND_SCANNER := $(shell command -v wayland-scanner)
endif
# Protocol XML dir: pkg-config var, else Termux's default share path.
WAYLAND_PROTOCOLS := $(shell pkg-config --variable=pkgdatadir wayland-protocols 2>/dev/null)
ifeq ($(WAYLAND_PROTOCOLS),)
WAYLAND_PROTOCOLS := $(PREFIX)/share/wayland-protocols
endif
XDG_SHELL_XML := $(WAYLAND_PROTOCOLS)/stable/xdg-shell/xdg-shell.xml

CFLAGS  += -DWLR_USE_UNSTABLE -std=c11 -Wall -Wextra -Wno-unused-parameter -g -I.
CFLAGS  += $(shell pkg-config --cflags $(PKGS))
LDLIBS  += $(shell pkg-config --libs $(PKGS))

xdg-shell-protocol.h:
	@test -n "$(WAYLAND_SCANNER)" || { echo "ERROR: wayland-scanner not found (install 'wayland')" >&2; exit 1; }
	@test -f "$(XDG_SHELL_XML)"   || { echo "ERROR: xdg-shell.xml not found at $(XDG_SHELL_XML)" >&2; \
	                                   echo "       install 'wayland-protocols'." >&2; exit 1; }
	$(WAYLAND_SCANNER) server-header $(XDG_SHELL_XML) $@

pocketwl: xdg-shell-protocol.h pocketwl.c
ifeq ($(WLROOTS),)
	@echo "ERROR: no wlroots pkg-config file found. 'pkg install wlroots' (needs x11-repo)." >&2; exit 1
endif
	@echo "Building against: $(WLROOTS)"
	$(CC) $(CFLAGS) -o $@ pocketwl.c $(LDLIBS)

clean:
	rm -f pocketwl xdg-shell-protocol.h

.PHONY: clean
