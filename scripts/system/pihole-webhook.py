#!/usr/bin/env python3
"""
Pi-hole Webhook Service
Temporarily disables Pi-hole blocking via HTTP request.

Usage:
    http://192.168.1.100:8888/?duration=10
    (Change 192.168.1.100 to your device's IP address)

Parameters:
    duration: Seconds to disable blocking (1-86400, default: 10)

Example Safari Bookmark:
    http://192.168.1.100:8888/?duration=10

This is useful when Pi-hole is blocking a link you need to access temporarily.
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import subprocess
import json

class PiHoleWebhook(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)

        # Get duration (default 10 seconds)
        duration = params.get('duration', ['10'])[0]

        # Validate duration is a number
        try:
            duration_int = int(duration)
            if duration_int < 1 or duration_int > 86400:  # Max 24 hours
                raise ValueError("Duration must be between 1 and 86400 seconds")
        except ValueError as e:
            self.send_response(400)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())
            return

        # Execute docker command to disable pihole
        try:
            result = subprocess.run(
                ['docker', 'exec', 'pihole', 'pihole', 'disable', f'{duration_int}s'],
                capture_output=True,
                text=True,
                timeout=5
            )

            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()

            response = {
                "status": "success",
                "message": f"Pi-hole disabled for {duration_int} seconds",
                "output": result.stdout
            }
            self.wfile.write(json.dumps(response).encode())

        except subprocess.TimeoutExpired:
            self.send_response(500)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Command timeout"}).encode())
        except Exception as e:
            self.send_response(500)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())

    def log_message(self, format, *args):
        # Log requests
        print(f"{self.address_string()} - {format % args}")

if __name__ == '__main__':
    PORT = 8888
    server = HTTPServer(('0.0.0.0', PORT), PiHoleWebhook)
    print(f'Pi-hole webhook server running on port {PORT}')
    print(f'Usage: http://192.168.1.100:{PORT}/?duration=10')
    print(f'(Change 192.168.1.100 to your device IP)')
    server.serve_forever()
