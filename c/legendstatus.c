/* legendstatus — a pocket status line for dwm / dwl, in C.
 *
 * "Reject Electron. Return to C."
 *
 * Reads the kernel's own /proc and /sys files — no libraries, no daemons —
 * and prints a single status string: battery, disk, memory, CPU load,
 * temperature, and the date. Every field is optional: if the machine has no
 * battery or no thermal zone, that field is silently dropped, so the same
 * binary works on the MacBook Air, on a phone, and on a headless box.
 *
 *   legendstatus -1        print one status line and exit (pipe into a bar)
 *   legendstatus           loop, printing a line every INTERVAL seconds
 *   legendstatus -n 2      loop with a 2-second interval
 *
 * Wire it into dwm:
 *   while :; do xsetroot -name "$(legendstatus -1)"; sleep 5; done &
 * or feed a status bar that reads stdin (dwl/dwlb, etc.):
 *   legendstatus -n 5 | dwlb -stdin ...
 *
 * Build:  cc -std=c99 -Os -o legendstatus legendstatus.c   (see c/Makefile)
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/statvfs.h>

#define INTERVAL 5      /* default loop interval, seconds */
#define SEP " | "       /* field separator */

/* Read the first whitespace-delimited token of a file as a long.
 * Returns 1 on success, 0 if the file is missing/unreadable. */
static int read_long(const char *path, long *out)
{
	FILE *f = fopen(path, "r");
	if (!f)
		return 0;
	int ok = (fscanf(f, "%ld", out) == 1);
	fclose(f);
	return ok;
}

/* Read the first line of a file into buf (newline stripped). */
static int read_str(const char *path, char *buf, size_t n)
{
	FILE *f = fopen(path, "r");
	if (!f)
		return 0;
	int ok = fgets(buf, (int)n, f) != NULL;
	fclose(f);
	if (ok)
		buf[strcspn(buf, "\n")] = '\0';
	return ok;
}

/* Append " bat NN% <glyph>" for the first real battery under
 * /sys/class/power_supply. Detected by its `type` file (== "Battery"), so it
 * works for laptop supplies named BAT0/BAT1 *and* Android's, named "battery". */

/* Estimated battery runtime, in minutes: time-to-empty while discharging,
 * time-to-full while charging. Uses energy_now/power_now (Wh/W) or, failing
 * that, charge_now/current_now (Ah/A). Returns 0 when the rate isn't exposed
 * (common on phones) or there's no meaningful estimate. */
static long battery_minutes(const char *base, const char *status)
{
	char path[600];
	long now = 0, rate = 0, full = 0;
	long long target;

	snprintf(path, sizeof path, "%s/power_now", base);
	if (read_long(path, &rate) && rate != 0) {
		snprintf(path, sizeof path, "%s/energy_now", base);
		read_long(path, &now);
		snprintf(path, sizeof path, "%s/energy_full", base);
		read_long(path, &full);
	} else {
		snprintf(path, sizeof path, "%s/current_now", base);
		if (!read_long(path, &rate) || rate == 0)
			return 0;
		snprintf(path, sizeof path, "%s/charge_now", base);
		read_long(path, &now);
		snprintf(path, sizeof path, "%s/charge_full", base);
		read_long(path, &full);
	}
	if (rate < 0)
		rate = -rate; /* current_now is signed on some kernels */
	if (rate == 0)
		return 0;

	if (!strcmp(status, "Charging"))
		target = (long long)full - now;
	else if (!strcmp(status, "Discharging"))
		target = now;
	else
		return 0; /* Full/Unknown: no estimate worth showing */
	if (target <= 0)
		return 0;
	return (long)((target * 60) / rate);
}

static void field_battery(char *out, size_t n)
{
	DIR *d = opendir("/sys/class/power_supply");
	struct dirent *e;
	char base[512], path[600], type[32], status[32], eta[16];
	long cap, mins;

	if (!d)
		return;
	while ((e = readdir(d))) {
		if (e->d_name[0] == '.')
			continue;
		snprintf(base, sizeof base, "/sys/class/power_supply/%s", e->d_name);
		snprintf(path, sizeof path, "%s/type", base);
		if (!read_str(path, type, sizeof type) || strcmp(type, "Battery") != 0)
			continue;
		snprintf(path, sizeof path, "%s/capacity", base);
		if (!read_long(path, &cap))
			continue;
		snprintf(path, sizeof path, "%s/status", base);
		if (!read_str(path, status, sizeof status))
			snprintf(status, sizeof status, "Unknown");

		const char *glyph = "•";
		if (!strcmp(status, "Charging"))
			glyph = "+";
		else if (!strcmp(status, "Discharging"))
			glyph = "-";
		else if (!strcmp(status, "Full"))
			glyph = "=";

		/* Optional " 4h12m" runtime estimate when the kernel exposes it.
		 * Clamp implausible values (a near-zero rate yields a nonsense
		 * multi-thousand-hour estimate) to "unknown". */
		eta[0] = '\0';
		mins = battery_minutes(base, status);
		if (mins > 99 * 60 + 59)
			mins = 0;
		if (mins >= 60)
			snprintf(eta, sizeof eta, " %ldh%02ldm", mins / 60, mins % 60);
		else if (mins > 0)
			snprintf(eta, sizeof eta, " %ldm", mins);

		size_t len = strlen(out);
		snprintf(out + len, n - len, "%sbat %ld%%%s%s",
			 len ? SEP : "", cap, glyph, eta);
		break;
	}
	closedir(d);
}

