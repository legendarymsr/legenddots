/*
 * CaulkLinux installer — single C99 file, raw termios, zero ncurses
 * SPDX-License-Identifier: GPL-2.0-only
 */
#define _POSIX_C_SOURCE 200809L
#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <termios.h>
#include <unistd.h>

/* ── palette ── */
#define R0  "\033[0m"
#define RB  "\033[1m"
#define RD  "\033[2m"
#define RR  "\033[1;31m"
#define RG  "\033[1;32m"
#define RY  "\033[1;33m"
#define RBL "\033[1;34m"
#define RRV "\033[7m"

/* ── types ── */
typedef enum { WM_I3, WM_HYPRLAND, WM_NIRI } WM;

typedef struct {
    char disk[64];
    char user[64];
    char pass[128];
    char host[64];
    char tz[64];
    char keymap[32];
    WM   wm;
    int  uefi;
} Cfg;

/* ── terminal state ── */
static struct termios orig_term;
static int raw_active = 0;

static void raw_off(void) {
    if (raw_active) {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_term);
        raw_active = 0;
    }
}

static void raw_on(void) {
    tcgetattr(STDIN_FILENO, &orig_term);
    struct termios t = orig_term;
    t.c_lflag &= ~(unsigned)(ECHO | ICANON | ISIG | IEXTEN);
    t.c_iflag &= ~(unsigned)(IXON | ICRNL | BRKINT | INPCK | ISTRIP);
    t.c_cflag |= CS8;
    t.c_oflag &= ~(unsigned)OPOST;
    t.c_cc[VMIN]  = 1;
    t.c_cc[VTIME] = 0;
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &t);
    raw_active = 1;
}

static void cleanup(void) { raw_off(); printf(R0 "\033[?25h\n"); }
static void on_sig(int s) { (void)s; cleanup(); _exit(1); }

/* ── key reader ── */
static int gkey(void) {
    unsigned char c;
    if (read(STDIN_FILENO, &c, 1) != 1) return -1;
    if (c != 0x1b) return (int)c;
    unsigned char seq[3] = {0};
    if (read(STDIN_FILENO, &seq[0], 1) != 1) return 0x1b;
    if (seq[0] != '[') return 0x1b;
    if (read(STDIN_FILENO, &seq[1], 1) != 1) return 0x1b;
    switch (seq[1]) {
        case 'A': return 'k';
        case 'B': return 'j';
        case 'C': return 'l';
        case 'D': return 'h';
    }
    return 0x1b;
}

/* ── line reader (restores term) ── */
static void rline(char *buf, int sz, int hide) {
    raw_off();
    printf("\033[?25h");
    fflush(stdout);
    if (hide) {
        struct termios t;
        tcgetattr(STDIN_FILENO, &t);
        t.c_lflag &= ~(unsigned)ECHO;
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &t);
    }
    if (!fgets(buf, sz, stdin)) buf[0] = '\0';
    size_t n = strlen(buf);
    if (n && buf[n-1] == '\n') buf[n-1] = '\0';
    if (hide) {
        struct termios t;
        tcgetattr(STDIN_FILENO, &t);
        t.c_lflag |= ECHO;
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &t);
        puts("");
    }
    raw_on();
}

/* ── terminal dimensions ── */
static void termsize(int *rows, int *cols) {
    struct winsize ws;
    ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws);
    *rows = ws.ws_row ? ws.ws_row : 24;
    *cols = ws.ws_col ? ws.ws_col : 80;
}

static void clear(void) { printf("\033[2J\033[H"); }

/* ── centred box header ── */
static void banner(const char *title) {
    int rows, cols;
    termsize(&rows, &cols);
    (void)rows;
    int w = cols - 4;
    if (w < 40) w = 40;
    printf("\033[H" RBL);
    printf("  ╔");
    for (int i = 0; i < w; i++) printf("═");
    printf("╗\n");
    int pad = (w - (int)strlen(title)) / 2;
    printf("  ║%*s" RB "%s" RBL "%*s║\n", pad, "", title, w - pad - (int)strlen(title), "");
    printf("  ╠");
    for (int i = 0; i < w; i++) printf("═");
    printf("╣\n" R0);
}

