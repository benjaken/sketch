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
  # Symmetric gently bowed long edges, with tangent corner transitions.
  # Overall extents remain exactly 3200 x 1390; bow is an image-derived assumption.
  def outline(z,inset=0)
    a=[]
    81.times do |i|
      x=-1500+3000.0*i/80
      a << [x,695-95*(x/1500.0)**2]
    end
    1.upto(16) do |i|
      t=i/16.0
      a << [(1-t)**2*1500+2*(1-t)*t*1600+t*t*1600,
            (1-t)**2*600+2*(1-t)*t*(600-100*190.0/1500)+t*t*(500-100*190.0/1500)]
    end
    end_y=500-100*190.0/1500
    1.upto(12){|i|a << [1600,end_y*(1-2*i/12.0)]}
    1.upto(16) do |i|
      t=i/16.0
      a << [(1-t)**2*1600+2*(1-t)*t*1600+t*t*1500,
            -(1-t)**2*end_y-2*(1-t)*t*(600-100*190.0/1500)-t*t*600]
    end
    1.upto(80){|i|x=1500-3000.0*i/80;a << [x,-695+95*(x/1500.0)**2]}
    1.upto(16) do |i|
      t=i/16.0
      a << [-(1-t)**2*1500-2*(1-t)*t*1600-t*t*1600,
            -(1-t)**2*600-2*(1-t)*t*(600-100*190.0/1500)-t*t*end_y]
    end
    1.upto(12){|i|a << [-1600,-end_y*(1-2*i/12.0)]}
    1.upto(15) do |i|
      t=i/16.0
      a << [-(1-t)**2*1600-2*(1-t)*t*1600-t*t*1500,
            (1-t)**2*end_y+2*(1-t)*t*(600-100*190.0/1500)+t*t*600]
    end
    a.reverse.map{|x,y|pt(x*(1600-inset)/1600.0,y*(695-inset)/695.0,z)}
  end
  def rounded_profile(poly,cut)
    arr=[]
    poly.each_with_index do |p,i|
      prev=poly[(i-1)%poly.size];nxt=poly[(i+1)%poly.size]
      l1=Math.hypot(prev[0]-p[0],prev[1]-p[1]);l2=Math.hypot(nxt[0]-p[0],nxt[1]-p[1])
      d=[cut,l1*0.2,l2*0.2].min
      a=2.times.map{|j|p[j]+(prev[j]-p[j])*d/l1}
      b=2.times.map{|j|p[j]+(nxt[j]-p[j])*d/l2}
      9.times do |k|
        t=k/8.0
        arr << 2.times.map{|j|(1-t)**2*a[j]+2*(1-t)*t*p[j]+t*t*b[j]}
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
      surface(e,[points[0],points[1],points[2]],material)
      surface(e,[points[0],points[2],points[3]],material)
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
    profile=[[759.3,720],[880.7,720],[1245,483.1],[1245,0],[1175,0],[1175,446.9]]
    # True curved bullnose across both transverse slab ends, radius 23 mm.
    stations=[]
    13.times do |i|
      theta=i*Math::PI/24
      stations << [-525+23*(1-Math.cos(theta)),23*(1-Math.sin(theta))]
    end
    13.times do |i|
      theta=(12-i)*Math::PI/24
      stations << [525-23*(1-Math.cos(theta)),23*(1-Math.sin(theta))]
    end
    rings=stations.map{|y,d|rounded_profile(inset_poly(profile,d),10).map{|x,z|pt(sign*x,y,z)}}
    g=parent.add_group;g.name=sign<0 ? '02 左斜折板式支脚（推定）' : '03 右斜折板式支脚（推定）'
    surface(g.entities,rings.first,cap,sign>0)
    rings.each_cons(2).with_index{|(a,b),i|bridge(g.entities,a,b,body,sign<0)}
    surface(g.entities,rings.last,cap,sign<0)
    # Orient the connected shell from its cap so solid volume is positive.
    if g.volume<0;g.entities.grep(Sketchup::Face).each(&:reverse!);end
    g.entities.grep(Sketchup::Edge).each{|e|soft=e.faces.size==2 && e.faces[0].normal.angle_between(e.faces[1].normal)<35.degrees;e.soft=soft;e.smooth=soft}
    g.set_attribute('FDS','assumed','Thickness 70mm; width 1050mm; end bullnose R23; bent-profile corner blend 10mm')
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
    wood.texture=[ROOT+'/work/conference-table/light-oak-v02.png',3200.mm,1390.mm]
    wood.color=Sketchup::Color.new(218,194,163)
    wood.colorize_type=Sketchup::Material::COLORIZE_TINT
    edge=mat(model,'浅木色封边',[178,156,124])
    lower=mat(model,'桌面下斜边',[126,118,101])
    base=mat(model,'暖深灰支脚',[113,108,97])
    cap=mat(model,'支脚端面',[117,112,101])
    bevel=mat(model,'支脚柔化边缘',[135,129,117])
    gray=mat(model,'吸塑装饰板—暖灰',[151,148,136])
    black=mat(model,'黑色理线刷及缝隙',[28,28,26])
    socketmat=mat(model,'三位插座面板（布局示意）',[53,53,49])
    root=model.entities.add_group;root.name='会议枱 3200×1390×775 mm'
    root.set_attribute('FDS','overall_mm',[3200,1390,775])
    top=root.entities.add_group;top.name='01 浅木色圆角桌面 / 厚52mm（推定）'
    levels=[[720,100],[759,10],[766,0],[770,0],[772,3]]
    rings=levels.map{|z,i|outline(z,i)}
    rings.each_cons(2).with_index{|(a,b),i|bridge(top.entities,a,b,i<2 ? lower : edge)}
    bottom=surface(top.entities,rings.first,lower,true)
    hole0=rr(1804,264,12,720);h=top.entities.add_face(hole0);h.erase! if h
    upper=surface(top.entities,rings.last,wood)
    hole1=rr(1804,264,12,772);h=top.entities.add_face(hole1);h.erase! if h
    bridge(top.entities,hole0,hole1,edge,true)
    top.entities.grep(Sketchup::Edge).each do |e|
      smooth=e.faces.length==2 && e.faces[0].normal.angle_between(e.faces[1].normal)<10.degrees
      e.soft=smooth; e.smooth=smooth
    end
    # Subtle panel junctions visible in the source photographs.
    [-930,930].each{|x|box(root.entities,'桌面拼板接缝（推定）',x-0.25,-655,772.01,0.5,1310,0.04,edge)}
    foot(root.entities,-1,base,cap,bevel);foot(root.entities,1,base,cap,bevel)
    box(root.entities,'04A 前纵向承托梁（推定）',-800,-245,635,1600,45,85,base)
    box(root.entities,'04B 后纵向承托梁（推定）',-800,200,635,1600,45,85,base)
    box(root.entities,'左上承托板',-910,-525,714,130,1050,6,base)
    box(root.entities,'右上承托板',780,-525,714,130,1050,6,base)
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
    # One continuous annular cover: no artificial full-length seams.
    lid=lids.entities.add_group;lid.name='一体装饰盖板（开合机构未确认）'
    outer=[pt(-900,-130,772),pt(900,-130,772),pt(900,130,772),pt(-900,130,772)]
    f=surface(lid.entities,outer,gray)
    h=lid.entities.add_face([pt(-530,-9,772),pt(530,-9,772),pt(530,9,772),pt(-530,9,772)])
    h.erase!
    f.reverse! if f.normal.z<0
    f.pushpull(3.mm)
    lid.entities.grep(Sketchup::Face).each{|face|face.material=gray;face.back_material=gray}
    box(lids.entities,'理线刷',-530,-9,769,1060,18,3,black)
    root.set_attribute('FDS','assumptions','Top 52mm with 100mm undercut; long-edge bow 95mm at x1500; feet 70mm wide with R23 bullnose; inset 1800x260; hidden sockets conceptual')
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
