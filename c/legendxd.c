/* legendxd — a hex viewer, in C.
 *
 * "Reject Electron. Return to C."
 *
 * `hexdump -C`-style output: offset, 16 bytes of hex in two columns of eight,
 * and an ASCII gutter (non-printables shown as '.'). Reads a file argument or,
 * with none, standard input. No libraries.
 *
 *   legendxd file.bin
 *   some-command | legendxd
 *   legendxd < /bin/ls | head
 *
 * Build:  cc -std=c99 -Os -o legendxd legendxd.c    (see c/Makefile)
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <string.h>

#define WIDTH 16

static void dump(FILE *f)
{
	unsigned char buf[WIDTH];
	size_t off = 0, got;

	while ((got = fread(buf, 1, WIDTH, f)) > 0) {
		printf("%08zx  ", off);
		for (size_t i = 0; i < WIDTH; i++) {
			if (i < got)
				printf("%02x ", buf[i]);
			else
				printf("   ");
			if (i == WIDTH / 2 - 1)
				putchar(' '); /* gap between the two columns */
		}
		printf(" |");
		for (size_t i = 0; i < got; i++)
			putchar((buf[i] >= 0x20 && buf[i] < 0x7f) ? buf[i] : '.');
		printf("|\n");
		off += got;
	}
	printf("%08zx\n", off); /* final offset == total length, like hexdump -C */
}

int main(int argc, char **argv)
{
	if (argc > 2) {
		fprintf(stderr, "usage: %s [file]   (reads stdin if no file)\n", argv[0]);
		return 2;
	}
	if (argc == 2 && strcmp(argv[1], "-") != 0) {
		FILE *f = fopen(argv[1], "rb");
		if (!f) {
			perror(argv[1]);
			return 1;
		}
		dump(f);
		fclose(f);
	} else {
		dump(stdin);
	}
	return 0;
}
