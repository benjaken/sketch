require 'json'
# V06 — rebuild tuned against the three supplied product photos.
# Changes vs V04/V05: rounded (not knife-edge) tabletop edge, gentler plan bow with
# large corner radius, fuller slab thickness at the ends, shallower leg fold,
# deeper cable tray, cover with metal module. All dimensions still photo-derived.
module FDSV06
  extend self
  ROOT = 'D:/Codex work/FDS-AI-3D'

  HL      = 1600.0   # half length
  HW      = 695.0    # half width at centre
  BOW     = 55.0     # long-edge bow at the ends
  CORNER  = 210.0    # plan corner radius
  TOP_Z   = 772.0
  BOT_Z   = 720.0
  LEG_X   = 1245.0   # outer face of leg
  LEG_T   = 70.0     # plate thickness
  LEG_HW  = 525.0    # half width of leg (Y)
  LEG_R   = 23.0     # plan end radius of leg
  FOLD_Z  = 457.0    # outer fold height
  TOP_OUT = 800.0    # outer face top edge x at table underside
  TOP_W   = 121.4    # width of the horizontal cut where the leg meets the table

  def pt(x, y, z); Geom::Point3d.new(x.mm, y.mm, z.mm); end

  def mat(model, name, color)
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*color)
    m
  end

  # Rounded rectangle, inset by +inset+, sampled densely along edges and corners
  # so the long-edge bow actually shows, then bowed along the long edges.
  def outline(z, inset = 0)
    w = HL - inset; h = HW - inset; r = [CORNER - inset, 1].max
    cx = w - r; cy = h - r
    pts = []
    40.downto(0) { |i| pts << [-(cx) + 2 * cx * i / 40.0, -h] }        # bottom edge
    13.times { |i| a = (270 - i * 90.0 / 12) * Math::PI / 180; pts << [-cx + r * Math.cos(a), -cy + r * Math.sin(a)] }
    0.upto(40) { |i| pts << [-w, -cy + 2 * cy * i / 40.0] }            # left edge
    13.times { |i| a = (180 - i * 90.0 / 12) * Math::PI / 180; pts << [-cx + r * Math.cos(a), cy + r * Math.sin(a)] }
    0.upto(40) { |i| pts << [-cx + 2 * cx * i / 40.0, h] }             # top edge
    13.times { |i| a = (90 - i * 90.0 / 12) * Math::PI / 180; pts << [cx + r * Math.cos(a), cy + r * Math.sin(a)] }
    40.downto(0) { |i| pts << [w, cy - 2 * cy * i / 40.0] }            # right edge
    13.times { |i| a = (0 - i * 90.0 / 12) * Math::PI / 180; pts << [cx + r * Math.cos(a), -cy + r * Math.sin(a)] }
    pts.map! do |x, y|
      yy = y * (1.0 - (BOW / HW) * (x / HL)**2)
      pt(x, yy, z)
    end
    clean = []
    pts.each { |p| clean << p unless clean.last && clean.last.to_a.zip(p.to_a).all? { |a, b| (a - b).abs < 1e-6 } }
    clean.pop if clean.size > 1 && clean.first.to_a.zip(clean.last.to_a).all? { |a, b| (a - b).abs < 1e-6 }
    clean
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

  # Folded plate leg. Profile is the V04 bent plate with a lower fold and a
  # shallower slant; the ends keep an R23 plan rounding so the fold line runs
  # out to the end face.
  def foot(parent, sign, body, cap)
    fold_out = FOLD_Z
    fold_in  = FOLD_Z - 36.2
    prof = [[TOP_OUT - TOP_W, 720.0], [TOP_OUT, 720.0], [LEG_X, fold_out],
            [LEG_X, 0.0], [LEG_X - LEG_T, 0.0], [LEG_X - LEG_T, fold_in]]
    n = 12
    stations = []
    0.upto(n) { |i| th = (Math::PI / 2) * (n - i) / n; stations << [-(LEG_HW - LEG_R) - LEG_R * Math.sin(th), LEG_R * (1 - Math.cos(th))] }
    1.upto(n) { |i| th = (Math::PI / 2) * i / n;       stations << [(LEG_HW - LEG_R) + LEG_R * Math.sin(th),  LEG_R * (1 - Math.cos(th))] }
    stations << [-(LEG_HW - LEG_R), 0.0]
    stations << [(LEG_HW - LEG_R), 0.0]
    stations.sort_by! { |s| s[0] }
    stations.uniq! { |s| s[0] }
    # Per-vertex horizontal inset for the plan end rounding: outer-surface points
    # pull toward the plate centre, inner-surface points push away from it.
    offsets = [+0.15, -0.15, -1.0, -1.0, +1.0, +1.0]
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
      (e.soft = false; e.smooth = false) if zs.all? { |z| (z - fold_out).abs < 0.01 } || zs.all? { |z| (z - fold_in).abs < 0.01 }
    end
    panel = g.entities.add_face([pt(sign * (LEG_X - LEG_T), -450, 25), pt(sign * (LEG_X - LEG_T), 450, 25),
                                pt(sign * (LEG_X - LEG_T), 450, fold_in - 40), pt(sign * (LEG_X - LEG_T), -450, fold_in - 40)])
    panel.reverse! if panel.normal.x * sign > 0
    panel.material = body; panel.back_material = body
    panel.pushpull(-0.8.mm)
    g.set_attribute('FDS', 'assumed', "70mm bent plate; R#{LEG_R} plan end rounding; fold at #{FOLD_Z}mm; flat ground contact")
    g
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

    wood  = mat(model, 'E0准分子肤感板—浅木纹（外观示意）', [216, 196, 168])
    wood.texture = [ROOT + '/work/conference-table/light-oak-v02.png', 3200.mm, 1390.mm]
    wood.color = Sketchup::Color.new(222, 200, 170)
    wood.colorize_type = Sketchup::Material::COLORIZE_TINT
    edge  = mat(model, '浅木色封边', [186, 165, 134])
    lower = mat(model, '桌面下斜面', [120, 112, 96])
    base  = mat(model, '暖深灰支脚', [128, 124, 114])
    cap   = mat(model, '支脚端面', [133, 129, 119])
    gray  = mat(model, '吸塑装饰板—暖灰', [156, 153, 143])
    metal = mat(model, '金属接线模块（示意）', [176, 176, 172])
    black = mat(model, '黑色理线刷及缝隙', [28, 28, 26])
    socketmat = mat(model, '三位插座面板（布局示意）', [53, 53, 49])

    root = model.entities.add_group
    root.name = '会议枱 3200×1390×775 mm'
    root.set_attribute('FDS', 'overall_mm', [3200, 1390, 775])

    # --- tabletop: 52mm slab with a small roundover on both edges
    top = root.entities.add_group
    top.name = '01 浅木色圆角桌面 / 厚52mm（推定）'
    levels = [[720.0, 8.0], [724.0, 4.0], [728.0, 0.0], [764.0, 0.0], [768.0, 3.0], [771.0, 7.0], [772.0, 9.0]]
    rings = levels.map { |z, inset| outline(z, inset) }
    rings.each_cons(2).with_index { |(a, b), i| bridge(top.entities, a, b, i.zero? ? lower : wood) }
    surface(top.entities, rings.first, lower, true)
    hole0 = rounded_hole(1804, 264, 12, 720)
    h = top.entities.add_face(hole0); h.erase! if h
    surface(top.entities, rings.last, wood)
    hole1 = rounded_hole(1804, 264, 12, 772)
    h = top.entities.add_face(hole1); h.erase! if h
    bridge(top.entities, hole0, hole1, edge, true)
    top.entities.grep(Sketchup::Edge).each do |e|
      s = e.faces.length == 2 && e.faces[0].normal.angle_between(e.faces[1].normal) < 12.degrees
      e.soft = s; e.smooth = s
    end
    [-930, 930].each { |x| box(root.entities, '桌面拼板接缝（推定）', x - 0.25, -655, 772.02, 0.5, 1310, 0.04, edge) }

    # --- legs
    foot(root.entities, -1, base, cap)
    foot(root.entities, 1, base, cap)

    # --- support beams (hidden under the top, tie the two legs)
    box(root.entities, '04A 前纵向承托梁（推定）', -900, -245, 700, 1800, 45, 20, base)
    box(root.entities, '04B 后纵向承托梁（推定）', -900, 200, 700, 1800, 45, 20, base)

    # --- tray: 1800 x 260, hanging 70mm below the top
    tray = root.entities.add_group
    tray.name = '05 多功能线盒 / 三位电源插座（内部布局推定）'
    box(tray.entities, '线盒底壳', -900, -110, 650, 1800, 220, 6, base)
    box(tray.entities, '线盒前壁', -900, -115, 650, 1800, 5, 70, base)
    box(tray.entities, '线盒后壁', -900, 110, 650, 1800, 5, 70, base)
    [-900, 895].each { |x| box(tray.entities, '线盒端壁', x, -110, 650, 5, 220, 70, base) }
    [-450, -150, 150, 450].each_with_index do |x, i|
      s = tray.entities.add_group
      s.name = "插座#{i + 1}（三孔布局仅示意）"
      box(s.entities, '面板', x - 43, -43, 723, 86, 86, 9, socketmat)
      [[-15, -12, 7, 17], [9, -12, 7, 17], [-4, 15, 8, 17]].each do |dx, dy, w, l|
        box(s.entities, '插孔示意', x + dx, dy, 732, w, l, 0.5, black)
      end
    end

    # --- cover plate with brush slot and metal module
    lids = root.entities.add_group
    lids.name = '06 吸塑装饰盖板及黑色理线缝 / 1800×260mm（推定）'
    lid = lids.entities.add_group
    lid.name = '一体装饰盖板（开合机构未确认）'
    outer = [pt(-900, -130, 772), pt(900, -130, 772), pt(900, 130, 772), pt(-900, 130, 772)]
    f = surface(lid.entities, outer, gray)
    slot = lid.entities.add_face([pt(-430, -9, 772), pt(430, -9, 772), pt(430, 9, 772), pt(-430, 9, 772)])
    slot.erase!
    f.reverse! if f.normal.z < 0
    f.pushpull(3.mm)
    lid.entities.grep(Sketchup::Face).each { |face| face.material = gray; face.back_material = gray }
    box(lids.entities, '理线刷', -430, -9, 770, 860, 18, 3, black)
    box(lids.entities, '金属接线模块（示意）', 470, -110, 772, 400, 220, 3.0, metal)

    root.set_attribute('FDS', 'assumptions', 'Top 52mm with 12mm roundover; plan bow 55mm; legs 70mm bent plate with R23 ends and fold at 457mm; tray 1800x260 hanging 70mm; sockets conceptual')
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
    { bounds_mm: 3.times.map { |i| (root.bounds.max[i] - root.bounds.min[i]).to_mm },
      parts: root.entities.grep(Sketchup::Group).map { |g| { name: g.name, solid: g.manifold? } } }.to_json
  end

  def rounded_hole(l, w, r, z)
    pts = []
    cx = l / 2.0 - r; cy = w / 2.0 - r
    [[cx, cy, 0], [-cx, cy, 90], [-cx, -cy, 180], [cx, -cy, 270]].each do |ox, oy, start|
      9.times do |i|
        a = (start + i * 90.0 / 8) * Math::PI / 180
        pts << pt(ox + r * Math.cos(a), oy + r * Math.sin(a), z)
      end
    end
    pts
  end
end
FDSV06.build
