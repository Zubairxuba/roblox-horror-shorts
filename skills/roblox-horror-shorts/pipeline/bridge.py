"""Tiny local bridge between Roblox Studio (HttpService) and files on disk.
GET  /<path>  -> serves files under the work folder (env SHORTS_ROOT, default: the current folder)   (Studio pulls Luau sources)
POST /<path>  -> writes the request body to that file    (Studio pushes sources back)
Bound to 127.0.0.1 only."""
import http.server, os, pathlib
ROOT = pathlib.Path(os.environ.get("SHORTS_ROOT", ".")).resolve()
class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k): super().__init__(*a, directory=str(ROOT), **k)
    def do_POST(self):
        p = (ROOT / self.path.split("?")[0].lstrip("/")).resolve()
        if not (p.is_relative_to(ROOT / "roblox") or p.is_relative_to(ROOT / "projects")):
            self.send_response(403); self.end_headers(); return
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(self.rfile.read(int(self.headers["Content-Length"])))
        self.send_response(200); self.end_headers(); self.wfile.write(b"ok")
    def log_message(self, *a): pass
http.server.ThreadingHTTPServer(("127.0.0.1", 8765), H).serve_forever()
