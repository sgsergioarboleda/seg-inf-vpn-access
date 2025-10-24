#!/usr/bin/env python3
# 😺 Minimal HTTP server that prints "Request by [IP]"
from http.server import BaseHTTPRequestHandler, HTTPServer
import os

HOST = "0.0.0.0"
PORT = int(os.environ.get("APP_PORT", "8080"))

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        client_ip = self.client_address[0]
        body = f"Request by {client_ip}\n".encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    # optional: silence default logging to stderr
    def log_message(self, fmt, *args):
        return

if __name__ == "__main__":
    httpd = HTTPServer((HOST, PORT), Handler)
    print(f"[*] Listening on {HOST}:{PORT} ...")
    httpd.serve_forever()
