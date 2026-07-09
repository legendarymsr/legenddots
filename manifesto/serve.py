import http.server
import socketserver

PORT = 8080

class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # Silent Mode

print(f"\n⚡ FOSS PROPAGANDA SERVER ONLINE")
print(f"📡 TARGET: http://localhost:{PORT}")

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n\n💀 SERVER KILLED.")
