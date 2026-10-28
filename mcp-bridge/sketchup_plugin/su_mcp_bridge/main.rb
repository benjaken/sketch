require 'sketchup'
require 'json'
require 'socket'

module SUMCPBridge
  class Server
    def initialize(host = '127.0.0.1', port = 9876)
      @host = host
      @port = port
      @server = nil
      @timer = nil
      @running = false
      @clients = {}
    end

    def start
      return if @running
      @server = TCPServer.new(@host, @port)
      @running = true
      @timer = UI.start_timer(0.1, true) { tick }
      log "listening on #{@host}:#{@port}"
    end

    def stop
      @running = false
      UI.stop_timer(@timer) if @timer
      @timer = nil
      (@server.close rescue nil) if @server
      @server = nil
      @clients.keys.each { |client| close_client(client) }
      log "stopped"
    end

    private

    # Immortal tick: no exception may escape, or the timer dies and the server
    # stops responding to everything (the mhyrr failure mode).
    def tick
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
            if state[:input].include?("\n")
              state[:output] = process(state[:input].split("\n", 2).first).to_json + "\n"
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

    def process(line)
      req = JSON.parse(line)
      id  = req["id"]
      case req["cmd"]
      when "eval"
        { "id" => id, "ok" => true, "result" => run_eval((req["args"] || {})["code"]).to_s }
      when "scene_info"
        { "id" => id, "ok" => true, "result" => scene_info }
      when "selection"
        { "id" => id, "ok" => true, "result" => selection_info }
      when "screenshot"
        { "id" => id, "ok" => true, "result" => screenshot((req["args"] || {})) }
      else
        { "id" => id, "ok" => false, "error" => "unknown cmd: #{req["cmd"]}" }
      end
    rescue StandardError, ScriptError => e
      { "id" => id, "ok" => false, "error" => "#{e.class}: #{e.message}" }
    end

    # Every eval runs inside an operation; abort_operation on ANY error guarantees
    # no dangling transaction (the hypothesised write-hang root cause).
    def run_eval(code)
      model = Sketchup.active_model
      model.start_operation("MCP eval", true)
      begin
        result = eval(code, TOPLEVEL_BINDING)
        model.commit_operation
        result
      rescue StandardError, ScriptError
        model.abort_operation rescue nil
        raise
      end
    end

    def scene_info
      m = Sketchup.active_model
      b = m.bounds
      units = m.options["UnitsOptions"]["LengthUnit"]
      "title=#{m.title.empty? ? '(untitled)' : m.title} " \
      "entities=#{m.entities.length} selection=#{m.selection.length} " \
      "length_unit_code=#{units} " \
      "bounds_min=#{b.min.to_a.inspect} bounds_max=#{b.max.to_a.inspect}"
    end

    def selection_info
      sel = Sketchup.active_model.selection
      return "(empty selection)" if sel.empty?
      sel.map { |e|
        bb = (e.bounds rescue nil)
        "##{e.entityID} #{e.typename}" + (bb ? " bbox=#{bb.min.to_a.inspect}..#{bb.max.to_a.inspect}" : "")
      }.join("\n")
    end

    # Writes the current view to a PNG on the host. The path is a *Windows* path
    # the Ruby side can write; the Python side maps it to /mnt/c/... to read it.
    def screenshot(args)
      win_dir = args["win_dir"] || File.join(ENV["TEMP"] || "C:/Windows/Temp")
      path = File.join(win_dir, "su_mcp_view.png").tr("/", "\\")
      view = Sketchup.active_model.active_view
      ok = view.write_image(path, 1280, 720, true)
      raise "write_image failed" unless ok
      path
    end

    def log(msg)
      puts "[SUMCPBridge] #{msg}"
    end
  end

  @server = nil
  def self.start_server
    @server ||= Server.new
    @server.start
  end
  def self.stop_server
    @server&.stop
  end

  unless file_loaded?(__FILE__)
    menu = UI.menu('Extensions').add_submenu('SketchUp MCP Bridge')
    menu.add_item('Start Server') { start_server }
    menu.add_item('Stop Server')  { stop_server }
    menu.add_item('Status') { UI.messagebox(@server && @server.instance_variable_get(:@running) ? 'SketchUp MCP: 127.0.0.1:9876' : 'SketchUp MCP: stopped') }
    # Local FDS installation: start automatically for the first SketchUp instance.
    UI.start_timer(1, false) do
      begin
        start_server
      rescue StandardError => e
        puts "[SUMCPBridge] auto-start unavailable: #{e.message}"
      end
    end
    file_loaded(__FILE__)
  end
end
