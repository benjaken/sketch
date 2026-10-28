require 'json'
m=Sketchup.active_model
raise 'Wrong model' unless m.get_attribute('FDS','model_id')=='conference-table-v01'
root=m.entities.grep(Sketchup::Group).find{|g|g.get_attribute('FDS','overall_mm')}
cover=root.entities.grep(Sketchup::Group).find{|g|g.name.start_with?('06 ')}
out='D:/Codex work/FDS-AI-3D/outputs/conference-table-v03'
v=m.active_view
m.shadow_info['UseSunForAllShading']=true
m.shadow_info['Light']=65
m.shadow_info['Dark']=30
['DrawHidden','DrawHiddenGeometry','DrawHiddenObjects'].each{|k|m.rendering_options[k]=false}
views=[
 ['01 透视 A',[-4200,-6500,4600],[0,0,380],[0,0,1],2600,'perspective-a',false],
 ['02 透视 B',[4800,-6500,3200],[0,0,400],[0,0,1],2300,'perspective-b',false],
 ['03 正立面',[0,-7000,390],[0,0,390],[0,0,1],2200,'front',false],
 ['04 俯视',[0,0,7500],[0,0,0],[0,1,0],2250,'top',false],
 ['05 线盒内部（推定）',[1800,-3500,5000],[0,0,600],[0,0,1],1900,'cable-box',true]
]
m.pages.to_a.each{|p|m.pages.erase(p)}
views.each do |name,eye,target,up,h,file,hidden|
 m.rendering_options['EdgeDisplayMode']=0
 m.rendering_options['DrawSilhouettes']=false
 cover.hidden=hidden
 v.camera=Sketchup::Camera.new(FDSConference.pt(*eye),FDSConference.pt(*target),up)
 v.camera.perspective=false
 v.camera.height=h.mm
 if file.start_with?('perspective')
  v.camera.perspective=true
  v.camera.fov=30
  v.zoom(root)
  cam=v.camera
  cam.set(cam.target.offset(cam.eye-cam.target,cam.eye.distance(cam.target)*1.08),cam.target,cam.up)
 end
 p=m.pages.add(name)
 p.use_hidden_objects=true
 p.set_drawingelement_visibility(cover,!hidden)
 p.description=hidden ? '移除装饰盖板以展示三位插座；内部结构与插孔制式仅为示意，未经实物确认。' : '依据三张产品图片重建；总体3200×1390×775mm，其余构件尺寸推定。'
 m.styles.update_selected_style
 p.update
 v.refresh
 v.write_image(filename:out+'/'+file+'.png',width:1600,height:1000,antialias:true)
end
cover.hidden=false
m.pages.selected_page=m.pages[0]
v.camera=m.pages[0].camera
v.refresh
leaves=[]
walk=lambda do |g|
 children=g.entities.grep(Sketchup::Group)
 if children.empty?
  leaves << {name:g.name,solid:g.manifold?,volume_mm3:g.volume*25.4**3}
 else
  children.each{|ch|walk.call(ch)}
 end
end
walk.call(root)
bounds=3.times.map{|i|(root.bounds.max[i]-root.bounds.min[i]).to_mm}
raise 'Dimension mismatch' unless bounds.zip([3200,1390,775]).all?{|a,b|(a-b).abs<0.001}
raise 'Non-solid leaf' unless leaves.all?{|x|x[:solid]}
report={overall_mm:bounds,scene_count:m.pages.size,solid_leaf_count:leaves.size,all_leaf_parts_solid:leaves.all?{|x|x[:solid]},parts:leaves,notes:'Confirmed overall size only. Internal structure, sockets, edge radii, thicknesses and material appearance inferred.'}
File.write(out+'/validation.json',JSON.pretty_generate(report))
m.description='会议枱照片重建 V03。总体尺寸3200×1390×775 mm。桌面、支脚、装饰板和内部线盒尺寸按照片估计；非生产图。材质名称依据用户商品说明，未验证环保或电气认证。'
raise 'Save failed' unless m.save(out+'/conference-table-3200x1390x775-v03.skp')
report.to_json
