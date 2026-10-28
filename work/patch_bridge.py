from pathlib import Path
r=Path('vendor/sketchup-mcp-bridge')
p=r/'src/sketchup_mcp_bridge/server.py';s=p.read_text();a=s.index('    """Call SketchUp;');z=s.index('\n\n\ndef eval_ruby',a);s=s[:a]+'''    """Let FastMCP report bridge failures as tool errors."""
    result = get_client().call(cmd, args)
    return "" if result is None else str(result)'''+s[z:];s=s.replace('wsl_path = _win_to_wsl(str(win_path))','wsl_path = str(win_path) if sys.platform == "win32" else _win_to_wsl(str(win_path))');p.write_text(s)
p=r/'src/sketchup_mcp_bridge/client.py';s=p.read_text().replace('buf += chunk','buf += chunk\n                    if len(buf) > 8 * 1024 * 1024:\n                        raise SketchupError("response exceeds 8 MiB")');s=s.replace('        if not resp.get("ok"):', '        if resp.get("id") != req["id"]:\n            raise SketchupError("response id mismatch")\n        if not resp.get("ok"):');p.write_text(s)
p=r/'sketchup_plugin/su_mcp_bridge/main.rb';s=p.read_text().replace('      @running = false\n    end','      @running = false\n      @clients = {}\n    end',1);a=s.index('    def tick');z=s.index('    def process',a);s=s[:a]+'''    def tick
      return unless @running
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      4.times do
        client = @server.accept_nonblock(exception: false)
        break if client == :wait_readable
        if @clients.length >= 8
          client.close
        else
          @clients[client] = { input: +"", output: nil, deadline: now + 10 }
        end
      end
      @clients.keys.each do |client|
        state = @clients[client]
        begin
          raise IOError, 'request deadline exceeded' if now > state[:deadline]
          if state[:output]
            written = client.write_nonblock(state[:output], exception: false)
            next if written == :wait_writable
            state[:output] = state[:output].byteslice(written..-1)
            close_client(client) if state[:output].empty?
          else
            chunk = client.read_nonblock(16384, exception: false)
            next if chunk == :wait_readable
            raise EOFError unless chunk
            state[:input] << chunk
            raise IOError, 'request exceeds 1 MiB' if state[:input].bytesize > 1048576
            if state[:input].include?("\\n")
              state[:output] = process(state[:input].split("\\n", 2).first).to_json + "\\n"
              state[:deadline] = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
            end
          end
        rescue StandardError => e
          log "client error: #{e.class}: #{e.message}"
          close_client(client)
        end
      end
    rescue StandardError => e
      log "tick error: #{e.class}: #{e.message}"
    end

    def close_client(client)
      @clients.delete(client)
      client.close rescue nil
    end

'''+s[z:];s=s.replace('      @server = nil\n      log "stopped"','      @server = nil\n      @clients.keys.each { |client| close_client(client) }\n      log "stopped"');s=s.replace('    rescue => e\n      { "id" => nil','    rescue StandardError, ScriptError => e\n      { "id" => id');s=s.replace('      rescue\n        model.abort_operation','      rescue StandardError, ScriptError\n        model.abort_operation');p.write_text(s)
p=r/'tests/test_server.py';s=p.read_text().replace('    out = srv.eval_ruby("raise")\n    assert "boom" in out  # returned as a string, not raised, so Claude sees it','    import pytest\n    with pytest.raises(SketchupError, match="boom"):\n        srv.eval_ruby("raise")');s+='''\n\ndef test_native_windows_screenshot(monkeypatch, tmp_path):
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
''';p.write_text(s)
print('Patched Python transport, screenshot, error semantics and Ruby event loop')
