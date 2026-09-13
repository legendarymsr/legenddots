/* legendbar — a sparkline generator, in C.
 *
 * "Reject Electron. Return to C."
 *
 * Turns a series of numbers into a one-line Unicode sparkline (▁▂▃▄▅▆▇█),
 * scaled between the min and max of the data. Reads numbers from the command
 * line, or from stdin if none are given. No libraries.
 *
 *   legendbar 1 2 3 4 3 2 1
 *   uptime | awk '{print $10}' | legendbar        # (whatever you can pipe)
 *   echo "3 1 4 1 5 9 2 6" | legendbar
 *
 * Build:  cc -std=c99 -Os -o legendbar legendbar.c    (see c/Makefile)
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static const char *TICKS[] = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" };

int main(int argc, char **argv)
{
	double *v = NULL, x;
	size_t n = 0, cap = 0;

	#define PUSH(val) do { \
		if (n == cap) { cap = cap ? cap * 2 : 32; \
			v = realloc(v, cap * sizeof *v); \
			if (!v) { fprintf(stderr, "legendbar: out of memory\n"); return 1; } } \
		v[n++] = (val); \
	} while (0)

	if (argc > 1) {
		for (int i = 1; i < argc; i++) {
			char *end;
			x = strtod(argv[i], &end);
			if (*end) {
				fprintf(stderr, "legendbar: not a number: %s\n", argv[i]);
				free(v);
				return 2;
			}
			PUSH(x);
		}
	} else if (isatty(STDIN_FILENO)) {
		/* No args and no pipe: don't hang waiting on the terminal. */
		fprintf(stderr, "usage: %s N N N ...   (or pipe numbers on stdin)\n",
			argv[0]);
		return 2;
	} else {
		while (scanf("%lf", &x) == 1)
			PUSH(x);
	}

	if (n == 0) {
		fprintf(stderr, "usage: %s N N N ...   (or pipe numbers on stdin)\n",
			argv[0]);
		free(v);
		return 2;
	}

	double mn = v[0], mx = v[0];
	for (size_t i = 1; i < n; i++) {
		if (v[i] < mn) mn = v[i];
		if (v[i] > mx) mx = v[i];
	}
	double range = mx - mn;
	for (size_t i = 0; i < n; i++) {
		int lvl = range > 0 ? (int)((v[i] - mn) / range * 7.0 + 0.5) : 0;
		if (lvl < 0) lvl = 0;
		if (lvl > 7) lvl = 7;
		fputs(TICKS[lvl], stdout);
	}
	putchar('\n');
	free(v);
	return 0;
}