/* Append " disk NN%" — used space on the filesystem holding `path` (df-style).
 * Defaults to $HOME so it reports the partition your files live on (the data
 * partition on Android, /home on a laptop) rather than a read-only system
 * image mounted at / that always shows ~100%. */
static void field_storage(char *out, size_t n, const char *path)
{
	struct statvfs vfs;
	unsigned long long total, avail, used;

	if (statvfs(path, &vfs) != 0 || vfs.f_blocks == 0)
		return;
	total = (unsigned long long)vfs.f_blocks - vfs.f_bfree; /* used blocks */
	avail = vfs.f_bavail;                                   /* free to us */
	used = total;
	if (used + avail == 0)
		return;
	size_t len = strlen(out);
	snprintf(out + len, n - len, "%sdisk %llu%%",
		 len ? SEP : "", (used * 100) / (used + avail));
}

/* Append " load N.NN" from /proc/loadavg (1-minute average). */
static void field_load(char *out, size_t n)
{
	char buf[128];
	if (!read_str("/proc/loadavg", buf, sizeof buf))
		return;
	char *sp = strchr(buf, ' ');
	if (sp)
		*sp = '\0';
	size_t len = strlen(out);
	snprintf(out + len, n - len, "%sload %s", len ? SEP : "", buf);
}

/* Append " mem NN%" of used RAM from /proc/meminfo. */
static void field_mem(char *out, size_t n)
{
	FILE *f = fopen("/proc/meminfo", "r");
	char key[64];
	long val, total = 0, avail = 0;

	if (!f)
		return;
	while (fscanf(f, "%63s %ld %*s", key, &val) == 2) {
		if (!strcmp(key, "MemTotal:"))
			total = val;
		else if (!strcmp(key, "MemAvailable:"))
			avail = val;
		if (total && avail)
			break;
	}
	fclose(f);
	if (total > 0) {
		long used = total - avail;
		size_t len = strlen(out);
		snprintf(out + len, n - len, "%smem %ld%%",
			 len ? SEP : "", (used * 100) / total);
	}
}

/* Append " NN°C" from the first thermal zone that exists. */
static void field_temp(char *out, size_t n)
{
	long milli;
	if (!read_long("/sys/class/thermal/thermal_zone0/temp", &milli))
		return;
	size_t len = strlen(out);
	snprintf(out + len, n - len, "%s%ld°C", len ? SEP : "", milli / 1000);
}

/* Append the local date/time. */
static void field_clock(char *out, size_t n)
{
	time_t t = time(NULL);
	struct tm tm;
	char buf[64];

	if (!localtime_r(&t, &tm))
		return;
	strftime(buf, sizeof buf, "%a %d %b %H:%M", &tm);
	size_t len = strlen(out);
	snprintf(out + len, n - len, "%s%s", len ? SEP : "", buf);
}

static void build_line(char *out, size_t n, const char *diskpath)
{
	out[0] = '\0';
	field_battery(out, n);
	field_storage(out, n, diskpath);
	field_mem(out, n);
	field_load(out, n);
	field_temp(out, n);
	field_clock(out, n);
}

int main(int argc, char **argv)
{
	int once = 0;
	unsigned interval = INTERVAL;
	char line[512];
	const char *diskpath = getenv("HOME");

	if (!diskpath || !*diskpath)
		diskpath = "/";

	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-1")) {
			once = 1;
		} else if (!strcmp(argv[i], "-n") && i + 1 < argc) {
			int v = atoi(argv[++i]);
			if (v > 0)
				interval = (unsigned)v;
		} else if (!strcmp(argv[i], "-d") && i + 1 < argc) {
			diskpath = argv[++i];
		} else {
			fprintf(stderr,
				"usage: %s [-1] [-n interval] [-d path]\n"
				"  -1          print one line and exit\n"
				"  -n SECONDS  loop interval (default %d)\n"
				"  -d PATH     filesystem to report for 'disk'\n"
				"              (default $HOME, else /)\n",
				argv[0], INTERVAL);
			return 2;
		}
	}

	do {
		build_line(line, sizeof line, diskpath);
		puts(line);
		fflush(stdout);
		if (!once)
			sleep(interval);
	} while (!once);

	return 0;
}
