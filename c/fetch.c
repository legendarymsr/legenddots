/* fetch — the manifesto spite binary, in C.
 *
 * "Freedom is not granted — it is taken and defended."
 * "Reject Electron. Return to C."
 *
 * A dependency-free system fetch that states the manifesto and prints a
 * little machine info by reading /proc, /etc, and uname(2) — no libraries,
 * no runtime, no 90MB of Chromium. The C sibling of the Rust manifesto
 * (../fetch.rs); both are kept. Installs as 'fetch-c' so it coexists with
 * 'fetch'.
 *
 * Build:  cc -std=c99 -Os -o fetch-c fetch.c    (see c/Makefile)
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pwd.h>
#include <sys/utsname.h>

/* Trans-pride truecolor palette (matches the original fetch.rs). */
#define BLUE  "\x1b[38;2;91;206;250m"
#define PINK  "\x1b[38;2;245;169;184m"
#define WHITE "\x1b[38;2;255;255;255m"
#define DIM   "\x1b[2m"
#define BOLD  "\x1b[1m"
#define RESET "\x1b[0m"

/* Pull PRETTY_NAME="..." out of /etc/os-release into buf. */
static void os_pretty_name(char *buf, size_t n)
{
	FILE *f = fopen("/etc/os-release", "r");
	char line[256];

	snprintf(buf, n, "unknown");
	if (!f)
		return;
	while (fgets(line, sizeof line, f)) {
		if (strncmp(line, "PRETTY_NAME=", 12) != 0)
			continue;
		char *v = line + 12;
		if (*v == '"')
			v++;
		v[strcspn(v, "\"\n")] = '\0';
		snprintf(buf, n, "%s", v);
		break;
	}
	fclose(f);
}

/* Format the system uptime (from /proc/uptime) as "Nd Nh Nm". */
static void uptime_str(char *buf, size_t n)
{
	double up = 0.0;
	FILE *f = fopen("/proc/uptime", "r");

	snprintf(buf, n, "?");
	if (!f)
		return;
	if (fscanf(f, "%lf", &up) == 1) {
		long s = (long)up;
		long d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60;
		if (d)
			snprintf(buf, n, "%ldd %ldh %ldm", d, h, m);
		else if (h)
			snprintf(buf, n, "%ldh %ldm", h, m);
		else
			snprintf(buf, n, "%ldm", m);
	}
	fclose(f);
}

int main(void)
{
	struct utsname u;
	struct passwd *pw = getpwuid(getuid());
	char host[256] = "localhost", os[256], up[64];
	const char *user = pw ? pw->pw_name : "user";
	const char *shell = getenv("SHELL");

	gethostname(host, sizeof host);
	host[sizeof host - 1] = '\0';
	os_pretty_name(os, sizeof os);
	uptime_str(up, sizeof up);
	if (uname(&u) != 0)
		snprintf(u.release, sizeof u.release, "?");
	if (!shell || !*shell)
		shell = "?";

	/* The manifesto. */
	putchar('\n');
	printf("  " BOLD WHITE "Freedom is not granted — it is taken and defended." RESET "\n");
	printf("  " BOLD BLUE  "Reject Electron. " PINK "Return to C." RESET "\n");
	putchar('\n');

	/* The machine (neofetch, minus the bloat). */
	printf("  " BOLD BLUE "%s" RESET "@" BOLD BLUE "%s" RESET "\n", user, host);
	printf("  " PINK "os     " RESET "%s\n", os);
	printf("  " PINK "kernel " RESET "%s %s\n", u.sysname, u.release);
	printf("  " PINK "uptime " RESET "%s\n", up);
	printf("  " PINK "shell  " RESET "%s\n", shell);
	printf("  " PINK "fetch  " RESET "C — no Rust, no Electron, no runtime\n");
	putchar('\n');
	return 0;
}
