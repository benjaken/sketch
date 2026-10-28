require 'json'
m = Sketchup.active_model
expected = 'D:/Codex work/FDS-AI-3D/work/bridge-validation.skp'
raise 'Refusing to replace an unrelated document' unless m.path.tr('\\','/').downcase == expected.downcase
m.entities.clear!
m.options['UnitsOptions']['LengthUnit'] = 2
m.options['UnitsOptions']['LengthFormat'] = 0
root = m.entities.add_group
root.name = 'FDS Demo Cabinet 1200x600x2100 mm'
wood = m.materials.add('FDS Warm Oak')
wood.color = Sketchup::Color.new(190, 145, 91)
back = m.materials.add('FDS Back Panel')
back.color = Sketchup::Color.new(225, 210, 185)
parts = []
make_panel = lambda do |name, x,y,z,w,d,h,material|
  group = root.entities.add_group
  group.name = name
  e = group.entities
  face = e.add_face([x.mm,y.mm,z.mm],[(x+w).mm,y.mm,z.mm],[(x+w).mm,(y+d).mm,z.mm],[x.mm,(y+d).mm,z.mm])
  face.reverse! if face.normal.z < 0
  face.pushpull(h.mm)
  group.material = material
  group.set_attribute('FDS', 'dimensions_mm', [w,d,h])
  group.set_attribute('FDS', 'part_id', name)
  parts << {id: name, dimensions_mm: [w,d,h]}
end
make_panel.call('P01 Left side',0,0,0,18,600,2100,wood)
make_panel.call('P02 Right side',1182,0,0,18,600,2100,wood)
make_panel.call('P03 Bottom',18,0,80,1164,600,18,wood)
make_panel.call('P04 Top',18,0,2082,1164,600,18,wood)
make_panel.call('P05 Divider',591,0,98,18,588,1984,wood)
make_panel.call('P06 Back',18,588,98,1164,12,1984,back)
make_panel.call('P07 Plinth',18,30,0,1164,18,80,wood)
[490,890,1290,1690].each_with_index do |z,i|
  make_panel.call("S#{i+1} Left shelf",18,0,z,573,588,18,wood)
  make_panel.call("S#{i+1} Right shelf",609,0,z,573,588,18,wood)
end
root.set_attribute('FDS', 'size_mm', [1200,600,2100])
root.set_attribute('FDS', 'generated_by', 'MCP verified integration')
m.active_view.camera = Sketchup::Camera.new([3400.mm,-4500.mm,2900.mm],[600.mm,300.mm,1050.mm],[0,0,1])
m.active_view.zoom(root)
File.write('D:/Codex work/FDS-AI-3D/outputs/cabinet-parts.json', JSON.pretty_generate(parts))
{part_count: parts.length, size_mm: [1200,600,2100]}.to_json