require 'json'
module FDSConference
  extend self
  ROOT = 'D:/Codex work/FDS-AI-3D'
  def pt(x,y,z); Geom::Point3d.new(x.mm,y.mm,z.mm); end
  def mat(model,name,color)
    m=model.materials[name] || model.materials.add(name)
    m.color=Sketchup::Color.new(*color)
    m
  end
  def rr(l,w,r,z,inset=0)
    l-=2*inset; w-=2*inset; r-=inset
    r=[r,1].max
    arr=[]
    [[l/2-r,w/2-r,0],[-l/2+r,w/2-r,90],[-l/2+r,-w/2+r,180],[l/2-r,-w/2+r,270]].each do |cx,cy,start|
      13.times do |i|
        a=(start+i*90.0/12)*Math::PI/180
        arr << pt(cx+r*Math.cos(a),cy+r*Math.sin(a),z)
      end
    end
    arr
  end
  def surface(e,points,material,reverse=false)
    f=e.add_face(points)
    raise 'Failed to create face' unless f
    f.reverse! if reverse
    f.material=material;f.back_material=material
    f
  end
  def bridge(e,a,b,material,flip=false)
    a.length.times do |i|
      j=(i+1)%a.length
      points=[a[i],a[j],b[j],b[i]]
      points.reverse! if flip
      surface(e,points,material)
    end
  end
  def box(parent,name,x,y,z,l,w,h,material)
    g=parent.add_group;g.name=name
    f=surface(g.entities,[pt(x,y,z),pt(x+l,y,z),pt(x+l,y+w,z),pt(x,y+w,z)],material)
    f.reverse! if f.normal.z<0
    f.pushpull(h.mm)
    g.entities.grep(Sketchup::Face).each{|face|face.material=material;face.back_material=material}
    g.set_attribute('FDS','nominal_mm',[l,w,h]);g
  end
  def inset_poly(poly,d)
    area=poly.each_with_index.sum{|p,i|q=poly[(i+1)%poly.length];p[0]*q[1]-q[0]*p[1]}
    sign=area>0 ? 1 : -1
    lines=poly.each_with_index.map do |p,i|
      q=poly[(i+1)%poly.length];dx=q[0]-p[0];dy=q[1]-p[1];len=Math.hypot(dx,dy)
      [[p[0]-sign*dy/len*d,p[1]+sign*dx/len*d],[dx,dy]]
    end
    lines.each_with_index.map do |(p,v),i|
      q,u=lines[(i-1)%lines.length];den=v[0]*u[1]-v[1]*u[0]
      t=((q[0]-p[0])*u[1]-(q[1]-p[1])*u[0])/den
      [p[0]+t*v[0],p[1]+t*v[1]]
    end
  end
  def foot(parent,sign,body,cap,bevel)
    profile=[[759.3,740],[880.7,740],[1245,483.1],[1245,0],[1175,0],[1175,446.9]]
    inner=inset_poly(profile,5)
    rings=[[-525,inner],[-519,profile],[519,profile],[525,inner]].map{|y,poly|poly.map{|x,z|pt(sign*x,y,z)}}
    g=parent.add_group;g.name=sign<0 ? '02 左斜折板式支脚（推定）' : '03 右斜折板式支脚（推定）'
    surface(g.entities,rings.first,cap,sign>0)
    rings.each_cons(2).with_index{|(a,b),i|bridge(g.entities,a,b,i==1 ? body : bevel,sign<0)}
    surface(g.entities,rings.last,cap,sign<0)
    # Orient the connected shell from its cap so solid volume is positive.
    if g.volume<0;g.entities.grep(Sketchup::Face).each(&:reverse!);end
    g.set_attribute('FDS','assumed','Thickness 70mm; transverse width 1050mm; knee 483mm; 5mm edge bevel')
    g
  end
  def build
    model=Sketchup.active_model
    path=model.path.tr('\\','/')
    owned=path.downcase.include?('/work/conference-table/working.skp') || model.get_attribute('FDS','model_id')=='conference-table-v01'
    raise "Refusing unrelated model: #{path}" unless owned
    model.entities.clear!
    model.pages.to_a.each{|page|model.pages.erase(page)}
    model.set_attribute('FDS','model_id','conference-table-v01')
    model.set_attribute('FDS','source','Three supplied product photos; overall dimensions confirmed, component dimensions estimated')
    model.options['UnitsOptions']['LengthUnit']=2
    model.options['UnitsOptions']['LengthFormat']=0
    model.options['UnitsOptions']['LengthPrecision']=1
    wood=mat(model,'E0准分子肤感板—浅木纹（外观示意）',[214,193,162])
    wood.texture=[ROOT+'/work/conference-table/Plywood_01_1K_alb_1.png',1800.mm,900.mm]
    wood.color=Sketchup::Color.new(202,181,150)
    wood.colorize_type=Sketchup::Material::COLORIZE_TINT
    edge=mat(model,'浅木色封边',[178,156,124])
    lower=mat(model,'桌面下斜边',[126,118,101])
    base=mat(model,'暖深灰支脚',[87,85,77])
    cap=mat(model,'支脚端面',[98,96,87])
    bevel=mat(model,'支脚柔化边缘',[113,110,99])
    gray=mat(model,'吸塑装饰板—暖灰',[151,148,136])
    black=mat(model,'黑色理线刷及缝隙',[28,28,26])
    socketmat=mat(model,'三位插座面板（布局示意）',[53,53,49])
    root=model.entities.add_group;root.name='会议枱 3200×1390×775 mm'
    root.set_attribute('FDS','overall_mm',[3200,1390,775])
    top=root.entities.add_group;top.name='01 浅木色圆角桌面 / 厚32mm（推定）'
    levels=[[740,20],[745,5],[769,0],[772,3]]
    rings=levels.map{|z,i|rr(3200,1390,90,z,i)}
    rings.each_cons(2).with_index{|(a,b),i|bridge(top.entities,a,b,i==0 ? lower : edge)}
    bottom=surface(top.entities,rings.first,lower,true)
    hole0=rr(1804,264,12,740);h=top.entities.add_face(hole0);h.erase! if h
    upper=surface(top.entities,rings.last,wood)
    hole1=rr(1804,264,12,772);h=top.entities.add_face(hole1);h.erase! if h
    bridge(top.entities,hole0,hole1,edge,true)
    top.entities.grep(Sketchup::Edge).each do |e|
      smooth=e.faces.length==2 && e.faces[0].normal.angle_between(e.faces[1].normal)<25.degrees
      e.soft=smooth; e.smooth=smooth
    end
    # Subtle panel junctions visible in the source photographs.
    [-930,930].each{|x|box(root.entities,'桌面拼板接缝（推定）',x-0.25,-692,772.01,0.5,1384,0.04,edge)}
    foot(root.entities,-1,base,cap,bevel);foot(root.entities,1,base,cap,bevel)
    box(root.entities,'04A 前纵向承托梁（推定）',-800,-245,655,1600,45,85,base)
    box(root.entities,'04B 后纵向承托梁（推定）',-800,200,655,1600,45,85,base)
    box(root.entities,'左上承托板',-910,-525,734,130,1050,6,base)
    box(root.entities,'右上承托板',780,-525,734,130,1050,6,base)
    tray=root.entities.add_group;tray.name='05 多功能线盒 / 三位电源插座（内部布局推定）'
    box(tray.entities,'线盒底壳',-720,-112,685,1440,224,5,base)
    box(tray.entities,'线盒前壁',-720,-117,685,1440,5,80,base)
    box(tray.entities,'线盒后壁',-720,112,685,1440,5,80,base)
    [-720,715].each{|x|box(tray.entities,'线盒端壁',x,-112,685,5,224,80,base)}
    [-300,0,300].each_with_index do |x,i|
      s=tray.entities.add_group;s.name="插座#{i+1}（三孔布局仅示意）"
      box(s.entities,'面板',x-43,-43,703,86,86,9,socketmat)
      [[-15,-12,7,17],[9,-12,7,17],[-4,15,8,17]].each do |dx,dy,w,l|
        box(s.entities,'插孔示意',x+dx,dy,712,w,l,0.5,black)
      end
    end
    lids=root.entities.add_group;lids.name='06 吸塑装饰盖板及黑色理线缝 / 1800×260mm（推定）'
    # Two continuous covers with a central brush slot; topmost surface defines overall H=775.
    box(lids.entities,'前半装饰盖板',-900,-130,772,1800,121,3,gray)
    box(lids.entities,'后半装饰盖板',-900,9,772,1800,121,3,gray)
    box(lids.entities,'左端封口',-900,-9,772,370,18,3,gray)
    box(lids.entities,'右端封口',530,-9,772,370,18,3,gray)
    box(lids.entities,'理线刷',-530,-9,769,1060,18,3,black)
    [-525,-510,-495,-480,-465].each{|x|box(lids.entities,'刷毛端部细节',x,-9,772,0.5,18,0.1,black)}
    root.set_attribute('FDS','assumptions','Top 32mm; corner R90; feet 70mm and 1050mm wide; inset 1800x260; hidden sockets conceptual')
    opts=model.rendering_options
    {'DisplayColorByLayer'=>false,'DrawGround'=>false,'DrawSky'=>false,'DisplaySectionPlanes'=>false,'DisplaySectionCuts'=>false,'EdgeDisplayMode'=>0,'DrawSilhouettes'=>false,'DrawProfilesOnly'=>false,'DisplayTextures'=>true,'RenderMode'=>2,'BackgroundColor'=>Sketchup::Color.new(255,255,255)}.each do |k,v|
      begin;opts[k]=v;rescue ArgumentError;end
    end
    model.shadow_info['DisplayShadows']=false
    model.active_view.camera=Sketchup::Camera.new(pt(2800,-6500,3600),pt(0,0,400),[0,0,1])
    model.active_view.camera.perspective=false
    model.active_view.zoom(root)
    model.active_view.camera.height=2400.mm
    model.active_view.refresh
    {bounds_mm:3.times.map{|i|(root.bounds.max[i]-root.bounds.min[i]).to_mm},parts:root.entities.grep(Sketchup::Group).map{|g|{name:g.name,solid:g.manifold?}}}.to_json
  end
end
FDSConference.build
