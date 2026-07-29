# pocketwl — build against Termux's native wlroots.
# wlroots has no stable API; its pkg-config name is versioned (wlroots-0.18,
# wlroots-0.19, ...). Auto-detect it, preferring the version pocketwl targets.

WLROOTS := $(shell \
	pkg-config --exists wlroots-0.18 && echo wlroots-0.18 || \
	( pkg-config --exists wlroots-0.19 && echo wlroots-0.19 || \
	( pkg-config --exists wlroots-0.17 && echo wlroots-0.17 || echo wlroots ) ) )

PKGS = $(WLROOTS) wayland-server xkbcommon

CFLAGS  += -DWLR_USE_UNSTABLE -std=c11 -Wall -Wextra -Wno-unused-parameter -g
CFLAGS  += $(shell pkg-config --cflags $(PKGS))
LDLIBS  += $(shell pkg-config --libs $(PKGS))

pocketwl: pocketwl.c
	@echo "Building against: $(WLROOTS)"
	$(CC) $(CFLAGS) -o $@ pocketwl.c $(LDLIBS)

clean:
	rm -f pocketwl

.PHONY: clean
