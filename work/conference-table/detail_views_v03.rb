require 'json'
m=Sketchup.active_model
raise 'Wrong model' unless m.get_attribute('FDS','model_id')=='conference-table-v01'
v=m.active_view
root=m.entities.grep(Sketchup::Group).first
out='D:/Codex work/FDS-AI-3D/outputs/conference-table-v03'
[
 ['06 正面透视校对',[0,-6000,1050],[0,0,390],nil,'front-perspective'],
 ['07 桌脚圆弧细节',[-2200,-2400,950],[-1170,-430,280],1050,'foot-detail'],
 ['08 桌面斜削边细节',[-2200,-2300,950],[-1250,-500,735],900,'edge-detail']
].each do |name,eye,target,h,file|
 v.camera=Sketchup::Camera.new(FDSConference.pt(*eye),FDSConference.pt(*target),[0,0,1])
 v.camera.perspective=h.nil?
 if h
  v.camera.height=h.mm
 else
  v.camera.fov=30
  v.zoom(root)
  c=v.camera;c.set(c.target.offset(c.eye-c.target,c.eye.distance(c.target)*1.08),c.target,c.up)
 end
 p=m.pages.add(name);p.description='依据用户红框修正的几何近景；弧度及截面尺寸仍为照片推定。';p.update
 v.refresh
 v.write_image(filename:out+'/'+file+'.png',width:1600,height:1000,antialias:true)
end
# Temporary uniform material to inspect actual geometry without wood grain.
faces=[]
walk=lambda do |e|
 e.each do |x|
  if x.is_a?(Sketchup::Face)
   faces << [x,x.material,x.back_material]
  elsif x.is_a?(Sketchup::Group)
   walk.call(x.entities)
  end
 end
end
walk.call(root.entities)
clay=m.materials['校对灰模'] || m.materials.add('校对灰模');clay.color=Sketchup::Color.new(180,180,180)
begin
 faces.each{|f,_,_|f.material=clay;f.back_material=clay}
 v.camera=m.pages[1].camera
 v.refresh
 v.write_image(filename:out+'/geometry-check.png',width:1600,height:1000,antialias:true)
ensure
 faces.each{|f,a,b|f.material=a;f.back_material=b}
end
m.pages.selected_page=m.pages[0];v.camera=m.pages[0].camera
m.save(out+'/conference-table-3200x1390x775-v03.skp')
r=JSON.parse(File.read(out+'/validation.json'));r['scene_count']=m.pages.size;r['revision']='V03 geometry: bowed long edges, deep undercut tabletop, rounded slab ends';File.write(out+'/validation.json',JSON.pretty_generate(r))
{scenes:m.pages.size,saved:m.path}.to_json
