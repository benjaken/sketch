from unittest.mock import MagicMock

import sketchup_mcp_bridge.server as srv


def test_eval_ruby_delegates_to_client(monkeypatch):
    fake = MagicMock()
    fake.call.return_value = "42"
    monkeypatch.setattr(srv, "get_client", lambda: fake)
    assert srv.eval_ruby("6*7") == "42"
    fake.call.assert_called_once_with("eval", {"code": "6*7"})


def test_get_scene_info_delegates(monkeypatch):
    fake = MagicMock()
    fake.call.return_value = "title=Untitled n=1"
    monkeypatch.setattr(srv, "get_client", lambda: fake)
    assert srv.get_scene_info() == "title=Untitled n=1"
    fake.call.assert_called_once_with("scene_info", {})


def test_eval_ruby_surfaces_errors(monkeypatch):
    from sketchup_mcp_bridge.client import SketchupError
    fake = MagicMock()
    fake.call.side_effect = SketchupError("RuntimeError: boom")
    monkeypatch.setattr(srv, "get_client", lambda: fake)
    import pytest
    with pytest.raises(SketchupError, match="boom"):
        srv.eval_ruby("raise")


def test_get_selection_delegates(monkeypatch):
    fake = MagicMock()
    fake.call.return_value = "ok"
    monkeypatch.setattr(srv, "get_client", lambda: fake)
    assert srv.get_selection() == "ok"
    fake.call.assert_called_once_with("selection", {})


def test_win_to_wsl():
    from sketchup_mcp_bridge.server import _win_to_wsl
    assert _win_to_wsl(r"C:\Users\username\AppData\Local\Temp\su_mcp_view.png") == \
        "/mnt/c/Users/username/AppData/Local/Temp/su_mcp_view.png"


def test_screenshot_returns_image(monkeypatch, tmp_path):
    from mcp.server.fastmcp import Image
    from sketchup_mcp_bridge.config import Config
    png = tmp_path / "su_mcp_view.png"
    png.write_bytes(b"\x89PNG\r\n\x1a\nFAKE")
    monkeypatch.setattr(srv, "_config", Config(host="localhost", port=9876, screenshot_dir=str(tmp_path)))
    fake = MagicMock()
    fake.call.return_value = str(png)  # _win_to_wsl leaves a /tmp path unchanged
    monkeypatch.setattr(srv, "get_client", lambda: fake)
    result = srv.screenshot()
    assert isinstance(result, Image)
    assert fake.call.call_args[0][0] == "screenshot"


def test_native_windows_screenshot(monkeypatch, tmp_path):
    from sketchup_mcp_bridge.config import Config
    png = tmp_path / "native.png"
    png.write_bytes(b"PNG")
    monkeypatch.setattr(srv.sys, "platform", "win32")
    monkeypatch.setattr(srv, "_config", Config("127.0.0.1", 9876, str(tmp_path)))
    fake = MagicMock()
    fake.call.return_value = str(png)
    monkeypatch.setattr(srv, "get_client", lambda: fake)
    monkeypatch.setattr(srv, "_win_to_wsl", lambda _: (_ for _ in ()).throw(AssertionError("WSL conversion on Windows")))
    assert srv.screenshot().data == b"PNG"
