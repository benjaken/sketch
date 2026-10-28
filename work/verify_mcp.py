import anyio,sys,json,base64
from pathlib import Path
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
root=Path(__file__).resolve().parents[1]
async def main():
    params=StdioServerParameters(command=sys.executable,args=['-m','sketchup_mcp_bridge.server','--host','127.0.0.1','--port','9876','--screenshot-dir',str(root/'work/screenshots')],cwd=str(root))
    report={}
    async with stdio_client(params) as streams:
      async with ClientSession(*streams) as s:
        init=await s.initialize();report['server']=init.serverInfo.model_dump()
        report['tools']=[t.name for t in (await s.list_tools()).tools]
        async def call(name,args={}):
          result=await s.call_tool(name,args)
          if result.isError: raise RuntimeError(str(result.content))
          text='\n'.join(c.text for c in result.content if c.type=='text')
          print(name,text[:600],flush=True)
          return result,text
        _,report['scene_before']=await call('get_scene_info')
        bad=await s.call_tool('eval_ruby',{'code':'raise "MCP expected failure"'})
        assert bad.isError,'Failure must be reported as MCP isError'
        report['mcp_error_semantics']=True
        _,report['generated']=await call('eval_ruby',{'code':(root/'work/generate_cabinet.rb').read_text(encoding='utf-8-sig')})
        _,report['saved']=await call('eval_ruby',{'code':"raise 'save failed' unless Sketchup.active_model.save('D:/Codex work/FDS-AI-3D/outputs/FDS-demo-cabinet.skp'); Sketchup.active_model.path"})
        _,report['scene_after']=await call('get_scene_info')
        result,_=await call('screenshot')
        imgs=[c for c in result.content if c.type=='image'];assert imgs
        (root/'outputs/FDS-demo-cabinet.png').write_bytes(base64.b64decode(imgs[0].data))
        report['screenshot_bytes']=(root/'outputs/FDS-demo-cabinet.png').stat().st_size
        report['skp_bytes']=(root/'outputs/FDS-demo-cabinet.skp').stat().st_size
    (root/'review/mcp-live-result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps(report,ensure_ascii=False,indent=2))
anyio.run(main)
