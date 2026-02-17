from http.server import BaseHTTPRequestHandler, HTTPServer
import os
import subprocess
from urllib.parse import parse_qs, urlparse


def getenv_required(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


SECRET = getenv_required("APPROVE_SECRET")
SESSION = os.environ.get("TMUX_SESSION", "codex:0.0").strip() or "codex:0.0"
HOST = os.environ.get("APPROVE_HOST", "127.0.0.1").strip() or "127.0.0.1"
PORT = int(os.environ.get("APPROVE_PORT", "8787"))


def tmux_send(choice: str):
    subprocess.check_call(["tmux", "send-keys", "-t", SESSION, choice, "Enter"])

def has_valid_secret(handler: BaseHTTPRequestHandler) -> bool:
    # 1) Allow secret via query string: /approve?secret=...
    try:
        parsed = urlparse(handler.path)
        q = parse_qs(parsed.query)
        if "secret" in q and q["secret"]:
            return q["secret"][0] == SECRET
    except Exception:
        pass

    # 2) Also allow header (keeps curl working)
    return handler.headers.get("X-Secret", "") == SECRET

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        path = urlparse(self.path).path

        if not has_valid_secret(self):
            self.send_response(401)
            self.end_headers()
            return

        if path == "/approve":
            tmux_send("y")
            self.send_response(200)
            self.end_headers()
            return

        if path == "/approve2":
            tmux_send("p")
            self.send_response(200)
            self.end_headers()
            return

        if path == "/deny":
            tmux_send("3")
            self.send_response(200)
            self.end_headers()
            return

        self.send_response(404)
        self.end_headers()

    def do_GET(self):
        path = urlparse(self.path).path

        if not has_valid_secret(self):
            self.send_response(401)
            self.end_headers()
            self.wfile.write(b"Unauthorized")
            return

        if path == "/approve":
            tmux_send("y")
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"Approved")
            return

        if path == "/approve2":
            tmux_send("p")
            tmux_send("Enter")
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"Approved (always)")
            return

        if path == "/deny":
            tmux_send("esc")
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"Denied")
            return

        self.send_response(404)
        self.end_headers()


print(f"Webhook listening on {HOST}:{PORT}")
HTTPServer((HOST, PORT), Handler).serve_forever()

