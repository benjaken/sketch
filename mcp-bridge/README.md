# sketchup-mcp-bridge

A robust [Model Context Protocol](https://modelcontextprotocol.io/) (MCP) server that lets an AI client (e.g. Claude Code) drive **SketchUp Pro 2026** on a Windows host — including from WSL.

Verified working on SketchUp engine **26.1.256**. MIT license.

---

## Why This Exists

The most popular existing tool (`mhyrr/sketchup-mcp`) has two failure modes this project fixes by design:

1. **Persistent-socket desync** — the original client held one socket open and sent a `ping` without reading its reply. SketchUp responded "Method not found", which was then mis-read as the response to the *next* command, so every other call failed with "Communication error with Sketchup: Method not found". **Fix:** connect-per-command — a fresh TCP connection is opened for each MCP tool call and closed immediately after the response.

2. **Write-hang** — the original Ruby server mutated the model inside the timer loop. A mutation that raised inside an open `start_operation` left a dangling transaction and hung the entire server (subsequent writes timed out). **Fix:** every `eval` is wrapped in `start_operation` / `commit_operation` with a guaranteed `abort_operation` on error; the timer loop is "immortal" — no exception can escape it.

Also note: install from source / git, not a stale PyPI build. Some published builds crash with `FastMCP.__init__() got an unexpected keyword argument 'description'`; this repo uses `instructions=` (the current FastMCP API).

---

## Architecture

```
Claude Code (WSL / any host)
        │  MCP stdio transport
        ▼
 Python MCP server  (FastMCP, run via uvx)
        │  TCP connect-per-command  →  127.0.0.1:9876
        ▼
 Ruby TCP server  (UI.start_timer loop inside SketchUp)
        │
        ▼
  SketchUp Pro 2026 model
```

**Two components:**

- **Ruby extension** — runs a TCP server on `127.0.0.1:9876` inside SketchUp. Built around a `UI.start_timer` accept loop on the main thread so Ruby API calls are safe. One request per connection.
- **Python MCP server** — a FastMCP server (`uvx`-installable) that acts as a connect-per-command TCP client; each tool call opens, uses, and closes one TCP connection.

---

## Wire Protocol

Each exchange is a single JSON line terminated by `\n`.

**Request:**
```json
{"id": 1, "cmd": "eval", "args": {"code": "Sketchup.version"}}
```

**Success response:**
```json
{"id": 1, "ok": true, "result": "26.1.256"}
```

**Error response:**
```json
{"id": 1, "ok": false, "error": "NameError: undefined local variable ..."}
```

The Ruby server closes the socket after writing the response. The Python client opens a fresh connection for every command. This is deliberate — it eliminates all desync issues.

---

## Tools

| Tool | Arguments | Description |
|------|-----------|-------------|
| `eval_ruby` | `code: str` | Execute arbitrary Ruby in the active model; returns `result.to_s` |
| `get_scene_info` | — | Model title, entity count, active length unit, model bounds, selection size |
| `get_selection` | — | Selected entities — entityID, typename, bounding box |
| `screenshot` | — | Renders the current view to a PNG on the host and returns it as an image |

---

## Installation

### 1. SketchUp Extension (`.rbz`)

**Get the extension — either download the prebuilt `.rbz` (easiest):**
```
https://github.com/Shattenjagger/sketchup-mcp-bridge/releases/latest/download/su_mcp_bridge.rbz
```
This asset is rebuilt automatically on every push to `master`.

**…or build it from source:**
```bash
python3 scripts/build_rbz.py
# → dist/su_mcp_bridge.rbz  (plain zip, no `zip` binary required)
```

**Install in SketchUp:**
1. **Window → Extension Manager → Install Extension**
2. Select `dist/su_mcp_bridge.rbz`
3. Accept the unsigned-extension prompt
4. Restart SketchUp

**Start the server each session:**

**Extensions → SketchUp MCP Bridge → Start Server**

The Ruby Console will print:
```
[SUMCPBridge] listening on 127.0.0.1:9876
```

> There is no autostart — you need to start the server at the beginning of each SketchUp session.

---

### 2. Python MCP Server (via `uvx`)

Register with Claude Code (user scope):
```bash
claude mcp add sketchup --scope user -- \
  uvx --from git+https://github.com/Shattenjagger/sketchup-mcp-bridge \
  sketchup-mcp-bridge --port 9876
```

For a local checkout, substitute `--from /path/to/local/clone`.

Then restart Claude Code so it picks up the new MCP tools.

**Configuration flags and environment variables:**

| Flag | Env var | Default | Description |
|------|---------|---------|-------------|
| `--host` | `SKETCHUP_MCP_HOST` | `localhost` | Host where SketchUp is running |
| `--port` | `SKETCHUP_MCP_PORT` | `9876` | TCP port the Ruby server listens on |
| `--screenshot-dir` | `SKETCHUP_MCP_SCREENSHOT_DIR` | none (required for `screenshot`) | WSL path to a host-side temp dir (e.g. `/mnt/c/Users/<you>/AppData/Local/Temp`); `screenshot` raises an error if unset |

---

## WSL + Windows Networking

If Claude Code runs in WSL and SketchUp on the Windows host, the Ruby extension binds `127.0.0.1` on the host — which is **not** reachable from WSL under default NAT networking.

**Enable mirrored networking** (requires Windows 11 22H2+):

Add the following to `C:\Users\<you>\.wslconfig`:
```ini
[wsl2]
networkingMode=mirrored
```

Then shut down WSL and reopen it:
```powershell
wsl --shutdown
```

After that, the host's `localhost:9876` is reachable from WSL without any port forwarding.

**Screenshot directory:** there is no default. You must set `--screenshot-dir` (or `SKETCHUP_MCP_SCREENSHOT_DIR`) to a WSL path that maps to a Windows temp directory, for example:
```bash
--screenshot-dir /mnt/c/Users/<you>/AppData/Local/Temp
```
(or any WSL-visible directory on the Windows host). The `screenshot` tool raises a clear error if this is not configured.

---

## Security

`eval_ruby` executes **arbitrary Ruby** in your SketchUp process with full SketchUp API access — there is no sandbox. The Ruby server binds loopback only (`127.0.0.1`) and is intended as a local, single-user developer tool on your own machine.

**Do not expose port 9876 to a network.** Do not use this in a shared or multi-user environment.

---

## Development

Python environment is managed with `uv`.

```bash
# Run tests
uv run pytest          # 14 tests

# Rebuild the extension after Ruby changes
python3 scripts/build_rbz.py
# Then reinstall dist/su_mcp_bridge.rbz in SketchUp and restart SketchUp
```

---

## License

MIT — see [LICENSE](LICENSE).
