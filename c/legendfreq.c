/* legendfreq — frequency count, in C.
 *
 * "Reject Electron. Return to C."
 *
 * Count how often each item appears, most-frequent first, with a little bar.
 * Give the items on the command line, or pipe lines in. No libraries.
 *
 *   legendfreq apple banana apple cherry apple
 *   awk '{print $1}' access.log | legendfreq | head
 *
 * Build:  cc -std=c99 -Os -o legendfreq legendfreq.c    (see c/Makefile)
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

struct pair { char *s; size_t n; };

static int cmp_str(const void *a, const void *b)
{
	return strcmp(*(char *const *)a, *(char *const *)b);
}

/* Most frequent first; ties broken alphabetically. */
static int cmp_pair(const void *a, const void *b)
{
	const struct pair *x = a, *y = b;
	if (x->n != y->n)
		return x->n < y->n ? 1 : -1;
	return strcmp(x->s, y->s);
}

static void push(char ***a, size_t *n, size_t *cap, char *s)
{
	if (*n == *cap) {
		*cap = *cap ? *cap * 2 : 64;
		*a = realloc(*a, *cap * sizeof **a);
		if (!*a) {
			fprintf(stderr, "legendfreq: out of memory\n");
			exit(1);
		}
	}
	(*a)[(*n)++] = s;
}

int main(int argc, char **argv)
{
	char **lines = NULL, *line = NULL;
	size_t n = 0, cap = 0, lc = 0;
	ssize_t len;
	int have_args = 0;

	for (int i = 1; i < argc; i++) {
		if (argv[i][0] == '-' && argv[i][1]) {
			fprintf(stderr, "usage: %s item item ...   (or pipe lines in)\n",
				argv[0]);
			return 2;
		}
		push(&lines, &n, &cap, argv[i]); /* item straight from argv */
		have_args = 1;
	}

	if (!have_args) {
		if (isatty(STDIN_FILENO)) {
			fprintf(stderr, "usage: %s item item ...   (or pipe lines in)\n",
				argv[0]);
			return 2;
		}
		while ((len = getline(&line, &lc, stdin)) != -1) {
			if (len && line[len - 1] == '\n')
				line[--len] = '\0';
			push(&lines, &n, &cap, strdup(line));
		}
		free(line);
	}
	if (n == 0)
		return 0;

	qsort(lines, n, sizeof *lines, cmp_str);

	struct pair *p = malloc(n * sizeof *p);
	size_t np = 0;
	for (size_t i = 0; i < n;) {
		size_t j = i + 1;
		while (j < n && !strcmp(lines[i], lines[j]))
			j++;
		p[np].s = lines[i];
		p[np].n = j - i;
		np++;
		i = j;
	}
	qsort(p, np, sizeof *p, cmp_pair);

	size_t max = p[0].n;
	for (size_t i = 0; i < np; i++) {
		int bar = (int)(p[i].n * 24 / max);
		printf("%7zu ", p[i].n);
		for (int b = 0; b < bar; b++)
			fputs("█", stdout);
		printf(" %s\n", p[i].s);
	}
	return 0;
}
