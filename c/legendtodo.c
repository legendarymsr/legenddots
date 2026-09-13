/* legendtodo — a plain-text todo list, in C.
 *
 * "Reject Electron. Return to C."
 *
 * Your tasks are just lines in a file ($LEGENDTODO, or ~/.legendtodo) —
 * greppable, editable by hand, syncable however you like. No database, no
 * daemon, no libraries. Each line is `[ ] task` or `[x] task`.
 *
 *   legendtodo                 list tasks (same as `ls`)
 *   legendtodo add buy milk    append a task
 *   legendtodo done 2          mark task 2 complete
 *   legendtodo undone 2        mark task 2 incomplete again
 *   legendtodo rm 2            delete task 2
 *   legendtodo clear           remove all completed tasks
 *
 * Build:  cc -std=c99 -Os -o legendtodo legendtodo.c    (see c/Makefile)
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define DIM   "\x1b[2m"
#define RESET "\x1b[0m"

static char **texts;
static int  *dones;
static size_t n_tasks, cap;

/* Path to the task file: $LEGENDTODO, else $HOME/.legendtodo, else ./.legendtodo */
static const char *todo_path(void)
{
	static char path[1024];
	const char *env = getenv("LEGENDTODO");
	const char *home = getenv("HOME");

	if (env && *env)
		snprintf(path, sizeof path, "%s", env);
	else if (home && *home)
		snprintf(path, sizeof path, "%s/.legendtodo", home);
	else
		snprintf(path, sizeof path, ".legendtodo");
	return path;
}

static void push(int done, const char *text)
{
	if (n_tasks == cap) {
		cap = cap ? cap * 2 : 16;
		texts = realloc(texts, cap * sizeof *texts);
		dones = realloc(dones, cap * sizeof *dones);
		if (!texts || !dones) {
			fprintf(stderr, "legendtodo: out of memory\n");
			exit(1);
		}
	}
	texts[n_tasks] = strdup(text);
	dones[n_tasks] = done;
	n_tasks++;
}

static void load(void)
{
	FILE *f = fopen(todo_path(), "r");
	char *line = NULL;
	size_t sz = 0;
	ssize_t len;

	if (!f)
		return; /* no file yet == empty list */
	while ((len = getline(&line, &sz, f)) != -1) {
		if (len && line[len - 1] == '\n')
			line[--len] = '\0';
		if (len == 0)
			continue;
		if (!strncmp(line, "[x] ", 4))
			push(1, line + 4);
		else if (!strncmp(line, "[ ] ", 4))
			push(0, line + 4);
		else
			push(0, line); /* tolerate hand-edited lines */
	}
	free(line);
	fclose(f);
}

static void save(void)
{
	FILE *f = fopen(todo_path(), "w");
	if (!f) {
		perror("legendtodo: cannot write task file");
		exit(1);
	}
	for (size_t i = 0; i < n_tasks; i++)
		fprintf(f, "[%c] %s\n", dones[i] ? 'x' : ' ', texts[i]);
	fclose(f);
}

static void list(void)
{
	size_t left = 0;
	if (n_tasks == 0) {
		printf("  no tasks — add one with `legendtodo add ...`\n");
		return;
	}
	for (size_t i = 0; i < n_tasks; i++) {
		if (dones[i])
			printf("  " DIM "%2zu  [x] %s" RESET "\n", i + 1, texts[i]);
		else {
			printf("  %2zu  [ ] %s\n", i + 1, texts[i]);
			left++;
		}
	}
	printf("  " DIM "%zu done, %zu left" RESET "\n", n_tasks - left, left);
}

/* Parse a 1-based task number argument into a valid index, or exit. */
static size_t require_index(const char *arg)
{
	char *end;
	long v = strtol(arg, &end, 10);
	if (*end || v < 1 || (size_t)v > n_tasks) {
		fprintf(stderr, "legendtodo: no task #%s\n", arg);
		exit(2);
	}
	return (size_t)v - 1;
}

/* Join argv[from..argc) into one space-separated string (caller frees). */
static char *join(int from, int argc, char **argv)
{
	size_t len = 1;
	for (int i = from; i < argc; i++)
		len += strlen(argv[i]) + 1;
	char *s = calloc(1, len);
	if (!s) {
		fprintf(stderr, "legendtodo: out of memory\n");
		exit(1);
	}
	for (int i = from; i < argc; i++) {
		if (i > from)
			strcat(s, " ");
		strcat(s, argv[i]);
	}
	return s;
}

int main(int argc, char **argv)
{
	const char *cmd = argc > 1 ? argv[1] : "ls";

	load();

	if (!strcmp(cmd, "ls") || !strcmp(cmd, "list")) {
		list();
	} else if (!strcmp(cmd, "add")) {
		if (argc < 3) {
			fprintf(stderr, "usage: legendtodo add <task text>\n");
			return 2;
		}
		char *t = join(2, argc, argv);
		push(0, t);
		free(t);
		save();
		list();
	} else if (!strcmp(cmd, "done") && argc == 3) {
		dones[require_index(argv[2])] = 1;
		save();
		list();
	} else if (!strcmp(cmd, "undone") && argc == 3) {
		dones[require_index(argv[2])] = 0;
		save();
		list();
	} else if (!strcmp(cmd, "rm") && argc == 3) {
		size_t idx = require_index(argv[2]);
		free(texts[idx]);
		for (size_t i = idx; i + 1 < n_tasks; i++) {
			texts[i] = texts[i + 1];
			dones[i] = dones[i + 1];
		}
		n_tasks--;
		save();
		list();
	} else if (!strcmp(cmd, "clear")) {
		size_t w = 0;
		for (size_t i = 0; i < n_tasks; i++) {
			if (dones[i])
				free(texts[i]);
			else {
				texts[w] = texts[i];
				dones[w] = dones[i];
				w++;
			}
		}
		n_tasks = w;
		save();
		list();
	} else {
		fprintf(stderr,
			"usage: legendtodo [ls | add <text> | done N | undone N | rm N | clear]\n"
			"  (no args)      list tasks\n"
			"  add <text>     append a task\n"
			"  done N         mark task N complete\n"
			"  undone N       mark task N incomplete\n"
			"  rm N           delete task N\n"
			"  clear          remove all completed tasks\n"
			"file: %s  (override with $LEGENDTODO)\n",
			todo_path());
		return 2;
	}
	return 0;
}
