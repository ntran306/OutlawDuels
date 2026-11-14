"""Laptop endpoint for the phone's dev tools (PLAN.md section 1B.6).

Python standard library only. Run from anywhere:

    python tools/devserver.py            # port 8765

GET  /tuning.json        serves tools/tuning.json
POST /log                appends the body (JSON lines) to build/device/log.jsonl
POST /telemetry/<name>   saves the body as build/device/<name>

Plain HTTP on the LAN, no authentication: run it only on a network you trust.
"""

import argparse
import re
import socket
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TUNING_PATH = REPO_ROOT / "tools" / "tuning.json"
DEVICE_DIR = REPO_ROOT / "build" / "device"
DEFAULT_PORT = 8765
MAX_BODY_BYTES = 64 * 1024 * 1024  # a 10 min recording is about 22 MB
SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")


class Handler(BaseHTTPRequestHandler):
    server_version = "OutlawDuelsDev/1"
    protocol_version = "HTTP/1.1"

    def _reply(self, status, body=b"", content_type="text/plain; charset=utf-8"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _read_body(self):
        try:
            length = int(self.headers.get("Content-Length", ""))
        except ValueError:
            self._reply(411, b"Content-Length required\n")
            return None
        if length < 0 or length > MAX_BODY_BYTES:
            self._reply(413, b"body too large\n")
            return None
        return self.rfile.read(length)

    def do_GET(self):
        if self.path.split("?", 1)[0] == "/tuning.json":
            try:
                body = TUNING_PATH.read_bytes()
            except OSError:
                self._reply(404, b"tools/tuning.json not found\n")
                return
            self._reply(200, body, "application/json")
        else:
            self._reply(404, b"not found\n")

    def do_POST(self):
        path = self.path.split("?", 1)[0]
        body = self._read_body()
        if body is None:
            return
        if path == "/log":
            DEVICE_DIR.mkdir(parents=True, exist_ok=True)
            with open(DEVICE_DIR / "log.jsonl", "ab") as f:
                f.write(body)
                if body and not body.endswith(b"\n"):
                    f.write(b"\n")
            self._reply(200, b"ok\n")
        elif path.startswith("/telemetry/"):
            name = path[len("/telemetry/"):]
            if not SAFE_NAME.match(name):
                self._reply(400, b"bad name\n")
                return
            DEVICE_DIR.mkdir(parents=True, exist_ok=True)
            (DEVICE_DIR / name).write_bytes(body)
            self._reply(200, b"ok\n")
        else:
            self._reply(404, b"not found\n")

    def log_message(self, fmt, *args):
        # Quiet for the 2 s tuning poll; print everything else.
        if self.command == "GET" and self.path.startswith("/tuning.json") and args and str(args[1]) == "200":
            return
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt % args))


def lan_address():
    """The laptop's address on the default route, without sending anything."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("192.0.2.1", 9))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--bind", default="0.0.0.0")
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.bind, args.port), Handler)
    print(f"Dev server on port {args.port}. In the app's Dev server field enter:")
    print(f"  http://{lan_address()}:{args.port}")
    print(f"Tuning file: {TUNING_PATH}")
    print(f"Uploads go to: {DEVICE_DIR}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
