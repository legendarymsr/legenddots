/* legendserve — a minimal static HTTP file server, in C.
 *
 * "Reject Electron. Return to C."
 *
 * A no-Python, no-Node `http.server`: serve a directory over HTTP for quick
 * local testing. Binds 127.0.0.1 by DEFAULT (localhost only) — pass
 * `-b 0.0.0.0` to expose it on the network deliberately. GET/HEAD only,
 * one connection at a time, with directory listings and a small MIME table.
 * Only POSIX sockets; no libraries.
 *
 *   legendserve                    serve ./ on 127.0.0.1:8000
 *   legendserve -p 8080 public     serve ./public on port 8080
 *   legendserve -b 0.0.0.0 -p 80   expose on all interfaces (intentional)
 *
 * Requests are confined to the served directory: the resolved path of every
 * request must stay inside it (realpath check), so `..` and symlink escapes
 * are refused with 403.
 *
 * Build:  cc -std=c99 -Os -o legendserve legendserve.c    (see c/Makefile)
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <signal.h>
#include <limits.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

static char root[PATH_MAX];     /* canonical document root */

/* Map a file extension to a MIME type (default: octet-stream). */
static const char *mime(const char *path)
{
	const char *dot = strrchr(path, '.');
	if (!dot)
		return "application/octet-stream";
	static const struct { const char *ext, *type; } t[] = {
		{ ".html", "text/html; charset=utf-8" },
		{ ".htm",  "text/html; charset=utf-8" },
		{ ".css",  "text/css; charset=utf-8" },
		{ ".js",   "text/javascript; charset=utf-8" },
		{ ".json", "application/json" },
		{ ".txt",  "text/plain; charset=utf-8" },
		{ ".md",   "text/plain; charset=utf-8" },
		{ ".xml",  "application/xml" },
		{ ".svg",  "image/svg+xml" },
		{ ".png",  "image/png" },
		{ ".jpg",  "image/jpeg" },
		{ ".jpeg", "image/jpeg" },
		{ ".gif",  "image/gif" },
		{ ".ico",  "image/x-icon" },
		{ ".webp", "image/webp" },
		{ ".pdf",  "application/pdf" },
		{ ".wasm", "application/wasm" },
	};
	for (size_t i = 0; i < sizeof t / sizeof *t; i++)
		if (!strcasecmp(dot, t[i].ext))
			return t[i].type;
	return "application/octet-stream";
}

/* Decode %xx escapes in a URL path in place; drop any query string. */
static void url_decode(char *s)
{
	char *q = strchr(s, '?');
	if (q)
		*q = '\0';
	char *w = s;
	for (char *r = s; *r; r++) {
		if (*r == '%' && r[1] && r[2]) {
			int hi = r[1], lo = r[2];
			hi = (hi >= 'a') ? hi - 'a' + 10 : (hi >= 'A') ? hi - 'A' + 10 : hi - '0';
			lo = (lo >= 'a') ? lo - 'a' + 10 : (lo >= 'A') ? lo - 'A' + 10 : lo - '0';
			*w++ = (char)((hi << 4) | lo);
			r += 2;
		} else {
			*w++ = *r;
		}
	}
	*w = '\0';
}

static void send_all(int fd, const char *buf, size_t n)
{
	while (n > 0) {
		ssize_t w = write(fd, buf, n);
		if (w <= 0)
			return;
		buf += w;
		n -= (size_t)w;
	}
}

static void send_status(int fd, int head, int code, const char *msg, const char *body)
{
	char hdr[512];
	size_t blen = body ? strlen(body) : 0;
	int hlen = snprintf(hdr, sizeof hdr,
		"HTTP/1.0 %d %s\r\n"
		"Content-Type: text/html; charset=utf-8\r\n"
		"Content-Length: %zu\r\n"
		"Connection: close\r\n\r\n",
		code, msg, blen);
	send_all(fd, hdr, (size_t)hlen);
	if (!head && body)
		send_all(fd, body, blen);
}

/* Emit an HTML directory listing for `dirpath` (URL path `urlpath`). */
static void send_listing(int fd, int head, const char *dirpath, const char *urlpath)
{
	struct dirent **ents;
	int n = scandir(dirpath, &ents, NULL, alphasort);
	if (n < 0) {
		send_status(fd, head, 500, "Internal Server Error", "<h1>500</h1>");
		return;
	}
	/* Build the body in a growable buffer. */
	size_t cap = 4096, len = 0;
	char *body = malloc(cap);
	if (!body) {
		while (n--) free(ents[n]);
		free(ents);
		send_status(fd, head, 500, "Internal Server Error", "<h1>500</h1>");
		return;
	}
	len += (size_t)snprintf(body + len, cap - len,
		"<!doctype html><meta charset=utf-8><title>%s</title>"
		"<h1>Index of %s</h1><ul>", urlpath, urlpath);
	for (int i = 0; i < n; i++) {
		const char *name = ents[i]->d_name;
		if (strcmp(name, ".") != 0) {
			if (cap - len < 1024) {
				cap *= 2;
				char *nb = realloc(body, cap);
				if (!nb) break;
				body = nb;
			}
			len += (size_t)snprintf(body + len, cap - len,
				"<li><a href=\"%s\">%s</a></li>", name, name);
		}
		free(ents[i]);
	}
	free(ents);
	len += (size_t)snprintf(body + len, cap - len, "</ul>");
	send_status(fd, head, 200, "OK", body);
	free(body);
}

