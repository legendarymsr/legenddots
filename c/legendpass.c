/* legendpass — a secure password generator (with optional GnuPG store), in C.
 *
 * "Reject Electron. Return to C."
 *
 * Randomness comes straight from the kernel CSPRNG (/dev/urandom) — never
 * rand()/srand(), which are not cryptographically secure. Characters are
 * drawn with rejection sampling so every character in the set is equally
 * likely (naive `byte % setlen` is biased when 256 isn't a multiple of the
 * set size).
 *
 * With -S it saves the generated password GPG-encrypted on disk (the same
 * public-key model `pass` uses): encrypting needs only your public key, so
 * there is no passphrase prompt when saving; -g decrypts one back. This is
 * the only part that shells out — to `gpg`; generation itself has no deps.
 *
 *   legendpass                 one 20-char alphanumeric password
 *   legendpass -l 32 -n 5      five 32-char passwords
 *   legendpass -s -x           symbols, minus ambiguous chars
 *   legendpass -S github       generate one and save ~/.legendpass/github.gpg
 *   legendpass -g github       decrypt and print that saved password
 *   legendpass -L              list saved names
 *
 * Build:  cc -std=c99 -Os -o legendpass legendpass.c -lm   (see c/Makefile)
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <fcntl.h>
#include <math.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/wait.h>

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
	if (read(urandom, &c, 1) != 1) {
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

/* The encrypted store directory: $LEGENDPASS_DIR, else ~/.legendpass. */
static const char *store_dir(void)
{
	static char dir[512];
	const char *env = getenv("LEGENDPASS_DIR");
	const char *home = getenv("HOME");
	if (env && *env)
		snprintf(dir, sizeof dir, "%s", env);
	else if (home && *home)
		snprintf(dir, sizeof dir, "%s/.legendpass", home);
	else
		snprintf(dir, sizeof dir, ".legendpass");
	return dir;
}

/* Reject names that could escape the store or confuse gpg. */
static int safe_name(const char *s)
{
	if (!*s || *s == '-' || *s == '.')
		return 0;
	for (const char *p = s; *p; p++)
		if (!(isalnum((unsigned char)*p) || strchr("_-.@", *p)))
			return 0;
	return 1;
}

/* Encrypt `pw` to `path` for `recipient` via gpg. 0 on success. */
static int save_encrypted(const char *pw, const char *path, const char *recipient)
{
	int fds[2];
	if (pipe(fds) != 0) {
		perror("legendpass: pipe");
		return -1;
	}
	pid_t pid = fork();
	if (pid < 0) {
		perror("legendpass: fork");
		return -1;
	}
	if (pid == 0) {
		dup2(fds[0], STDIN_FILENO);
		close(fds[0]);
		close(fds[1]);
		execlp("gpg", "gpg", "--batch", "--yes", "--encrypt",
		       "--recipient", recipient, "--output", path, (char *)NULL);
		perror("legendpass: gpg (is gnupg installed?)");
		_exit(127);
	}
	close(fds[0]);
	for (size_t off = 0, n = strlen(pw); off < n;) {
		ssize_t w = write(fds[1], pw + off, n - off);
		if (w <= 0)
			break;
		off += (size_t)w;
	}
	close(fds[1]);
	int st;
	waitpid(pid, &st, 0);
	return (WIFEXITED(st) && WEXITSTATUS(st) == 0) ? 0 : -1;
}

/* Print the saved names (files ending .gpg, suffix stripped). */
static int list_store(void)
{
	DIR *d = opendir(store_dir());
	if (!d)
		return 0; /* no store yet == nothing saved */
	struct dirent *e;
	while ((e = readdir(d))) {
		size_t n = strlen(e->d_name);
		if (n > 4 && !strcmp(e->d_name + n - 4, ".gpg")) {
			e->d_name[n - 4] = '\0';
			puts(e->d_name);
		}
	}
	closedir(d);
	return 0;
}

