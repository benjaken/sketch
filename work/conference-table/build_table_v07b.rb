require 'json'
# V07 — re-cut against the high-resolution photos.
# plan: rounded rectangle with a mild bow; slab edge with a true roundover;
# cover with reveal, offset slot and an inlaid metal module; legs with R5 ends.
module FDSV07
  extend self
  ROOT = 'D:/Codex work/FDS-AI-3D'

  HL     = 1600.0
  HW     = 695.0
  BOW    = 60.0
  CORNER = 175.0
  TOP_Z  = 772.0
  BOT_Z  = 720.0
  LEG_R  = 5.0

  def pt(x, y, z); Geom::Point3d.new(x.mm, y.mm, z.mm); end

  def mat(model, name, color)
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*color)
    m
  end

  def ring_points(w, h, r, samples = 36)
    cx = w - r; cy = h - r
    pts = []
    arc = lambda do |ox, oy, a0, a1|
      13.times do |i|
        a = (a0 + (a1 - a0) * i / 12.0) * Math::PI / 180
        pts << [ox + r * Math.cos(a), oy + r * Math.sin(a)]
      end
    end
    0.upto(samples) { |i| pts << [cx - 2 * cx * i / samples.to_f, -h] }
    arc.call(-cx, -cy, 270, 180)
    0.upto(samples) { |i| pts << [-w, -cy + 2 * cy * i / samples.to_f] }
    arc.call(-cx, cy, 180, 90)
    0.upto(samples) { |i| pts << [-cx + 2 * cx * i / samples.to_f, h] }
    arc.call(cx, cy, 90, 0)
    0.upto(samples) { |i| pts << [w, cy - 2 * cy * i / samples.to_f] }
    arc.call(cx, -cy, 0, -90)
    clean = []
    pts.each { |p| clean << p unless clean.last && (clean.last[0] - p[0]).abs < 1e-6 && (clean.last[1] - p[1]).abs < 1e-6 }
    clean.pop if clean.size > 1 && (clean.first[0] - clean.last[0]).abs < 1e-6 && (clean.first[1] - clean.last[1]).abs < 1e-6
    clean
  end

  def outline(z, inset = 0)
    pts = ring_points(HL - inset, HW - inset, [CORNER - inset, 1].max)
    pts.map! { |x, y| pt(x, y * (1.0 - (BOW / HW) * (x / HL)**2), z) }
    pts
  end

  # levels for a slab edge: roundover r at the bottom and the top
  def edge_levels(z0, z1, r, steps = 6)
    lv = []
    0.upto(steps) do |i|
      a = (Math::PI / 2) * i / steps
      lv << [(z0 + r * (1 - Math.cos(a))).round(4), (r * (1 - Math.sin(a))).round(4)]
    end
    lv << [(z1 - r).round(4), 0.0]
    0.upto(steps) do |i|
      a = (Math::PI / 2) * i / steps
      lv << [(z1 - r + r * Math.sin(a)).round(4), (r * (1 - Math.cos(a))).round(4)]
    end
    out = []
    lv.each { |z, i| out << [z, i] unless out.last && (out.last[0] - z).abs < 1e-6 }
    out
  end

  def rounded_rect_pts(cx, cy, w, h, r, z)
    r = [[r, w / 2.0 - 0.6].min, h / 2.0 - 0.6].min
    pts = []
    [[w / 2.0 - r, h / 2.0 - r, 0], [-(w / 2.0 - r), h / 2.0 - r, 90],
     [-(w / 2.0 - r), -(h / 2.0 - r), 180], [w / 2.0 - r, -(h / 2.0 - r), 270]].each do |ox, oy, start|
      9.times do |i|
        a = (start + i * 90.0 / 8) * Math::PI / 180
        pts << pt(cx + ox + r * Math.cos(a), cy + oy + r * Math.sin(a), z)
      end
    end
    pts
  end

  def surface(ent, points, material, reverse = false)
    f = ent.add_face(points)
    raise 'Failed to create face' unless f
    f.reverse! if reverse
    f.material = material; f.back_material = material
    f
  end

  def bridge(ent, a, b, material, flip = false)
    a.length.times do |i|
      j = (i + 1) % a.length
      q = [a[i], a[j], b[j], b[i]]
      q.reverse! if flip
      surface(ent, [q[0], q[1], q[2]], material)
      surface(ent, [q[0], q[2], q[3]], material)
    end
  end

  def box(parent, name, x, y, z, l, w, h, material)
    g = parent.add_group; g.name = name
    f = surface(g.entities, [pt(x, y, z), pt(x + l, y, z), pt(x + l, y + w, z), pt(x, y + w, z)], material)
    f.reverse! if f.normal.z < 0
    f.pushpull(h.mm)
    g.entities.grep(Sketchup::Face).each { |face| face.material = material; face.back_material = material }
    g.set_attribute('FDS', 'nominal_mm', [l, w, h])
    g
  end

  def foot(parent, sign, body, cap)
    prof = [[741.0, 720.0], [880.7, 720.0], [1245.0, 483.1], [1245.0, 0.0], [1155.0, 0.0], [1155.0, 440.0]]
    offsets = [0.15, -0.15, -1.0, -1.0, 1.0, 1.0]
    r = LEG_R
    stations = []
    0.upto(12) { |i| th = i * Math::PI / 24;        stations << [-525 + r * (1 - Math.cos(th)), r * (1 - Math.sin(th))] }
    0.upto(12) { |i| th = (12 - i) * Math::PI / 24; stations << [525 - r * (1 - Math.cos(th)),  r * (1 - Math.sin(th))] }
    rings = stations.map do |y, d|
      prof.each_with_index.map { |(x, z), i| pt(sign * (x + offsets[i] * d), y, z) }
    end
    g = parent.add_group
    g.name = sign < 0 ? '02 左斜折板式支脚（推定）' : '03 右斜折板式支脚（推定）'
    surface(g.entities, rings.first, cap, sign > 0)
    rings.each_cons(2).with_index { |(a, b), i| bridge(g.entities, a, b, body, sign < 0) }
    surface(g.entities, rings.last, cap, sign < 0)
    g.entities.grep(Sketchup::Face).each(&:reverse!) if g.volume < 0
    g.entities.grep(Sketchup::Edge).each do |e|
      s = e.faces.size == 2 && e.faces[0].normal.angle_between(e.faces[1].normal) < 35.degrees
      e.soft = s; e.smooth = s
    end
    g.entities.grep(Sketchup::Edge).each do |e|
      zs = e.vertices.map { |v| v.position.z.to_mm }
      (e.soft = false; e.smooth = false) if zs.all? { |z| (z - 483.1).abs < 0.01 } || zs.all? { |z| (z - 446.9).abs < 0.01 }
    end
    panel = g.entities.add_face([pt(sign * 1175, -500, 25), pt(sign * 1175, 500, 25),
                                pt(sign * 1175, 500, 420), pt(sign * 1175, -500, 420)])
    panel.reverse! if panel.normal.x * sign > 0
    panel.material = body; panel.back_material = body
    panel.pushpull(-0.8.mm)
    g.set_attribute('FDS', 'assumed', '70mm bent plate; R5 plan end; fold 483.1; inset panel 25mm border')
    g
  end

  def cover(lids, gray, metal, black)
    lid = lids.entities.add_group
    lid.name = '一体装饰盖板（开合机构未确认）'
    face = lid.entities.add_face(rounded_rect_pts(0, 0, 1800, 260, 45, 772.0))
    raise 'cover face' unless face
    face.reverse! if face.normal.z < 0
    face.pushpull(2.0.mm)
    slot = lid.entities.add_face(rounded_rect_pts(-470, 0, 720, 25, 11.9, 774.0))
    if slot
      slot.pushpull(-2.6.mm)
      slot.erase! if slot.valid?
    end
    hole = lid.entities.add_face(rounded_rect_pts(700, 0, 344, 209, 20, 774.0))
    if hole
      hole.pushpull(-2.6.mm)
      hole.erase! if hole.valid?
    end
    lid.entities.grep(Sketchup::Face).each { |f| f.material = gray; f.back_material = gray }
    box(lids.entities, '理线刷', -830, -12.5, 772.3, 720, 25, 1.2, black)
    mod = lids.entities.add_group
    mod.name = '金属接线模块（示意）'
    mf = mod.entities.add_face(rounded_rect_pts(700, 0, 340, 205, 18, 772.0))
    mf.reverse! if mf.normal.z < 0
    mf.pushpull(3.0.mm)
    mod.entities.grep(Sketchup::Face).each { |f| f.material = metal; f.back_material = metal }
    lid
  end

  def build
    model = Sketchup.active_model
    model.entities.clear!
    model.pages.to_a.each { |page| model.pages.erase(page) }
    model.set_attribute('FDS', 'model_id', 'conference-table-v01')
    model.set_attribute('FDS', 'source', 'Three supplied product photos; overall dimensions confirmed, component dimensions estimated')
    model.options['UnitsOptions']['LengthUnit'] = 2
    model.options['UnitsOptions']['LengthFormat'] = 0
    model.options['UnitsOptions']['LengthPrecision'] = 1

    wood  = mat(model, 'E0准分子肤感板—浅木纹（外观示意）', [224, 198, 164])
    wood.texture = [ROOT + '/work/conference-table/light-oak-v02.png', 3200.mm, 1390.mm]
    wood.color = Sketchup::Color.new(224, 198, 164)
    wood.colorize_type = Sketchup::Material::COLORIZE_TINT
    edge   = mat(model, '浅木色封边', [196, 172, 140])
    lower  = mat(model, '桌面下斜面', [116, 108, 94])
    base   = mat(model, '暖深灰支脚', [112, 108, 101])
    cap    = mat(model, '支脚端面', [172, 167, 158])
    gray   = mat(model, '吸塑装饰板—暖灰', [184, 181, 173])
    metal  = mat(model, '金属接线模块（示意）', [186, 186, 183])
    black  = mat(model, '黑色理线刷及缝隙', [26, 26, 24])
    socket = mat(model, '三位插座面板（布局示意）', [58, 58, 54])
    tray_m = mat(model, '线盒内部深灰', [74, 73, 70])

    root = model.entities.add_group
    root.name = '会议枱 3200×1390×775 mm'
    root.set_attribute('FDS', 'overall_mm', [3200, 1390, 775])

    top = root.entities.add_group
    top.name = '01 浅木色圆角桌面 / 厚52mm（推定）'
    levels = edge_levels(720.0, 772.0, 10.0, 6)
    rings = levels.map { |z, inset| outline(z, inset) }
    rings.each_cons(2).with_index { |(a, b), i| bridge(top.entities, a, b, i.zero? ? lower : wood) }
    surface(top.entities, rings.first, lower, true)
    hole0 = rounded_rect_pts(0, 0, 1804, 264, 49, 720.0)
    h = top.entities.add_face(hole0); h.erase! if h
    surface(top.entities, rings.last, wood)
    hole1 = rounded_rect_pts(0, 0, 1804, 264, 49, 772.0)
    h = top.entities.add_face(hole1); h.erase! if h
    bridge(top.entities, hole0, hole1, edge, true)
    top.entities.grep(Sketchup::Edge).each do |e|
      s = e.faces.length == 2 && e.faces[0].normal.angle_between(e.faces[1].normal) < 22.degrees
      e.soft = s; e.smooth = s
    end
    [-800, 800].each { |x| box(root.entities, '桌面拼板接缝（推定）', x - 0.75, -640, 772.0, 1.5, 1280, 0.05, lower) }

    foot(root.entities, -1, base, cap)
    foot(root.entities, 1, base, cap)

    box(root.entities, '04A 前纵向承托梁（推定）', -800, -245, 690, 1600, 45, 30, base)
    box(root.entities, '04B 后纵向承托梁（推定）', -800, 200, 690, 1600, 45, 30, base)

    tray = root.entities.add_group
    tray.name = '05 多功能线盒 / 三位电源插座（内部布局推定）'
    box(tray.entities, '线盒底壳', -720, -112, 690, 1440, 224, 5, tray_m)
    box(tray.entities, '线盒前壁', -720, -117, 690, 1440, 5, 75, tray_m)
    box(tray.entities, '线盒后壁', -720, 112, 690, 1440, 5, 75, tray_m)
    [-720, 715].each { |x| box(tray.entities, '线盒端壁', x, -112, 690, 5, 224, 75, tray_m) }
    [-450, -150, 150, 450].each_with_index do |x, i|
      s = tray.entities.add_group
      s.name = "插座#{i + 1}（三孔布局仅示意）"
      box(s.entities, '面板', x - 43, -43, 704, 86, 86, 9, socket)
      [[-15, -12, 7, 17], [9, -12, 7, 17], [-4, 15, 8, 17]].each do |dx, dy, w, l|
        box(s.entities, '插孔示意', x + dx, dy, 713, w, l, 0.5, black)
      end
    end

    lids = root.entities.add_group
    lids.name = '06 吸塑装饰盖板及黑色理线缝 / 1800×260mm（推定）'
    cover(lids, gray, metal, black)

    root.set_attribute('FDS', 'assumptions', 'Rounded-rect plan (bow 60, R175); 52mm slab with 10mm roundover; legs R5 ends; cover rounded with reveal and offset slot; beams 30mm; seams +-800')
    opts = model.rendering_options
    {'DisplayColorByLayer' => false, 'DrawGround' => false, 'DrawSky' => false,
     'DisplaySectionPlanes' => false, 'DisplaySectionCuts' => false, 'EdgeDisplayMode' => 1,
     'DrawSilhouettes' => false, 'DrawProfilesOnly' => false, 'DisplayTextures' => true,
     'RenderMode' => 2, 'BackgroundColor' => Sketchup::Color.new(255, 255, 255)}.each do |k, v|
      begin; opts[k] = v; rescue ArgumentError; end
    end
    model.shadow_info['DisplayShadows'] = false
    model.styles.update_selected_style
    v = model.active_view
    v.camera = Sketchup::Camera.new(pt(2800, -6500, 3600), pt(0, 0, 400), [0, 0, 1])
    v.camera.perspective = false
    v.zoom(root)
    v.camera.height = 2400.mm
    v.refresh
    "bounds=#{3.times.map { |i| (root.bounds.max[i] - root.bounds.min[i]).to_mm.round(1) }.inspect}"
  end
end
FDSV07.build