static void box_foot(void) {
    int rows, cols;
    termsize(&rows, &cols);
    (void)rows;
    int w = cols - 4;
    if (w < 40) w = 40;
    printf(RBL "  ╚");
    for (int i = 0; i < w; i++) printf("═");
    printf("╝\n" R0);
}

/* ── vertical menu ── */
static int menu(const char **items, int n, int cur) {
    while (1) {
        for (int i = 0; i < n; i++) {
            if (i == cur) printf("  " RRV "  %-36s  " R0 "\n", items[i]);
            else          printf("     %-36s  \n", items[i]);
        }
        printf(RD "\n  [j/↓] down  [k/↑] up  [Enter] select\n" R0);
        int k = gkey();
        if (k == 'j' || k == 14)  cur = (cur + 1) % n;
        if (k == 'k' || k == 16)  cur = (cur - 1 + n) % n;
        if (k == '\r' || k == '\n') return cur;
        if (k == 'q') return -1;
        /* redraw — move cursor up */
        printf("\033[%dA", n + 2);
    }
}

/* ── disk discovery ── */
static int find_disks(char disks[][64], int max) {
    DIR *d = opendir("/sys/block");
    if (!d) return 0;
    int n = 0;
    struct dirent *e;
    while ((e = readdir(d)) && n < max) {
        const char *nm = e->d_name;
        if (nm[0] == '.') continue;
        if (strncmp(nm, "loop", 4) == 0) continue;
        if (strncmp(nm, "ram",  3) == 0) continue;
        if (strncmp(nm, "zram", 4) == 0) continue;
        if (strncmp(nm, "sr",   2) == 0) continue;
        snprintf(disks[n], 64, "/dev/%s", nm);
        n++;
    }
    closedir(d);
    return n;
}

/* partition suffix: nvme0n1 → nvme0n1p1, sda → sda1 */
static void pname(const char *disk, int num, char *out, int sz) {
    if (strstr(disk, "nvme") || strstr(disk, "mmcblk"))
        snprintf(out, sz, "%sp%d", disk, num);
    else
        snprintf(out, sz, "%s%d", disk, num);
}

/* ── shell helpers ── */
static FILE *logf;

static int sh(const char *fmt, ...) {
    char cmd[1024];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(cmd, sizeof cmd, fmt, ap);
    va_end(ap);
    if (logf) { fprintf(logf, "$ %s\n", cmd); fflush(logf); }
    int r = system(cmd);
    if (logf) { fprintf(logf, "→ %d\n", r); fflush(logf); }
    return r;
}

static int chr(const char *root, const char *fmt, ...) {
    char inner[900];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(inner, sizeof inner, fmt, ap);
    va_end(ap);
    char cmd[1024];
    snprintf(cmd, sizeof cmd, "arch-chroot %s /bin/bash -c '%s'", root, inner);
    if (logf) { fprintf(logf, "chroot$ %s\n", cmd); fflush(logf); }
    int r = system(cmd);
    if (logf) { fprintf(logf, "chroot→ %d\n", r); fflush(logf); }
    return r;
}

/* ── partitioning ── */
static void do_partition(const char *disk, int uefi, char *p1, char *p2, int sz) {
    sh("wipefs -af %s", disk);
    pname(disk, 1, p1, sz);
    pname(disk, 2, p2, sz);
    if (uefi) {
        sh("parted -s %s mklabel gpt", disk);
        sh("parted -s %s mkpart ESP fat32 1MiB 513MiB", disk);
        sh("parted -s %s set 1 esp on", disk);
        sh("parted -s %s mkpart primary ext4 513MiB 100%%", disk);
        sh("mkfs.fat -F32 %s", p1);
        sh("mkfs.ext4 -F %s", p2);
    } else {
        sh("parted -s %s mklabel msdos", disk);
        sh("parted -s %s mkpart primary ext4 1MiB 100%%", disk);
        sh("parted -s %s set 1 boot on", disk);
        sh("mkfs.ext4 -F %s", p1);
        /* p2 unused in BIOS mode — fill with sentinel */
        snprintf(p2, sz, "none");
    }
}

