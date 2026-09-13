/* legendfreq — frequency count of stdin lines, in C.
 *
 * "Reject Electron. Return to C."
 *
 * `sort | uniq -c | sort -rn` in one tool, with a little bar per line — hand
 * it a log and see the top offenders at a glance. No libraries.
 *
 *   legendfreq access.log
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

int main(int argc, char **argv)
{
	char **lines = NULL, *line = NULL;
	size_t n = 0, cap = 0, lc = 0;
	ssize_t len;
	FILE *in = stdin;

	if (argc == 2 && argv[1][0] != '-') {
		in = fopen(argv[1], "r");
		if (!in) {
			perror(argv[1]);
			return 1;
		}
	} else if (argc != 1) {
		fprintf(stderr, "usage: %s [file]   (else reads stdin)\n", argv[0]);
		return 2;
	} else if (isatty(STDIN_FILENO)) {
		fprintf(stderr, "legendfreq: give a file or pipe lines in\n");
		return 2;
	}
	while ((len = getline(&line, &lc, in)) != -1) {
		if (len && line[len - 1] == '\n')
			line[--len] = '\0';
		if (n == cap) {
			cap = cap ? cap * 2 : 64;
			lines = realloc(lines, cap * sizeof *lines);
			if (!lines) {
				fprintf(stderr, "legendfreq: out of memory\n");
				return 1;
			}
		}
		lines[n++] = strdup(line);
	}
	free(line);
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
