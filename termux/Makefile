# pocketwl — build against Termux's native wlroots.
# wlroots has no stable API and its pkg-config name is versioned (wlroots-0.17,
# wlroots-0.18, wlroots-0.19, ...). Rather than guess the suffix, discover the
# actual installed name from pkg-config's own registry.
WLROOTS := $(shell pkg-config --list-all 2>/dev/null | awk '/^wlroots/{print $$1; exit}')

PKGS = $(WLROOTS) wayland-server xkbcommon

CFLAGS  += -DWLR_USE_UNSTABLE -std=c11 -Wall -Wextra -Wno-unused-parameter -g
CFLAGS  += $(shell pkg-config --cflags $(PKGS))
LDLIBS  += $(shell pkg-config --libs $(PKGS))

pocketwl: pocketwl.c
ifeq ($(WLROOTS),)
	@echo "ERROR: no wlroots pkg-config file found. Is it installed?" >&2; \
	 echo "  pkg install wlroots      # (needs x11-repo)" >&2; \
	 echo "  pkg-config --list-all | grep -i wlroots   # to see the name" >&2; \
	 exit 1
endif
	@echo "Building against: $(WLROOTS)"
	$(CC) $(CFLAGS) -o $@ pocketwl.c $(LDLIBS)

clean:
	rm -f pocketwl

.PHONY: clean