/* ── pacstrap ── */
static void do_pacstrap(const char *root, WM wm) {
    const char *common =
        "base linux linux-firmware grub efibootmgr networkmanager "
        "sudo zsh git curl wget alacritty neovim starship "
        "pipewire pipewire-alsa pipewire-pulse wireplumber "
        "ttf-jetbrains-mono-nerd";

    const char *wm_pkgs;
    switch (wm) {
        case WM_I3:
            wm_pkgs = "xorg-server xorg-xinit i3-wm polybar rofi i3lock "
                      "picom feh dunst xss-lock lightdm lightdm-gtk-greeter";
            break;
        case WM_HYPRLAND:
            wm_pkgs = "hyprland waybar fuzzel hyprlock dunst "
                      "xdg-desktop-portal-hyprland polkit-gnome";
            break;
        case WM_NIRI:
        default:
            wm_pkgs = "niri waybar fuzzel swaylock dunst "
                      "xdg-desktop-portal-gnome polkit-gnome";
            break;
    }

    sh("pacstrap -K %s %s %s", root, common, wm_pkgs);
}

/* ── system configuration ── */
static void do_configure(const char *root, const Cfg *c, const char *p1, const char *p2) {
    const char *wm_names[] = { "i3", "hyprland", "niri" };
    const char *wm = wm_names[c->wm];

    /* fstab */
    sh("genfstab -U %s >> %s/etc/fstab", root, root);

    /* timezone */
    chr(root, "ln -sf /usr/share/zoneinfo/%s /etc/localtime && hwclock --systohc", c->tz);

    /* locale */
    chr(root, "sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen");
    chr(root, "echo LANG=en_US.UTF-8 > /etc/locale.conf");

    /* keymap */
    chr(root, "echo KEYMAP=%s > /etc/vconsole.conf", c->keymap);

    /* hostname */
    chr(root, "echo %s > /etc/hostname", c->host);
    chr(root, "printf '127.0.0.1 localhost\\n::1 localhost\\n127.0.1.1 %s\\n' >> /etc/hosts", c->host);

    /* user + password */
    chr(root, "useradd -m -G wheel,audio,video,network -s /bin/zsh %s", c->user);
    chr(root, "echo '%s:%s' | chpasswd", c->user, c->pass);
    chr(root, "sed -i 's/^# %%wheel ALL=(ALL:ALL) ALL/%%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers");

    /* services */
    chr(root, "systemctl enable NetworkManager");

    /* session autostart */
    if (c->wm == WM_I3) {
        chr(root, "systemctl enable lightdm");
        chr(root, "echo 'exec i3' > /home/%s/.xinitrc && chown %s:%s /home/%s/.xinitrc",
            c->user, c->user, c->user, c->user);
    } else {
        /* Wayland: .zprofile Hyprland/Niri launch */
        chr(root,
            "printf 'if [ -z \"$DISPLAY\" ] && [ \"$(tty)\" = /dev/tty1 ]; then\\n"
            "  exec %s\\nfi\\n' >> /home/%s/.zprofile && "
            "chown %s:%s /home/%s/.zprofile",
            wm, c->user, c->user, c->user, c->user);
        chr(root, "systemctl enable getty@tty1");
    }

    /* bootloader */
    if (c->uefi) {
        sh("mount --mkdir %s /mnt/boot/efi", p1);
        chr(root, "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=CaulkLinux");
    } else {
        chr(root, "grub-install --target=i386-pc %s", c->disk);
    }
    chr(root, "grub-mkconfig -o /boot/grub/grub.cfg");
    (void)p2;
}

