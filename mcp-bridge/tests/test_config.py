from sketchup_mcp_bridge.config import Config


def test_defaults():
    c = Config.from_args_and_env([], env={})
    assert c.host == "localhost"
    assert c.port == 9876


def test_cli_overrides():
    c = Config.from_args_and_env(["--host", "1.2.3.4", "--port", "9999"], env={})
    assert c.host == "1.2.3.4"
    assert c.port == 9999


def test_env_fallback_when_no_cli():
    c = Config.from_args_and_env([], env={"SKETCHUP_MCP_HOST": "h", "SKETCHUP_MCP_PORT": "1000"})
    assert c.host == "h"
    assert c.port == 1000


def test_cli_beats_env():
    c = Config.from_args_and_env(["--port", "2000"], env={"SKETCHUP_MCP_PORT": "1000"})
    assert c.port == 2000


def test_screenshot_dir_default():
    c = Config.from_args_and_env([], env={})
    assert c.screenshot_dir is None
