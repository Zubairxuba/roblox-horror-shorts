"""Tiny local bridge between Roblox Studio (HttpService) and files on disk.
GET  /<path>  -> serves files under roblox/ and projects/ of the work folder (env SHORTS_ROOT, default: the current folder)
POST /<path>  -> writes the request body to a .txt/.lua/.json file under roblox/ or projects/ (camera log, sources)
Bound to 127.0.0.1 only. Rejects browser requests (any Origin header) and foreign Host names (DNS rebinding),
so a web page cannot read your files or write scripts you later run."""
import http.server, os, pathlib
PORT = int(os.environ.get("BRIDGE_PORT", "8765"))
ROOT = pathlib.Path(os.environ.get("SHORTS_ROOT", ".")).resolve()
HOSTS = {f"127.0.0.1:{PORT}", f"localhost:{PORT}"}
WRITABLE = {".txt", ".lua", ".json"}

class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k): super().__init__(*a, directory=str(ROOT), **k)

    def target(self):
        """The resolved file path, or None (after a 403) if the request is not allowed."""
        # the SAME path the handler serves (percent-decoded, ?/# stripped, normalised): checking the raw URL let ..%2F escape
        p = pathlib.Path(self.translate_path(self.path)).resolve()
        ok = (self.headers.get("Host") in HOSTS and "Origin" not in self.headers
              and (p.is_relative_to(ROOT / "roblox") or p.is_relative_to(ROOT / "projects")))
        if not ok:
            self.send_response(403); self.end_headers()
            return None
        return p

    def do_GET(self):
        if self.target(): super().do_GET()

    def list_directory(self, path):   # no folder listings
        self.send_error(403); return None

    def do_HEAD(self):
        if self.target(): super().do_HEAD()

    def do_POST(self):
        p = self.target()
        if not p: return
        if p.suffix not in WRITABLE:
            self.send_response(403); self.end_headers(); return
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(self.rfile.read(int(self.headers["Content-Length"])))
        self.send_response(200); self.end_headers(); self.wfile.write(b"ok")

    def log_message(self, *a): pass

if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
