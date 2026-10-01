/* legendtimer — a terminal countdown timer, in C.
 *
 * "Reject Electron. Return to C."
 *
 * Counts down a duration on a single live-updating line, then rings the
 * terminal bell. No libraries, no notification daemon — just the terminal.
 *
 *   legendtimer 90             90 seconds
 *   legendtimer 5m             5 minutes
 *   legendtimer 1h30m          an hour and a half
 *   legendtimer 25m focus      labelled: "focus  24:59"
 *
 * A bare number is seconds; h/m/s suffixes combine (order-independent).
 *
 * Build:  cc -std=c99 -Os -o legendtimer legendtimer.c    (see c/Makefile)
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>

/* Parse "1h30m", "90s", "5m", or a bare-seconds "90" into seconds.
 * Returns -1 on malformed input. */
static long parse_duration(const char *s)
{
	long total = 0, num = 0;
	int seen_digit = 0;

	for (; *s; s++) {
		if (isdigit((unsigned char)*s)) {
			num = num * 10 + (*s - '0');
			seen_digit = 1;
		} else if (*s == 'h') {
			total += num * 3600;
			num = 0;
		} else if (*s == 'm') {
			total += num * 60;
			num = 0;
		} else if (*s == 's') {
			total += num;
			num = 0;
		} else {
			return -1;
		}
	}
	total += num; /* trailing bare number counts as seconds */
	return seen_digit ? total : -1;
}

static void sleep_one_second(void)
{
	struct timespec ts = { 1, 0 };
	nanosleep(&ts, NULL);
}

int main(int argc, char **argv)
{
	long remaining;
	char label[64] = "";

	if (argc < 2) {
		fprintf(stderr,
			"usage: %s DURATION [label]\n"
			"  DURATION  90 | 90s | 5m | 1h30m  (bare number = seconds)\n"
			"  label     optional text shown beside the countdown\n",
			argv[0]);
		return 2;
	}
	remaining = parse_duration(argv[1]);
	if (remaining < 0) {
		fprintf(stderr, "%s: bad duration '%s'\n", argv[0], argv[1]);
		return 2;
	}
	/* Join any remaining args into a label. */
	for (int i = 2; i < argc; i++) {
		if (label[0])
			strncat(label, " ", sizeof label - strlen(label) - 1);
		strncat(label, argv[i], sizeof label - strlen(label) - 1);
	}

	for (;;) {
		long h = remaining / 3600, m = (remaining % 3600) / 60, s = remaining % 60;
		if (h)
			printf("\r  %s%s%ld:%02ld:%02ld remaining   ",
			       label, label[0] ? "  " : "", h, m, s);
		else
			printf("\r  %s%s%02ld:%02ld remaining   ",
			       label, label[0] ? "  " : "", m, s);
		fflush(stdout);
		if (remaining == 0)
			break;
		sleep_one_second();
		remaining--;
	}

	printf("\r  %s%stime's up!            \n", label, label[0] ? "  " : "");
	/* Ring the bell a few times. */
	for (int i = 0; i < 3; i++) {
		putchar('\a');
		fflush(stdout);
		struct timespec ts = { 0, 400000000 }; /* 0.4s */
		nanosleep(&ts, NULL);
	}
	return 0;
}
