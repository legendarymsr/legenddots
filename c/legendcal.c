/* legendcal — a pocket month calendar, in C.
 *
 * "Reject Electron. Return to C."
 *
 *   legendcal            this month, today highlighted
 *   legendcal 2026 9     September 2026
 *
 * Pure libc (time.h); no libraries.
 *
 * Build:  cc -std=c99 -Os -o legendcal legendcal.c    (see c/Makefile)
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static const char *MONTHS[] = {
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December"
};

int main(int argc, char **argv)
{
	time_t t = time(NULL);
	struct tm now;
	localtime_r(&t, &now);

	int year = now.tm_year + 1900, month = now.tm_mon + 1;
	if (argc == 3) {
		year = atoi(argv[1]);
		month = atoi(argv[2]);
	} else if (argc != 1) {
		fprintf(stderr, "usage: %s [year month]\n", argv[0]);
		return 2;
	}
	if (month < 1 || month > 12) {
		fprintf(stderr, "legendcal: month must be 1-12\n");
		return 2;
	}

	/* Weekday of the 1st (0 = Sunday), via mktime normalization. */
	struct tm d;
	memset(&d, 0, sizeof d);
	d.tm_year = year - 1900;
	d.tm_mon = month - 1;
	d.tm_mday = 1;
	d.tm_hour = 12;
	mktime(&d);
	int first_wday = d.tm_wday;

	int dim[] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
	int leap = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
	int days = (month == 2 && leap) ? 29 : dim[month - 1];

	char title[64];
	int n = snprintf(title, sizeof title, "%s %d", MONTHS[month - 1], year);
	printf("%*s%s\n", (20 - n) / 2, "", title);
	printf("Su Mo Tu We Th Fr Sa\n");

	int col = 0;
	for (int i = 0; i < first_wday; i++, col++)
		printf("   ");
	for (int day = 1; day <= days; day++) {
		int is_today = year == now.tm_year + 1900 &&
			       month == now.tm_mon + 1 && day == now.tm_mday;
		if (is_today)
			printf("\x1b[7m%2d\x1b[0m ", day);
		else
			printf("%2d ", day);
		if (++col == 7) {
			col = 0;
			putchar('\n');
		}
	}
	if (col != 0)
		putchar('\n');
	return 0;
}
