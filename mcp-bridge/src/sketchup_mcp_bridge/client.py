from __future__ import annotations

import itertools
import json
import socket
from typing import Any


class SketchupError(Exception):
    """Raised when the bridge cannot reach SketchUp or SketchUp returns ok:false."""


class SketchupClient:
    """Connect-per-command JSON-over-TCP client. Each call opens a fresh socket,
    sends one line, reads one line, closes. This matches the Ruby server's
    one-request-per-connection model — no persistent socket to desync or go stale."""

    def __init__(self, host: str = "localhost", port: int = 9876,
                 connect_timeout: float = 5.0, read_timeout: float = 30.0) -> None:
        self.host = host
        self.port = port
        self.connect_timeout = connect_timeout
        self.read_timeout = read_timeout
        self._ids = itertools.count(1)

    def call(self, cmd: str, args: dict | None = None) -> Any:
        req = {"id": next(self._ids), "cmd": cmd, "args": args or {}}
        try:
            with socket.create_connection((self.host, self.port), timeout=self.connect_timeout) as s:
                s.settimeout(self.read_timeout)
                s.sendall(json.dumps(req).encode("utf-8") + b"\n")
                buf = b""
                while b"\n" not in buf:
                    chunk = s.recv(4096)
                    if not chunk:
                        raise SketchupError("connection closed before a full response")
                    buf += chunk
                    if len(buf) > 8 * 1024 * 1024:
                        raise SketchupError("response exceeds 8 MiB")
        except (OSError, socket.timeout) as e:
            raise SketchupError(f"transport error talking to {self.host}:{self.port}: {e}") from e

        resp = json.loads(buf.split(b"\n", 1)[0].decode("utf-8"))
        if resp.get("id") != req["id"]:
            raise SketchupError("response id mismatch")
        if not resp.get("ok"):
            raise SketchupError(resp.get("error", "unknown error from SketchUp"))
        return resp.get("result")
