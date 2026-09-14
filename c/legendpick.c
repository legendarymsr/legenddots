/* legendpick — pick random items, in C.
 *
 * "Reject Electron. Return to C."
 *
 * Give the choices right on the command line, or pipe them in — one is chosen
 * (or -n of them) with kernel randomness (/dev/urandom, never rand()). No
 * libraries.
 *
 *   legendpick heads tails            one of two
 *   legendpick -n 3 a b c d e         three of five (no repeats)
 *   ls | legendpick                   one random line from a pipe
 *
 * Build:  cc -std=c99 -Os -o legendpick legendpick.c    (see c/Makefile)
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <limits.h>

static int urandom = -1;

static unsigned long rand_word(void)
{
	unsigned long r;
	if (read(urandom, &r, sizeof r) != (ssize_t)sizeof r) {
		perror("legendpick: /dev/urandom");
		exit(1);
	}
	return r;
}

/* Uniform in [0, n) via rejection sampling (no modulo bias). */
static unsigned long uniform(unsigned long n)
{
	unsigned long limit = ULONG_MAX - (ULONG_MAX % n), r;
	do {
		r = rand_word();
	} while (r >= limit);
	return r % n;
}

static void push(char ***a, size_t *n, size_t *cap, char *s)
{
	if (*n == *cap) {
		*cap = *cap ? *cap * 2 : 16;
		*a = realloc(*a, *cap * sizeof **a);
		if (!*a) {
			fprintf(stderr, "legendpick: out of memory\n");
			exit(1);
		}
	}
	(*a)[(*n)++] = s;
}

int main(int argc, char **argv)
{
	int k = 1;
	char **items = NULL;
	size_t n = 0, cap = 0;
	int have_items = 0;

	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-n") && i + 1 < argc) {
			k = atoi(argv[++i]);
		} else if (argv[i][0] == '-' && argv[i][1]) {
			fprintf(stderr, "usage: %s [-n count] item item ...   "
				"(or pipe lines in)\n", argv[0]);
			return 2;
		} else {
			push(&items, &n, &cap, argv[i]); /* item straight from argv */
			have_items = 1;
		}
	}
	if (k < 1) {
		fprintf(stderr, "legendpick: count must be >= 1\n");
		return 2;
	}

	if (!have_items) {
		if (isatty(STDIN_FILENO)) {
			fprintf(stderr, "usage: %s [-n count] item item ...   "
				"(or pipe lines in)\n", argv[0]);
			return 2;
		}
		char *line = NULL;
		size_t lc = 0;
		ssize_t len;
		while ((len = getline(&line, &lc, stdin)) != -1) {
			if (len && line[len - 1] == '\n')
				line[--len] = '\0';
			push(&items, &n, &cap, strdup(line));
		}
		free(line);
	}
	if (n == 0)
		return 0;

	urandom = open("/dev/urandom", O_RDONLY);
	if (urandom < 0) {
		perror("legendpick: open /dev/urandom");
		return 1;
	}

	/* Partial Fisher-Yates: shuffle the first `out` slots, print them. */
	size_t out = (size_t)k < n ? (size_t)k : n;
	for (size_t i = 0; i < out; i++) {
		size_t j = i + uniform(n - i);
		char *t = items[i];
		items[i] = items[j];
		items[j] = t;
		puts(items[i]);
	}
	return 0;
}
