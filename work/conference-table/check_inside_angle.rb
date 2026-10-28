require 'json'
m=Sketchup.active_model
root=m.entities.grep(Sketchup::Group).find{|g|g.get_attribute('FDS','overall_mm')}
foot=root.entities.grep(Sketchup::Group).find{|g|g.name.start_with?('02 ')}
verts=foot.entities.grep(Sketchup::Edge).flat_map(&:vertices).uniq.map(&:position)
find=lambda do |x,y,z|
 target=FDSConference.pt(x,y,z)
 p=verts.min_by{|v|v.distance(target)}
 raise 'Expected vertex missing' if p.distance(target)>0.01.mm
 p
end
k=find.call(-1175,-502,446.9)
a=find.call(-759.3,-502,720)
b=find.call(-1175,-502,0)
angle=(a-k).angle_between(b-k)*180/Math::PI
helper=m.entities.add_group;helper.name='校对标注：桌脚内角（非家具零件）'
blue=m.materials['角度校对蓝']||m.materials.add('角度校对蓝');blue.color=Sketchup::Color.new(0,80,210)
center=FDSConference.pt(-1175,-550,446.9)
start=-Math::PI/2
finish=Math.atan2(a.z-k.z,a.x-k.x)
arc=49.times.map{|i|t=start+(finish-start)*i/48;FDSConference.pt(-1175+145*Math.cos(t),-550,446.9+145*Math.sin(t))}
helper.entities.add_curve(arc).each{|e|e.material=blue}
helper.entities.add_text("INNER ANGLE = #{angle.round(1)} deg (OBTUSE)",FDSConference.pt(-960,-550,390))
v=m.active_view
v.camera=Sketchup::Camera.new(FDSConference.pt(-1050,-6000,410),FDSConference.pt(-1050,0,410),[0,0,1])
v.camera.perspective=false;v.camera.height=1000.mm
m.rendering_options['EdgeDisplayMode']=1
m.rendering_options['DrawSilhouettes']=false
v.refresh
v.write_image(filename:'D:/Codex work/FDS-AI-3D/outputs/conference-table-v04/inside-angle-check.png',width:1400,height:1100,antialias:true)
helper.erase!
m.rendering_options['EdgeDisplayMode']=0
m.pages.selected_page=m.pages[0];v.camera=m.pages[0].camera
m.save('D:/Codex work/FDS-AI-3D/outputs/conference-table-v04/conference-table-3200x1390x775-v04.skp')
{measured_from_actual_vertices:true,inside_angle_deg:angle}.to_json
