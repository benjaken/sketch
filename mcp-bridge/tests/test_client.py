import json
import socket
import threading

import pytest

from sketchup_mcp_bridge.client import SketchupClient, SketchupError

def _serve_once(handler):
    """Start a localhost TCP server that handles exactly one connection. Returns port."""
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", 0))
    srv.listen(1)
    port = srv.getsockname()[1]

    def run():
        conn, _ = srv.accept()
        with conn:
            line = b""
            while not line.endswith(b"\n"):
                line += conn.recv(4096)
            handler(conn, json.loads(line))
        srv.close()

    threading.Thread(target=run, daemon=True).start()
    return port


def _closed_port() -> int:
    """Bind then immediately close a socket to get a port nothing is listening on."""
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port

def test_call_sends_framed_request_and_parses_result():
    captured = {}
    def handler(conn, req):
        captured.update(req)
        conn.sendall(json.dumps({"id": req["id"], "ok": True, "result": "pong"}).encode() + b"\n")
    port = _serve_once(handler)
    c = SketchupClient(host="127.0.0.1", port=port)
    assert c.call("eval", {"code": "1+1"}) == "pong"
    assert captured["cmd"] == "eval"
    assert captured["args"] == {"code": "1+1"}
    assert "id" in captured

def test_call_raises_on_ok_false():
    def handler(conn, req):
        conn.sendall(json.dumps({"id": req["id"], "ok": False, "error": "RuntimeError: boom"}).encode() + b"\n")
    port = _serve_once(handler)
    c = SketchupClient(host="127.0.0.1", port=port)
    with pytest.raises(SketchupError, match="boom"):
        c.call("eval", {"code": "raise"})

def test_call_raises_on_connection_refused():
    c = SketchupClient(host="127.0.0.1", port=_closed_port(), connect_timeout=1.0)
    with pytest.raises(SketchupError):
        c.call("eval", {"code": "1"})


def test_response_id_mismatch():
    def handler(conn, req):
        conn.sendall(json.dumps({"id": req["id"] + 1, "ok": True, "result": "wrong"}).encode() + b"\n")
    port = _serve_once(handler)
    with pytest.raises(SketchupError, match="id mismatch"):
        SketchupClient(host="127.0.0.1", port=port).call("scene_info")
