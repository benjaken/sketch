require 'json'
require 'fileutils'
# Scenes / exports / validation / save for a given output directory.
module FDSFinal
  extend self
  VIEWS = [
    ['01 透视 A', [-4200, -6500, 4600], [0, 0, 380], 2600, true,  nil],
    ['02 透视 B', [6500, -6500, 3200], [0, 0, 400], 2300, true,  nil],
    ['03 正立面', [0, -7000, 390], [0, 0, 390], 2200, false, nil],
    ['04 俯视', [0, 0, 7500], [0, 0, 0], 2250, false, 'top'],
    ['05 线盒内部（推定）', [1800, -3500, 5000], [0, 0, 600], 1900, false, nil],
    ['06 正面透视校对', [0, -6000, 750], [0, 0, 390], nil, true,  nil],
    ['07 桌脚圆弧细节', [-2200, -2400, 950], [-1170, -430, 280], 1050, false, nil],
    ['08 桌面斜削边细节', [-2200, -2300, 950], [-1250, -500, 735], 900, false, nil]
  ]
  FILES = { '01 透视 A' => 'perspective-a', '02 透视 B' => 'perspective-b', '03 正立面' => 'front',
            '04 俯视' => 'top', '05 线盒内部（推定）' => 'cable-box', '06 正面透视校对' => 'front-perspective',
            '07 桌脚圆弧细节' => 'foot-detail', '08 桌面斜削边细节' => 'edge-detail' }
  def pt(x, y, z); Geom::Point3d.new(x.mm, y.mm, z.mm); end

  def scenes(model)
    v = model.active_view
    root = model.entities[0]
    ro = model.rendering_options
    ro['EdgeDisplayMode'] = 1
    ro['DrawSilhouettes'] = false
    ro['DrawProfilesOnly'] = false
    model.styles.update_selected_style
    cover = root.entities.grep(Sketchup::Group).find { |g| g.name.start_with?('06 ') }
    model.pages.to_a.each { |p| model.pages.erase(p) }
    VIEWS.each do |name, eye, target, h, persp, upflag|
      hide = name.start_with?('05 ')
      cover.hidden = hide
      cam = Sketchup::Camera.new(pt(*eye), pt(*target), upflag ? [0, 1, 0] : [0, 0, 1])
      cam.perspective = persp
      if h.nil?
        cam.fov = 12
        v.camera = cam
        v.zoom(root)
        c = v.camera; c.set(c.target.offset(c.eye - c.target, c.eye.distance(c.target) * 1.08), c.target, c.up)
      elsif persp
        cam.fov = 18
        v.camera = cam
        v.zoom(root)
        c = v.camera; c.set(c.target.offset(c.eye - c.target, c.eye.distance(c.target) * 1.08), c.target, c.up)
      else
        v.camera = cam
        v.camera.height = h.mm
      end
      page = model.pages.add(name)
      page.use_hidden_objects = true
      page.set_drawingelement_visibility(cover, !hide)
      page.description = '依据产品图片重建；总体3200×1390×775mm，其余构件尺寸推定。'
      page.update
    end
    cover.hidden = false
    model.pages.selected_page = model.pages['01 透视 A']
    v.camera = model.pages['01 透视 A'].camera
    v.refresh
  end

  def export(model, out)
    FileUtils.mkdir_p(out)
    v = model.active_view
    FILES.each do |page_name, file|
      page = model.pages[page_name]
      model.pages.selected_page = page
      v.camera = page.camera
      v.refresh
      v.write_image(filename: "#{out}/#{file}.png", width: 1600, height: 1000, antialias: true)
    end
    root = model.entities[0]
    faces = []
    walk = lambda do |ents|
      ents.each do |x|
        if x.is_a?(Sketchup::Face) then faces << [x, x.material, x.back_material]
        elsif x.is_a?(Sketchup::Group) then walk.call(x.entities) end
      end
    end
    walk.call(root.entities)
    clay = model.materials['校对灰模'] || model.materials.add('校对灰模')
    clay.color = Sketchup::Color.new(180, 180, 180)
    begin
      faces.each { |f, _, _| f.material = clay; f.back_material = clay }
      model.pages.selected_page = model.pages['02 透视 B']
      v.camera = model.pages['02 透视 B'].camera
      v.refresh
      v.write_image(filename: "#{out}/geometry-check.png", width: 1600, height: 1000, antialias: true)
    ensure
      faces.each { |f, a, b| f.material = a; f.back_material = b }
    end
    model.pages.selected_page = model.pages['01 透视 A']
    v.camera = model.pages['01 透视 A'].camera
    v.refresh
  end

  def validate(model, out, revision, desc)
    root = model.entities[0]
    leaves = []
    walk = lambda do |g|
      kids = g.entities.grep(Sketchup::Group)
      kids.empty? ? leaves << { 'name' => g.name, 'solid' => g.manifold?, 'volume_mm3' => g.volume * 25.4**3 } : kids.each { |k| walk.call(k) }
    end
    walk.call(root)
    bounds = 3.times.map { |i| (root.bounds.max[i] - root.bounds.min[i]).to_mm }
    report = { 'overall_mm' => bounds, 'scene_count' => model.pages.size, 'solid_leaf_count' => leaves.size,
               'all_leaf_parts_solid' => leaves.all? { |x| x['solid'] }, 'parts' => leaves,
               'notes' => 'Confirmed overall size only. Internal structure, sockets, edge radii, thicknesses and material appearance inferred.',
               'revision' => revision,
               'feet_volume_mm3' => leaves.select { |x| x['name'].include?('支脚') }.map { |x| x['volume_mm3'] } }
    File.write("#{out}/validation.json", JSON.pretty_generate(report))
    model.description = desc
    saved = model.save(out + '/' + File.basename(out) + '.skp')
    report.merge('saved' => saved).to_json
  end
end
