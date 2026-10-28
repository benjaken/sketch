from __future__ import annotations

import sys
import os
import json
from datetime import datetime, timezone
from pathlib import Path

from mcp.server.fastmcp import FastMCP, Image

from .client import SketchupClient
from .config import Config

# instructions= is the kwarg that loads cleanly on current mcp SDKs.
# (description= is the one that crashes — the bug we explicitly avoid.)
mcp = FastMCP(
    "SketchUp MCP Bridge",
    instructions="Drive SketchUp 2026 on the Windows host. eval_ruby runs arbitrary "
                 "Ruby in the live model; results are returned as strings.",
)

_client: SketchupClient | None = None
_config: Config | None = None


def get_client() -> SketchupClient:
    global _client
    if _client is None:
        cfg = _config or Config.from_args_and_env([])
        _client = SketchupClient(host=cfg.host, port=cfg.port,
                                 connect_timeout=cfg.connect_timeout,
                                 read_timeout=cfg.read_timeout)
    return _client


def _win_to_wsl(win_path: str) -> str:
    """Map a Windows path (C:\\Users\\..) to its WSL mount (/mnt/c/Users/..)."""
    p = win_path.replace("\\", "/")
    if len(p) > 1 and p[1] == ":":
        p = f"/mnt/{p[0].lower()}{p[2:]}"
    return p


def _safe_call(cmd: str, args: dict) -> str:
    """Let FastMCP report bridge failures as tool errors."""
    result = get_client().call(cmd, args)
    return "" if result is None else str(result)


def eval_ruby(code: str) -> str:
    """Execute arbitrary Ruby in the active SketchUp model and return result.to_s."""
    return _safe_call("eval", {"code": code})


def get_scene_info() -> str:
    """Return model title, entity count, active units, bounds, and selection size."""
    return _safe_call("scene_info", {})


def get_selection() -> str:
    """Return the currently selected entities (entityID, typename, bbox)."""
    return _safe_call("selection", {})


def screenshot() -> Image:
    """Capture the current SketchUp view and return it as an image."""
    cfg = _config or Config.from_args_and_env([])
    if not cfg.screenshot_dir:
        raise ValueError(
            "screenshot requires a host temp dir: set --screenshot-dir or "
            "SKETCHUP_MCP_SCREENSHOT_DIR to a WSL path like "
            "/mnt/c/Users/<you>/AppData/Local/Temp"
        )
    # Convert the configured screenshot dir (a /mnt/c/.. WSL path) back to a
    # Windows path so SketchUp can write to it.
    win_dir = cfg.screenshot_dir
    if win_dir.startswith("/mnt/") and len(win_dir) > 6:
        win_dir = f"{win_dir[5].upper()}:{win_dir[6:]}"
    win_path = get_client().call("screenshot", {"win_dir": win_dir})
    wsl_path = str(win_path) if sys.platform == "win32" else _win_to_wsl(str(win_path))
    data = Path(wsl_path).read_bytes()
    return Image(data=data, format="png")


# Register tools with MCP using call form so functions stay directly callable at
# module scope and return plain values (required for the test suite).
mcp.tool()(eval_ruby)
mcp.tool()(get_scene_info)
mcp.tool()(get_selection)
mcp.tool()(screenshot)


def main() -> None:
    global _config, _client
    _config = Config.from_args_and_env(sys.argv[1:])
    _client = None  # force re-creation with the new config
    audit_path = os.environ.get("FDS_MCP_AUDIT")
    if audit_path:
        from mcp.types import ListToolsRequest
        original = mcp._mcp_server.request_handlers[ListToolsRequest]
        async def audited_list(req):
            result = await original(req)
            event = {"time": datetime.now(timezone.utc).isoformat(), "pid": os.getpid(),
                     "method": "tools/list", "tools": [tool.name for tool in result.root.tools]}
            with open(audit_path, "a", encoding="utf8") as stream:
                stream.write(json.dumps(event) + "\n")
            return result
        mcp._mcp_server.request_handlers[ListToolsRequest] = audited_list
    mcp.run()


if __name__ == "__main__":
    main()
