CC      = gcc
CFLAGS  = -std=c99 -O2 -Wall -Wextra -pedantic
LDFLAGS = -static

BIN     = installer/install
PROFILE = iso
WORK    = /tmp/caulk-work
OUT     = .

.PHONY: all installer iso clean

all: installer

installer: $(BIN)

$(BIN): installer/install.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

iso: installer
	cp $(BIN) $(PROFILE)/airootfs/usr/bin/caulk-install
	chmod +x $(PROFILE)/airootfs/usr/bin/caulk-install
	sudo mkarchiso -v -w $(WORK) -o $(OUT) $(PROFILE)

clean:
	rm -f $(BIN)
	rm -rf $(WORK)
	rm -f caulklinux-*.iso
