require 'sketchup.rb'
require 'extensions.rb'

module SUMCPBridge
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('SketchUp MCP Bridge', 'su_mcp_bridge/main')
    ext.description = 'Robust MCP bridge: drives SketchUp from Claude via a local TCP/JSON server.'
    ext.version     = '0.1.0'
    ext.creator     = 'Shattenjagger'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