/* ── dotfiles ── */
static void do_dotfiles(const char *root, const char *user, WM wm) {
    const char *cfg = "/dots";
    char dst[256];
    snprintf(dst, sizeof dst, "%s/home/%s/.config", root, user);
    sh("mkdir -p %s", dst);

    const char *wm_dir[] = { "i3", "hyprland", "niri" };
    char src[256];

    /* WM-specific dotfiles */
    snprintf(src, sizeof src, "%s/%s", cfg, wm_dir[wm]);
    struct stat st;
    if (stat(src, &st) == 0)
        sh("cp -r %s %s/", src, dst);

    /* shared dotfiles */
    const char *shared[] = { "alacritty", "nvim", "waybar", "dunst", NULL };
    for (int i = 0; shared[i]; i++) {
        snprintf(src, sizeof src, "%s/%s", cfg, shared[i]);
        if (stat(src, &st) == 0)
            sh("cp -r %s %s/", src, dst);
    }

    /* .zshrc */
    snprintf(src, sizeof src, "%s/.zshrc", cfg);
    if (stat(src, &st) == 0) {
        char zdst[256];
        snprintf(zdst, sizeof zdst, "%s/home/%s/.zshrc", root, user);
        sh("cp %s %s", src, zdst);
    }

    /* fix ownership */
    sh("chown -R 1000:1000 %s/home/%s", root, user);
}

/* ══════════════════════════════════════════════════════
 * Screens
 * ══════════════════════════════════════════════════════ */

static void scr_welcome(void) {
    clear();
    banner("  CaulkLinux Installer  ");
    printf("\n");
    printf("  " RG "Minimal Arch-based Linux" R0 "\n\n");
    printf("  Modes:  " RBL "i3" R0 " (X11)   " RBL "Hyprland" R0 " (Wayland)   " RBL "Niri" R0 " (Wayland)\n\n");
    printf("  Dotfiles are copied from " RY "/dots" R0 " on the ISO.\n\n");
    printf("  " RR "All data on the selected disk will be erased." R0 "\n\n");
    box_foot();
    printf(RD "  Press Enter to begin...\n" R0);
    fflush(stdout);
    int k;
    do { k = gkey(); } while (k != '\r' && k != '\n' && k != ' ');
}

static void scr_disk(Cfg *c) {
    char disks[16][64];
    int nd = find_disks(disks, 16);

    clear();
    banner("  Select Installation Disk  ");
    printf("\n");

    if (nd == 0) {
        printf(RR "  No disks found. Aborting.\n" R0);
        sleep(3); exit(1);
    }

    const char *items[16];
    for (int i = 0; i < nd; i++) items[i] = disks[i];

    int sel = menu(items, nd, 0);
    if (sel < 0) exit(0);
    strncpy(c->disk, disks[sel], sizeof c->disk - 1);

    /* UEFI detection */
    c->uefi = (access("/sys/firmware/efi", F_OK) == 0);

    box_foot();
    printf("  Selected: " RG "%s" R0 "  (%s)\n\n",
           c->disk, c->uefi ? "UEFI" : "BIOS");
    sleep(1);
}

static void scr_user(Cfg *c) {
    clear();
    banner("  User Setup  ");
    printf("\n");
    raw_off();

    printf("  " RBL "Username: " R0); fflush(stdout);
    rline(c->user, sizeof c->user, 0);

    printf("  " RBL "Password: " R0); fflush(stdout);
    rline(c->pass, sizeof c->pass, 1);

    char confirm[128];
    printf("  " RBL "Confirm : " R0); fflush(stdout);
    rline(confirm, sizeof confirm, 1);
    if (strcmp(c->pass, confirm) != 0) {
        printf(RR "  Passwords do not match. Try again.\n" R0);
        sleep(2);
        scr_user(c);
        return;
    }

    printf("  " RBL "Hostname: " R0); fflush(stdout);
    rline(c->host, sizeof c->host, 0);

    box_foot();
    raw_on();
}

static void scr_locale(Cfg *c) {
    clear();
    banner("  Locale  ");
    printf("\n");
    raw_off();

    printf("  " RBL "Timezone" R0 " (e.g. America/New_York): "); fflush(stdout);
    rline(c->tz, sizeof c->tz, 0);
    if (!c->tz[0]) strncpy(c->tz, "Europe/Brussels", sizeof c->tz - 1);

    printf("  " RBL "Keymap " R0 " (e.g. us, uk, de):        "); fflush(stdout);
    rline(c->keymap, sizeof c->keymap, 0);
    if (!c->keymap[0]) strncpy(c->keymap, "us", sizeof c->keymap - 1);

    box_foot();
    raw_on();
}

