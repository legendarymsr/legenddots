/* legendpick — pick random lines from stdin, in C.
 *
 * "Reject Electron. Return to C."
 *
 * Reservoir sampling with kernel randomness (/dev/urandom, never rand()), so
 * it picks uniformly from a stream of any size without loading it all or
 * needing a rewind. No libraries.
 *
 *   ls | legendpick            one random file
 *   legendpick -n 3 < list.txt three random lines
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

int main(int argc, char **argv)
{
	int k = 1;
	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-n") && i + 1 < argc) {
			k = atoi(argv[++i]);
		} else {
			fprintf(stderr, "usage: %s [-n count]   (reads lines on stdin)\n",
				argv[0]);
			return 2;
		}
	}
	if (k < 1) {
		fprintf(stderr, "legendpick: count must be >= 1\n");
		return 2;
	}

	urandom = open("/dev/urandom", O_RDONLY);
	if (urandom < 0) {
		perror("legendpick: open /dev/urandom");
		return 1;
	}

	char **res = calloc((size_t)k, sizeof *res);
	if (!res) {
		fprintf(stderr, "legendpick: out of memory\n");
		return 1;
	}
	char *line = NULL;
	size_t cap = 0, seen = 0;
	ssize_t len;
	while ((len = getline(&line, &cap, stdin)) != -1) {
		if (len && line[len - 1] == '\n')
			line[--len] = '\0';
		if (seen < (size_t)k) {
			res[seen] = strdup(line);
		} else {
			unsigned long j = uniform(seen + 1);
			if (j < (size_t)k) {
				free(res[j]);
				res[j] = strdup(line);
			}
		}
		seen++;
	}
	free(line);
	close(urandom);

	size_t out = seen < (size_t)k ? seen : (size_t)k;
	for (size_t i = 0; i < out; i++)
		puts(res[i]);
	return 0;
}
