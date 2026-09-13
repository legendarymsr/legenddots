/* legendcolors — a terminal color palette tester, in C.
 *
 * "Reject Electron. Return to C."
 *
 * Prints the terminal's 16 ANSI colors, the 256-color cube + grayscale ramp,
 * and a 24-bit truecolor gradient, so you can eyeball a theme (Tokyo Night,
 * say) and confirm what your terminal actually renders. Pure ANSI escapes,
 * no libraries.
 *
 *   legendcolors           show every section
 *   legendcolors -16       just the 16 ANSI colors
 *   legendcolors -256      just the 256-color cube
 *   legendcolors -t        just the truecolor gradient
 *
 * Build:  cc -std=c99 -Os -o legendcolors legendcolors.c    (see c/Makefile)
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <string.h>

#define RESET "\x1b[0m"

static void ansi16(void)
{
	printf("  16 ANSI colors (foreground on default, then as background):\n  ");
	for (int i = 0; i < 16; i++) {
		printf("\x1b[38;5;%dm %3d " RESET, i, i);
		if (i == 7)
			printf("\n  ");
	}
	printf("\n  ");
	for (int i = 0; i < 16; i++) {
		int fg = (i == 0 || i == 8) ? 15 : 0; /* keep labels legible */
		printf("\x1b[48;5;%dm\x1b[38;5;%dm %3d " RESET, i, fg, i);
		if (i == 7)
			printf("\n  ");
	}
	printf("\n");
}

static void cube256(void)
{
	printf("  256-color cube (16-231) + grayscale ramp (232-255):\n");
	for (int i = 16; i < 232; i++) {
		if ((i - 16) % 36 == 0)
			printf("  ");
		printf("\x1b[48;5;%dm  " RESET, i);
		if ((i - 15) % 36 == 0)
			printf("\n");
	}
	printf("  ");
	for (int i = 232; i < 256; i++)
		printf("\x1b[48;5;%dm  " RESET, i);
	printf("\n");
}

static void truecolor(void)
{
	printf("  24-bit truecolor gradient (if your terminal supports it):\n  ");
	for (int i = 0; i < 76; i++) {
		/* sweep hue across the row */
		double h = i / 76.0 * 6.0;
		int x = (int)(255 * (1 - (h - (int)h)));
		int y = (int)(255 * (h - (int)h));
		int r, g, b;
		switch ((int)h % 6) {
		case 0: r = 255; g = y;   b = 0;   break;
		case 1: r = x;   g = 255; b = 0;   break;
		case 2: r = 0;   g = 255; b = y;   break;
		case 3: r = 0;   g = x;   b = 255; break;
		case 4: r = y;   g = 0;   b = 255; break;
		default: r = 255; g = 0;  b = x;   break;
		}
		printf("\x1b[48;2;%d;%d;%dm " RESET, r, g, b);
	}
	printf("\n");
}

int main(int argc, char **argv)
{
	int only16 = 0, only256 = 0, onlytc = 0;

	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-16"))
			only16 = 1;
		else if (!strcmp(argv[i], "-256"))
			only256 = 1;
		else if (!strcmp(argv[i], "-t"))
			onlytc = 1;
		else {
			fprintf(stderr,
				"usage: %s [-16 | -256 | -t]\n"
				"  (no args)  show all sections\n"
				"  -16        16 ANSI colors\n"
				"  -256       256-color cube + grayscale\n"
				"  -t         24-bit truecolor gradient\n",
				argv[0]);
			return 2;
		}
	}
	int all = !(only16 || only256 || onlytc);

	if (all || only16)  { ansi16();    if (all) putchar('\n'); }
	if (all || only256) { cube256();   if (all) putchar('\n'); }
	if (all || onlytc)  { truecolor(); }
	return 0;
}
