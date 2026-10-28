require 'json'
report = {version: Sketchup.version, ruby: RUBY_VERSION, plugin_path: Sketchup.find_support_file('Plugins')}
begin
  path = 'D:/Codex work/FDS-AI-3D/vendor/sketchup-mcp-bridge/sketchup_plugin/su_mcp_bridge/main.rb'
  RubyVM::InstructionSequence.compile_file(path)
  load path
  server = SUMCPBridge::Server.new
  raise 'scene_info failed' unless server.send(:process, {id: 1, cmd: 'scene_info'}.to_json)['ok']
  before = Sketchup.active_model.entities.length
  response = server.send(:process, {id: 2, cmd: 'eval', args: {code: 'Sketchup.active_model.entities.add_group; raise "rollback test"'}}.to_json)
  raise 'rollback failed' if response['ok'] || Sketchup.active_model.entities.length != before
  response = server.send(:process, {id: 3, cmd: 'eval', args: {code: 'def invalid('}}.to_json)
  raise 'syntax error not contained' if response['ok'] || response['id'] != 3
  raise 'recovery failed' unless server.send(:process, {id: 4, cmd: 'eval', args: {code: '2+2'}}.to_json)['result'] == '4'
  SUMCPBridge.start_server
  report[:ok] = true
rescue Exception => e
  report[:ok] = false
  report[:error] = "#{e.class}: #{e.message}"
  report[:backtrace] = e.backtrace.first(5)
end
File.write('D:/Codex work/FDS-AI-3D/work/ruby-live-check.json', JSON.pretty_generate(report))
puts report.inspect
