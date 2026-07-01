with open('scenes/levels/hotel_siberia/base_hotel_level.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

import re
new_ext = '[ext_resource type="Script" path="res://scripts/levels/hotel_level_generator.gd" id="99_generator"]\n'
last_ext_idx = content.rfind('[ext_resource')
end_of_line = content.find('\n', last_ext_idx) + 1
content = content[:end_of_line] + new_ext + content[end_of_line:]

target = '[node name="HotelGeometry" type="Node3D" parent="NavigationRegion3D"]'
replacement = '[node name="HotelGeometry" type="Node3D" parent="NavigationRegion3D"]\nscript = ExtResource("99_generator")'
content = content.replace(target, replacement)

with open('scenes/levels/hotel_siberia/base_hotel_level.tscn', 'w', encoding='utf-8') as f:
    f.write(content)
