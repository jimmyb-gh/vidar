#!/usr/bin/env python3

"""
Vidar attacker-location map server.

Functions:

1. Serves vidar_map.html and other static files from the current directory.
2. Provides an SSE endpoint at /events.
3. Reads IP addresses from standard input.
4. Looks up the approximate geographic location of each IP address.
5. Sends the resulting location to connected browsers.

Run:

    python3 vidar_map_server.py

Then enter IP addresses:

    8.8.8.8
    1.1.1.1

Or pipe them in:

    printf '8.8.8.8\n1.1.1.1\n' | python3 vidar_map_server.py

Open:

    http://127.0.0.1:8080/vidar_map.html
"""

from __future__ import annotations

import ipaddress
import json
import queue
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from typing import Any


LISTEN_ADDRESS = "127.0.0.1"
LISTEN_PORT = 8080

# One queue is maintained for each connected browser.
subscribers: list[queue.Queue[dict[str, Any]]] = []
subscribers_lock = threading.Lock()


def log(message: str) -> None:
    """Write a timestamped message to standard error."""

    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}", file=sys.stderr, flush=True)


def publish(event: dict[str, Any]) -> None:
    """Send an event to every connected browser."""

    with subscribers_lock:
        current_subscribers = list(subscribers)

    for subscriber_queue in current_subscribers:
        try:
            subscriber_queue.put_nowait(event)
        except queue.Full:
            log("Dropping event for a slow browser client")


def normalize_ip(line: str) -> str | None:
    """
    Extract and validate an IP address from one line of input.

    Accepted examples:

        8.8.8.8
        8.8.8.8 extra text
        2026-08-03|8.8.8.8|description
    """

    line = line.strip()

    if not line or line.startswith("#"):
        return None

    # First try the whole line.
    try:
        return str(ipaddress.ip_address(line))
    except ValueError:
        pass

    # Vidar records may be pipe-delimited or whitespace-delimited.
    candidates = line.replace("|", " ").split()

    for candidate in candidates:
        candidate = candidate.strip("[](),;")

        try:
            return str(ipaddress.ip_address(candidate))
        except ValueError:
            continue

    return None


def locate_ip(ip_string: str) -> dict[str, Any]:
    """
    Look up an IP address using the ipwho.is JSON API.

    The returned location is approximate. IP geolocation normally identifies
    the network or service-provider location rather than a physical attacker.
    """

    try:
        ip_object = ipaddress.ip_address(ip_string)
    except ValueError:
        return {
            "type": "error",
            "ip": ip_string,
            "message": "Invalid IP address",
        }

    if not ip_object.is_global:
        return {
            "type": "error",
            "ip": ip_string,
            "message": "Address is private, reserved, or otherwise non-global",
        }

    encoded_ip = urllib.parse.quote(ip_string, safe="")
    url = f"https://ipwho.is/{encoded_ip}"

    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "Vidar-Attacker-Map/1.0",
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            raw_data = response.read()
    except urllib.error.HTTPError as error:
        return {
            "type": "error",
            "ip": ip_string,
            "message": f"Geolocation HTTP error: {error.code}",
        }
    except urllib.error.URLError as error:
        return {
            "type": "error",
            "ip": ip_string,
            "message": f"Geolocation connection error: {error.reason}",
        }
    except TimeoutError:
        return {
            "type": "error",
            "ip": ip_string,
            "message": "Geolocation request timed out",
        }

    try:
        data = json.loads(raw_data)
    except json.JSONDecodeError as error:
        return {
            "type": "error",
            "ip": ip_string,
            "message": f"Invalid geolocation response: {error}",
        }

    if not data.get("success", False):
        return {
            "type": "error",
            "ip": ip_string,
            "message": data.get("message", "Geolocation lookup failed"),
        }

    latitude = data.get("latitude")
    longitude = data.get("longitude")

    if not isinstance(latitude, (int, float)):
        return {
            "type": "error",
            "ip": ip_string,
            "message": "Geolocation response did not contain latitude",
        }

    if not isinstance(longitude, (int, float)):
        return {
            "type": "error",
            "ip": ip_string,
            "message": "Geolocation response did not contain longitude",
        }

    connection = data.get("connection") or {}

    return {
        "type": "location",
        "ip": ip_string,
        "latitude": latitude,
        "longitude": longitude,
        "city": data.get("city") or "",
        "region": data.get("region") or "",
        "country": data.get("country") or "",
        "country_code": data.get("country_code") or "",
        "isp": connection.get("isp") or "",
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
    }

def parse_input_line(line: str) -> tuple[str, bool] | None:
    line = line.strip()
    
    if not line or line.startswith("#"):
        return None
    
    fields = [field.strip() for field in line.split("|")]
    
    try:
        ip_string = str(ipaddress.ip_address(fields[0]))
    except ValueError:
    	return None
    
    permanent_block = False
    
    if len(fields) >= 2:
        permanent_block = fields[1] in {
            "1",
            "true",
            "yes",
            "permanent",
        }
        
    return ip_string, permanent_block