static void usage(const char *me)
{
	fprintf(stderr,
		"usage: %s [-l len] [-n count] [-s] [-x] [-e]\n"
		"       %s -S name [-l len] [-s] [-x] [-r gpgkey]   save one, encrypted\n"
		"       %s -g name                                  print a saved one\n"
		"       %s -L                                       list saved names\n"
		"  -l N     length (default 20)      -n N   how many (default 1)\n"
		"  -s       include symbols          -x     drop ambiguous chars\n"
		"  -e       print entropy to stderr\n"
		"  -S name  generate one and GPG-encrypt it to $LEGENDPASS_DIR (or\n"
		"           ~/.legendpass)/name.gpg; also prints it once\n"
		"  -g name  decrypt and print that saved password\n"
		"  -L       list saved names\n"
		"  -r key   GPG recipient for -S (else $LEGENDPASS_GPG_KEY)\n",
		me, me, me, me);
}

int main(int argc, char **argv)
{
	int length = 20, count = 1, symbols = 0, no_ambig = 0, show_entropy = 0;
	const char *save_name = NULL, *get_name = NULL, *recipient = NULL;
	int do_list = 0;
	char set[128];
	int setlen = 0;

	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-l") && i + 1 < argc)
			length = atoi(argv[++i]);
		else if (!strcmp(argv[i], "-n") && i + 1 < argc)
			count = atoi(argv[++i]);
		else if (!strcmp(argv[i], "-s"))
			symbols = 1;
		else if (!strcmp(argv[i], "-x"))
			no_ambig = 1;
		else if (!strcmp(argv[i], "-e"))
			show_entropy = 1;
		else if (!strcmp(argv[i], "-S") && i + 1 < argc)
			save_name = argv[++i];
		else if (!strcmp(argv[i], "-g") && i + 1 < argc)
			get_name = argv[++i];
		else if (!strcmp(argv[i], "-r") && i + 1 < argc)
			recipient = argv[++i];
		else if (!strcmp(argv[i], "-L"))
			do_list = 1;
		else {
			usage(argv[0]);
			return 2;
		}
	}

	/* --- retrieve / list: no generation needed --- */
	if (do_list)
		return list_store();
	if (get_name) {
		if (!safe_name(get_name)) {
			fprintf(stderr, "legendpass: bad name '%s'\n", get_name);
			return 2;
		}
		char path[700];
		snprintf(path, sizeof path, "%s/%s.gpg", store_dir(), get_name);
		execlp("gpg", "gpg", "--quiet", "--decrypt", path, (char *)NULL);
		perror("legendpass: gpg (is gnupg installed?)");
		return 127;
	}

	if (length < 1 || count < 1) {
		fprintf(stderr, "legendpass: length and count must be >= 1\n");
		return 2;
	}
	if (save_name && !safe_name(save_name)) {
		fprintf(stderr, "legendpass: bad name '%s' "
			"(use letters, digits, . _ - @)\n", save_name);
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

	if (save_name) {
		/* Generate one and save it GPG-encrypted. */
		if (!recipient || !*recipient)
			recipient = getenv("LEGENDPASS_GPG_KEY");
		if (!recipient || !*recipient) {
			fprintf(stderr,
				"legendpass: -S needs a GPG recipient (your own key).\n"
				"  set one:  export LEGENDPASS_GPG_KEY=you@example.com\n"
				"  or pass:  legendpass -S %s -r you@example.com\n"
				"  no key?   gpg --quick-generate-key \"You <you@example.com>\"\n",
				save_name);
			return 2;
		}
		char *pw = malloc((size_t)length + 1);
		if (!pw) {
			fprintf(stderr, "legendpass: out of memory\n");
			return 1;
		}
		for (int i = 0; i < length; i++)
			pw[i] = set[uniform(setlen)];
		pw[length] = '\0';
		close(urandom);

		mkdir(store_dir(), 0700); /* ok if it already exists */
		char path[700];
		snprintf(path, sizeof path, "%s/%s.gpg", store_dir(), save_name);
		if (save_encrypted(pw, path, recipient) != 0) {
			fprintf(stderr, "legendpass: gpg encryption failed "
				"(bad key '%s'?)\n", recipient);
			free(pw);
			return 1;
		}
		fprintf(stderr, "legendpass: saved encrypted to %s\n", path);
		puts(pw); /* show it once so you can use it now */
		free(pw);
	} else {
		for (int p = 0; p < count; p++) {
			for (int i = 0; i < length; i++)
				putchar(set[uniform(setlen)]);
			putchar('\n');
		}
		close(urandom);
	}

	if (show_entropy)
		fprintf(stderr, "%d chars from a set of %d = %.0f bits of entropy\n",
			length, setlen, length * log2((double)setlen));
	return 0;
}
