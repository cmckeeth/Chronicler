#!/usr/bin/env python3
"""
Chronicler deploy webhook — runs on the HOST (not in Docker).
Listens for POST /deploy, runs git pull && ./deploy.sh.

Usage:
    DEPLOY_SECRET=your-secret python3 webhook.py

Or with systemd — see chronicler-webhook.service
"""

import http.server
import subprocess
import os
import threading
import time

REPO    = os.path.dirname(os.path.abspath(__file__))
SECRET  = os.environ.get("DEPLOY_SECRET", "")
PORT    = int(os.environ.get("WEBHOOK_PORT", "5162"))
# Write to home dir to avoid Docker-owned logs/ dir
LOG     = os.path.expanduser("~/webhook.log")

_deploying = False


def run_deploy():
    global _deploying
    os.makedirs(os.path.join(REPO, "logs"), exist_ok=True)
    with open(LOG, "a") as f:
        f.write(f"\n[{time.strftime('%Y-%m-%d %H:%M:%S')}] Deploy triggered\n")
        f.flush()
        result = subprocess.run(
            ["bash", "-c", "git pull && ./deploy.sh"],
            cwd=REPO, stdout=f, stderr=subprocess.STDOUT
        )
        f.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Deploy exited: {result.returncode}\n")
    _deploying = False


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        global _deploying

        if self.path != "/deploy":
            self._respond(404, "not found")
            return

        if SECRET and self.headers.get("X-Deploy-Secret", "") != SECRET:
            self._respond(401, "unauthorized")
            return

        if _deploying:
            self._respond(409, "deploy already in progress")
            return

        _deploying = True
        threading.Thread(target=run_deploy, daemon=True).start()
        self._respond(200, "deploy started")

    def do_GET(self):
        if self.path == "/deploy/status":
            self._respond(200, "deploying" if _deploying else "idle")
        else:
            self._respond(404, "not found")

    def _respond(self, code, body):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(body.encode())

    def log_message(self, fmt, *args):
        pass  # silence default access log — deploy.sh already logs


if __name__ == "__main__":
    if not SECRET:
        print("WARNING: DEPLOY_SECRET not set — endpoint is unprotected")

    server = http.server.HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Chronicler webhook listening on :{PORT}")
    print(f"  POST /deploy  (X-Deploy-Secret: {SECRET or '(none)'})")
    print(f"  GET  /deploy/status")
    server.serve_forever()