def stdin_reader() -> None:
    """Read IP addresses continuously from standard input."""

    log("Ready for IP addresses on standard input")

    for line in sys.stdin:
#       ip_string = normalize_ip(line)
        parsed = parse_input_line(line)

        if parsed is None:
            stripped_line = line.strip()

            if stripped_line and not stripped_line.startswith("#"):
                log(f"No valid IP address found in input: {stripped_line}")

            continue
        
        ip_string, permanent_block = parsed

        log(f"Looking up {ip_string};"
            f"permanent_block={permanent_block}"
        )

        event = locate_ip(ip_string)
        event["permanent_block"] = permanent_block

        if event["type"] == "location":
            location_parts = [
                event.get("city", ""),
                event.get("region", ""),
                event.get("country", ""),
            ]

            location_text = ", ".join(
                part for part in location_parts if part
            )

            log(
                f"Located {ip_string}: "
                f"{event['latitude']}, {event['longitude']} "
                f"{location_text}"
            )
        else:
            log(f"Could not locate {ip_string}: {event['message']}")

        publish(event)

    log("Standard input closed")


class VidarRequestHandler(SimpleHTTPRequestHandler):
    """HTTP handler for static files and the SSE event stream."""

    protocol_version = "HTTP/1.1"

    def log_message(self, format_string: str, *args: object) -> None:
        """Route HTTP log messages through our logger."""

        log(
            f"{self.client_address[0]} "
            f"{format_string % args}"
        )

    def do_GET(self) -> None:
        """Handle static-file and SSE requests."""

        parsed_url = urllib.parse.urlparse(self.path)

        if parsed_url.path == "/events":
            self.handle_event_stream()
            return

        if parsed_url.path == "/health":
            self.handle_health_check()
            return

        super().do_GET()

    def handle_health_check(self) -> None:
        """Return a simple JSON health response."""

        body = json.dumps(
            {
                "status": "ok",
                "service": "vidar-map",
            }
        ).encode("utf-8")

        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def handle_event_stream(self) -> None:
        """Maintain a Server-Sent Events connection."""

        subscriber_queue: queue.Queue[dict[str, Any]] = queue.Queue(
            maxsize=100
        )

        with subscribers_lock:
            subscribers.append(subscriber_queue)
            client_count = len(subscribers)

        log(
            f"Browser connected to event stream; "
            f"{client_count} client(s) connected"
        )

        try:
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            #self.send_header("Connection", "keep-alive")
            self.send_header("X-Accel-Buffering", "no")
            self.end_headers()

            self.send_sse(
                {
                    "type": "status",
                    "message": "Connected to Vidar event stream",
                }
            )

            while True:
                try:
                    event = subscriber_queue.get(timeout=15)
                    self.send_sse(event)
                except queue.Empty:
                    # SSE comment used as a keepalive.
                    self.wfile.write(b": keepalive\n\n")
                    self.wfile.flush()

        except (
            BrokenPipeError,
            ConnectionResetError,
            ConnectionAbortedError,
        ):
            pass
        finally:
            with subscribers_lock:
                if subscriber_queue in subscribers:
                    subscribers.remove(subscriber_queue)

                client_count = len(subscribers)

            log(
                f"Browser disconnected from event stream; "
                f"{client_count} client(s) connected"
            )

    def send_sse(self, event: dict[str, Any]) -> None:
        """Write one JSON Server-Sent Event."""

        json_data = json.dumps(event, ensure_ascii=False)
        message = f"data: {json_data}\n\n".encode("utf-8")

        self.wfile.write(message)
        self.wfile.flush()


class VidarHTTPServer(ThreadingHTTPServer):
	daemon_threads = True
	
	def handle_error(self, request, client_address):
		# error = sys.exception()
		error = sys.exc_info()[1]
		
		if isinstance(
			error,
			(
				BrokenPipeError,
				ConnectionResetError,
				ConnectionAbortedError,
			),
		):
			log(
				f"Client {client_address[0]} disconnected "
				"without closing the HTTP connection cleanly"
			)
			return
			
		super().handle_error(request,client_address)




def main() -> None:
    stdin_thread = threading.Thread(
        target=stdin_reader,
        name="stdin-reader",
        daemon=True,
    )
    stdin_thread.start()

    server = VidarHTTPServer(
        (LISTEN_ADDRESS, LISTEN_PORT),
        VidarRequestHandler,
    )

    log(
        f"Serving on http://{LISTEN_ADDRESS}:{LISTEN_PORT}/"
        "vidar_map.html"
    )

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log("Stopping server")
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