static void scr_wm(Cfg *c) {
    clear();
    banner("  Window Manager  ");
    printf("\n");

    const char *items[] = {
        "i3        — X11 · i3-wm · polybar · rofi · i3lock",
        "Hyprland  — Wayland · hyprland · waybar · fuzzel · hyprlock",
        "Niri      — Wayland · niri · waybar · fuzzel · swaylock",
    };
    int sel = menu(items, 3, 0);
    if (sel < 0) exit(0);
    c->wm = (WM)sel;
    box_foot();
}

static void scr_confirm(const Cfg *c) {
    const char *wm_names[] = { "i3", "Hyprland", "Niri" };
    clear();
    banner("  Confirm Installation  ");
    printf("\n");
    printf("  Disk     : " RY "%s" R0 "\n", c->disk);
    printf("  Firmware : " RY "%s" R0 "\n", c->uefi ? "UEFI" : "BIOS");
    printf("  User     : " RY "%s" R0 "\n", c->user);
    printf("  Hostname : " RY "%s" R0 "\n", c->host);
    printf("  Timezone : " RY "%s" R0 "\n", c->tz);
    printf("  Keymap   : " RY "%s" R0 "\n", c->keymap);
    printf("  WM       : " RY "%s" R0 "\n", wm_names[c->wm]);
    printf("\n  " RR "ALL DATA ON %s WILL BE ERASED." R0 "\n\n", c->disk);
    box_foot();

    const char *items[] = { "Install now", "Abort" };
    int sel = menu(items, 2, 0);
    if (sel != 0) { printf("  Aborted.\n"); exit(0); }
}

static void scr_install(const Cfg *c) {
    const char *root = "/mnt";
    char p1[80], p2[80];

    clear();
    banner("  Installing CaulkLinux  ");
    printf("\n");

    logf = fopen("/tmp/caulk-install.log", "w");
    raw_off();
    printf("\033[?25h");
    fflush(stdout);

#define STEP(label, ...) \
    do { printf("  " RBL "→ " R0 label "\n"); fflush(stdout); __VA_ARGS__; } while(0)

    STEP("Partitioning %s ...", c->disk,
         do_partition(c->disk, c->uefi, p1, p2, sizeof p1));

    STEP("Mounting ...",
         sh("mount %s %s", c->uefi ? p2 : p1, root);
         if (c->uefi) sh("mkdir -p %s/boot/efi", root));

    STEP("Pacstrapping packages ...",
         do_pacstrap(root, c->wm));

    STEP("Configuring system ...",
         do_configure(root, c, p1, p2));

    STEP("Copying dotfiles ...",
         do_dotfiles(root, c->user, c->wm));

    STEP("Unmounting ...",
         sh("umount -R %s", root));

#undef STEP

    if (logf) fclose(logf);

    printf("\n  " RG "Installation complete!" R0 "\n");
    printf("  Log: /tmp/caulk-install.log\n\n");
    printf("  Remove the USB and reboot.\n\n");
    fflush(stdout);
    printf("  Press Enter to reboot...\n");
    raw_on();
    int k; do { k = gkey(); } while (k != '\r' && k != '\n');
    raw_off();
    sh("reboot");
}

/* ── entry point ── */
int main(void) {
    atexit(cleanup);
    signal(SIGINT,  on_sig);
    signal(SIGTERM, on_sig);
    signal(SIGHUP,  on_sig);

    raw_on();
    printf("\033[?25l"); /* hide cursor */

    Cfg cfg;
    memset(&cfg, 0, sizeof cfg);

    scr_welcome();
    scr_disk(&cfg);
    scr_user(&cfg);
    scr_locale(&cfg);
    scr_wm(&cfg);
    scr_confirm(&cfg);
    scr_install(&cfg);

    return 0;
}
