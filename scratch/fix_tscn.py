import re

path = r'c:\wndr\repo\alex_fight\scenes\levels\hotel_siberia\hotel_level.tscn'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix Ramp1_Down
content = re.sub(
    r'(\[node name="Ramp1_Down" type="CSGPolygon3D" parent="NavigationRegion3D/HotelGeometry/Stairwell"\]\n\s*transform = Transform3D\()[^\n]+\n\s*polygon = PackedVector2Array\([^\n]+\)',
    r'\g<1>-4.37114e-08, 0, -1, 0, 1, 0, 1, 0, -4.37114e-08, -3, -2, -3)\npolygon = PackedVector2Array(0, 2, 3, 0, 0, 0)',
    content
)

# 2. Fix Ramp2_Down
content = re.sub(
    r'(\[node name="Ramp2_Down" type="CSGPolygon3D" parent="NavigationRegion3D/HotelGeometry/Stairwell"\]\n\s*transform = Transform3D\()[^\n]+\n\s*polygon = PackedVector2Array\([^\n]+\)',
    r'\g<1>-4.37114e-08, 0, 1, 0, 1, 0, -1, 0, -4.37114e-08, 3, -4, -6)\npolygon = PackedVector2Array(0, 2, 3, 0, 0, 0)',
    content
)

# 3. Add Ramp3_Down
if 'Ramp3_Down' not in content:
    ramp3_down = '''[node name="Ramp3_Down" type="CSGPolygon3D" parent="NavigationRegion3D/HotelGeometry/Stairwell"]
transform = Transform3D(-4.37114e-08, 0, -1, 0, 1, 0, 1, 0, -4.37114e-08, -3, -6, -3)
polygon = PackedVector2Array(0, 2, 3, 0, 0, 0)
depth = 2.0
material = SubResource("StandardMaterial3D_floor")

'''
    content = content.replace('[node name="StairWallEast"', ramp3_down + '[node name="StairWallEast"')

# 4. Fix Teleport collision shapes
new_shape = '''[sub_resource type="BoxShape3D" id="BoxShape3D_teleport"]
size = Vector3(6, 4, 1)

'''
last_sub_res = content.rfind('[sub_resource')
if last_sub_res != -1:
    end_of_sub_res = content.find('[node', last_sub_res)
    content = content[:end_of_sub_res] + new_shape + content[end_of_sub_res:]

# Replace TeleportUpper
content = re.sub(
    r'(\[node name="CollisionShape3D" \nparent="NavigationRegion3D/HotelGeometry/Stairwell/TeleportUpper"\]\nshape = SubResource\(")BoxShape3D_corridor_floor("\))',
    r'\g<1>BoxShape3D_teleport\g<2>\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2, 0)',
    content
)

# Replace TeleportLower
content = re.sub(
    r'(\[node name="CollisionShape3D" \nparent="NavigationRegion3D/HotelGeometry/Stairwell/TeleportLower"\]\nshape = SubResource\(")BoxShape3D_corridor_floor("\))',
    r'\g<1>BoxShape3D_teleport\g<2>\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2, 0)',
    content
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated hotel_level.tscn')
