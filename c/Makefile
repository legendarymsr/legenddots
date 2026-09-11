# c/ — the manifesto's tools, in C.
#
#   "Reject Electron. Return to C."
#
# No autotools, no cmake, no build system with a build system. Just cc.
#
#   make            build every tool
#   make install    install to $(PREFIX)/bin   (run with doas)
#   make uninstall  remove them again
#   make clean      delete the binaries
#
# Override PREFIX to install elsewhere, e.g.:  make PREFIX=$HOME/.local install

PREFIX ?= /usr/local
BINDIR  = $(PREFIX)/bin

# Hardened, warning-clean, size-optimized — a good fit for hardened Gentoo.
CFLAGS ?= -std=c99 -Os -Wall -Wextra -pedantic \
          -D_FORTIFY_SOURCE=2 -fstack-protector-strong
LDFLAGS ?=

# The Rust manifesto (../fetch.rs) keeps the name 'fetch'; the C port installs
# as 'fetch-c' so the two coexist. Same output, different language.
BINS = fetch-c legendstatus

all: $(BINS)

fetch-c: fetch.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

legendstatus: legendstatus.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

install: all
	mkdir -p $(DESTDIR)$(BINDIR)
	cp -f $(BINS) $(DESTDIR)$(BINDIR)
	cd $(DESTDIR)$(BINDIR) && chmod 0755 $(BINS)

uninstall:
	cd $(DESTDIR)$(BINDIR) && rm -f $(BINS)

clean:
	rm -f $(BINS)

.PHONY: all install uninstall clean
