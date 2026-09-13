/* legendpass — a secure password generator, in C.
 *
 * "Reject Electron. Return to C."
 *
 * Randomness comes straight from the kernel CSPRNG (/dev/urandom) — never
 * rand()/srand(), which are not cryptographically secure. Characters are
 * drawn with rejection sampling so every character in the set is equally
 * likely (naive `byte % setlen` is biased when 256 isn't a multiple of the
 * set size). No libraries.
 *
 *   legendpass                 one 20-char alphanumeric password
 *   legendpass -l 32 -n 5      five 32-char passwords
 *   legendpass -s              include symbols
 *   legendpass -x              exclude ambiguous chars (O0oIl1|`'")
 *   legendpass -e              also print entropy (bits) to stderr
 *
 * Build:  cc -std=c99 -Os -o legendpass legendpass.c    (see c/Makefile)
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <math.h>

static const char LOWER[] = "abcdefghijklmnopqrstuvwxyz";
static const char UPPER[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
static const char DIGIT[] = "0123456789";
static const char SYMBOL[] = "!@#$%^&*()-_=+[]{};:,.?/";
static const char AMBIG[] = "O0oIl1|`'\"";

static int urandom = -1;

/* One random byte from the kernel CSPRNG, or die. */
static unsigned char rbyte(void)
{
	unsigned char c;
	ssize_t r = read(urandom, &c, 1);
	if (r != 1) {
		perror("legendpass: /dev/urandom");
		exit(1);
	}
	return c;
}

/* Uniform index in [0, len) via rejection sampling (no modulo bias). */
static int uniform(int len)
{
	int limit = 256 - (256 % len);
	unsigned char b;
	do {
		b = rbyte();
	} while (b >= limit);
	return b % len;
}

int main(int argc, char **argv)
{
	int length = 20, count = 1, symbols = 0, no_ambig = 0, show_entropy = 0;
	char set[128];
	int setlen = 0;

	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-l") && i + 1 < argc) {
			length = atoi(argv[++i]);
		} else if (!strcmp(argv[i], "-n") && i + 1 < argc) {
			count = atoi(argv[++i]);
		} else if (!strcmp(argv[i], "-s")) {
			symbols = 1;
		} else if (!strcmp(argv[i], "-x")) {
			no_ambig = 1;
		} else if (!strcmp(argv[i], "-e")) {
			show_entropy = 1;
		} else {
			fprintf(stderr,
				"usage: %s [-l length] [-n count] [-s] [-x] [-e]\n"
				"  -l N   password length (default 20)\n"
				"  -n N   how many to generate (default 1)\n"
				"  -s     include symbols (%s)\n"
				"  -x     exclude ambiguous chars (%s)\n"
				"  -e     print entropy in bits to stderr\n",
				argv[0], SYMBOL, AMBIG);
			return 2;
		}
	}
	if (length < 1 || count < 1) {
		fprintf(stderr, "legendpass: length and count must be >= 1\n");
		return 2;
	}

	/* Build the character set from the selected classes. */
	const char *classes[] = { LOWER, UPPER, DIGIT, symbols ? SYMBOL : "" };
	for (size_t c = 0; c < sizeof classes / sizeof *classes; c++)
		for (const char *p = classes[c]; *p; p++) {
			if (no_ambig && strchr(AMBIG, *p))
				continue;
			if (setlen < (int)sizeof set - 1)
				set[setlen++] = *p;
		}
	set[setlen] = '\0';
	if (setlen < 2) {
		fprintf(stderr, "legendpass: character set too small\n");
		return 2;
	}

	urandom = open("/dev/urandom", O_RDONLY);
	if (urandom < 0) {
		perror("legendpass: open /dev/urandom");
		return 1;
	}

	for (int p = 0; p < count; p++) {
		for (int i = 0; i < length; i++)
			putchar(set[uniform(setlen)]);
		putchar('\n');
	}
	close(urandom);

	if (show_entropy)
		fprintf(stderr, "%d chars from a set of %d = %.0f bits of entropy\n",
			length, setlen, length * log2((double)setlen));
	return 0;
}