/* Stream a regular file with correct Content-Type/Length. */
static void send_file(int fd, int head, const char *path, off_t size)
{
	FILE *f = fopen(path, "rb");
	if (!f) {
		send_status(fd, head, 403, "Forbidden", "<h1>403</h1>");
		return;
	}
	char hdr[512];
	int hlen = snprintf(hdr, sizeof hdr,
		"HTTP/1.0 200 OK\r\nContent-Type: %s\r\n"
		"Content-Length: %lld\r\nConnection: close\r\n\r\n",
		mime(path), (long long)size);
	send_all(fd, hdr, (size_t)hlen);
	if (!head) {
		char buf[65536];
		size_t got;
		while ((got = fread(buf, 1, sizeof buf, f)) > 0)
			send_all(fd, buf, got);
	}
	fclose(f);
}

static void handle(int fd)
{
	char req[8192];
	ssize_t r = read(fd, req, sizeof req - 1);
	if (r <= 0)
		return;
	req[r] = '\0';

	char method[16], target[4096];
	if (sscanf(req, "%15s %4095s", method, target) != 2) {
		send_status(fd, 0, 400, "Bad Request", "<h1>400</h1>");
		return;
	}
	int head = !strcmp(method, "HEAD");
	if (strcmp(method, "GET") && !head) {
		send_status(fd, head, 405, "Method Not Allowed", "<h1>405</h1>");
		fprintf(stderr, "%s %s -> 405\n", method, target);
		return;
	}
	url_decode(target);
	if (target[0] != '/' || strchr(target, '\0') - target == 0) {
		send_status(fd, head, 400, "Bad Request", "<h1>400</h1>");
		return;
	}

	/* Resolve against the document root and confine to it. */
	char full[PATH_MAX * 2], resolved[PATH_MAX];
	snprintf(full, sizeof full, "%s%s", root, target);
	if (!realpath(full, resolved)) {
		send_status(fd, head, 404, "Not Found", "<h1>404 Not Found</h1>");
		fprintf(stderr, "GET %s -> 404\n", target);
		return;
	}
	size_t rl = strlen(root);
	if (strncmp(resolved, root, rl) != 0 ||
	    (resolved[rl] != '\0' && resolved[rl] != '/')) {
		send_status(fd, head, 403, "Forbidden", "<h1>403 Forbidden</h1>");
		fprintf(stderr, "GET %s -> 403 (escapes root)\n", target);
		return;
	}

	struct stat st;
	if (stat(resolved, &st) != 0) {
		send_status(fd, head, 404, "Not Found", "<h1>404</h1>");
		return;
	}
	if (S_ISDIR(st.st_mode)) {
		char index[PATH_MAX + 16];
		int need = snprintf(index, sizeof index, "%s/index.html", resolved);
		if (need > 0 && (size_t)need < sizeof index && stat(index, &st) == 0 &&
		    S_ISREG(st.st_mode)) {
			send_file(fd, head, index, st.st_size);
			fprintf(stderr, "GET %s -> 200 (index.html)\n", target);
		} else {
			send_listing(fd, head, resolved, target);
			fprintf(stderr, "GET %s -> 200 (listing)\n", target);
		}
	} else if (S_ISREG(st.st_mode)) {
		send_file(fd, head, resolved, st.st_size);
		fprintf(stderr, "%s %s -> 200\n", method, target);
	} else {
		send_status(fd, head, 403, "Forbidden", "<h1>403</h1>");
	}
}

int main(int argc, char **argv)
{
	int port = 8000;
	const char *addr = "127.0.0.1", *dir = ".";

	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-p") && i + 1 < argc)
			port = atoi(argv[++i]);
		else if (!strcmp(argv[i], "-b") && i + 1 < argc)
			addr = argv[++i];
		else if (argv[i][0] != '-')
			dir = argv[i];
		else {
			fprintf(stderr,
				"usage: %s [-p port] [-b addr] [dir]\n"
				"  -p PORT   listen port (default 8000)\n"
				"  -b ADDR   bind address (default 127.0.0.1; 0.0.0.0 = all)\n"
				"  dir       directory to serve (default .)\n",
				argv[0]);
			return 2;
		}
	}
	if (!realpath(dir, root)) {
		perror(dir);
		return 1;
	}
	if (port < 1 || port > 65535) {
		fprintf(stderr, "legendserve: bad port %d\n", port);
		return 2;
	}

	signal(SIGPIPE, SIG_IGN);

	int s = socket(AF_INET, SOCK_STREAM, 0);
	if (s < 0) {
		perror("socket");
		return 1;
	}
	int one = 1;
	setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);

	struct sockaddr_in sa;
	memset(&sa, 0, sizeof sa);
	sa.sin_family = AF_INET;
	sa.sin_port = htons((unsigned short)port);
	if (inet_pton(AF_INET, addr, &sa.sin_addr) != 1) {
		fprintf(stderr, "legendserve: bad address %s\n", addr);
		return 2;
	}
	if (bind(s, (struct sockaddr *)&sa, sizeof sa) != 0) {
		perror("bind");
		return 1;
	}
	if (listen(s, 16) != 0) {
		perror("listen");
		return 1;
	}
	fprintf(stderr, "legendserve: serving %s on http://%s:%d/  (Ctrl+C to stop)\n",
		root, addr, port);

	for (;;) {
		int c = accept(s, NULL, NULL);
		if (c < 0)
			continue;
		handle(c);
		close(c);
	}
	return 0; /* not reached */
}
