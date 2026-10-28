from __future__ import annotations

import argparse
import os
from dataclasses import dataclass

DEFAULT_HOST = "localhost"
DEFAULT_PORT = 9876
DEFAULT_SCREENSHOT_DIR = None


@dataclass
class Config:
    host: str
    port: int
    screenshot_dir: str | None
    connect_timeout: float = 5.0
    read_timeout: float = 30.0

    @classmethod
    def from_args_and_env(cls, argv: list[str], env: dict | None = None) -> "Config":
        env = os.environ if env is None else env
        p = argparse.ArgumentParser(prog="sketchup-mcp-bridge")
        p.add_argument("--host", default=None)
        p.add_argument("--port", type=int, default=None)
        p.add_argument("--screenshot-dir", default=None)
        ns = p.parse_args(argv)
        host = ns.host or env.get("SKETCHUP_MCP_HOST") or DEFAULT_HOST
        if ns.port is not None:
            port = ns.port
        else:
            raw_port = env.get("SKETCHUP_MCP_PORT")
            try:
                port = int(raw_port) if raw_port is not None else DEFAULT_PORT
            except ValueError:
                raise ValueError(f"SKETCHUP_MCP_PORT={raw_port!r} is not a valid integer") from None
        sdir = ns.screenshot_dir or env.get("SKETCHUP_MCP_SCREENSHOT_DIR") or DEFAULT_SCREENSHOT_DIR
        return cls(host=host, port=port, screenshot_dir=sdir)
