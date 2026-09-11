# c — the manifesto's tools, in C

> Freedom is not granted — it is taken and defended.
> Reject Electron. Return to C.

Small, dependency-free C tools. No runtime, no framework, no build system with
a build system inside it — just `cc` and a `Makefile`. Each one reads the
kernel's own `/proc` and `/sys` and talks straight to libc.

| tool | what it does |
|------|--------------|
| `fetch-c` | states the manifesto and prints neofetch-style system info. The C sibling of the Rust `fetch` (`../fetch.rs`); both are kept. |
| `legendstatus` | a pocket status line for **dwm**/**dwl**: battery, load, memory, temperature, clock. |

> The Rust manifesto (`../fetch.rs`) keeps the name `fetch`; this C port
> installs as `fetch-c` so the two live side by side.

## Build & run

```sh
make                 # build every tool into ./
./fetch-c            # run straight from here, no install needed
./legendstatus -1    # one status line (see below for the loop modes)
```

`make` needs nothing but a C compiler (`cc`/`gcc`/`clang`) and `make` — both
are already on any dev box; on a fresh Gentoo they come with `sys-devel/gcc`
and `sys-devel/make` (in `@system`).

## Install

```sh
doas make install    # install to /usr/local/bin, then run `fetch-c` anywhere
```

Override the prefix for a per-user install (no root needed):

```sh
make PREFIX="$HOME/.local" install    # ensure ~/.local/bin is on your PATH
```

Remove them again with `doas make uninstall` (same `PREFIX`).

`Bootstrap.sh` / `EndeavourRecovery.sh` already run `make -C c && make -C c
install` for you, so a fresh deploy compiles these automatically.

Build flags are hardened and warning-clean (`-Wall -Wextra -pedantic
-D_FORTIFY_SOURCE=2 -fstack-protector-strong`) — a good fit for hardened
Gentoo. Both binaries come out around 16 KB.

## fetch-c

```sh
fetch-c
```

Prints the two manifesto lines, then: `user@host`, OS (`/etc/os-release`),
kernel (`uname`), uptime (`/proc/uptime`), shell, and a reminder that it's C —
no Rust, no Electron, no runtime. Call it from your shell rc to greet every
new terminal.

## legendstatus

```sh
legendstatus -1       # print one line and exit
legendstatus          # loop, one line every 5s
legendstatus -n 2     # loop with a 2s interval
```

Every field is optional: a machine with no battery or no thermal zone simply
drops that field, so the same binary works on the MacBook Air and on a
headless box. Example output:

```
bat 87%- | load 0.42 | mem 31% | 47°C | Fri 11 Sep 14:03
```

### Wiring it into a bar

**dwm** (sets the root window name):

```sh
while :; do xsetroot -name "$(legendstatus -1)"; sleep 5; done &
```

**dwl / dwlb** (or any bar that reads stdin):

```sh
legendstatus -n 5 | dwlb -stdin -status-stdin all
```

Battery status is shown with a trailing glyph: `+` charging, `-`
discharging, `=` full, `•` unknown.
