import re

def fix_file(file_path, wall_name):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the wall to replace
    wall_pattern = r'\[node name="' + wall_name + r'" type="CSGBox3D" parent="\."\]\ntransform = Transform3D\(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, (-0\.25)\)\nsize = Vector3\(7, 10, 0\.5\)\nmaterial = SubResource\("StandardMaterial3D_wall"\)\n\n\[node name="DoorHole" type="CSGBox3D" parent="' + wall_name + r'"\]\ntransform = Transform3D\(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1\.4375, 0\)\noperation = 2\nsize = Vector3\(1\.84, 2\.875, 1\)'

    replacement = f'''[node name="{wall_name}Left" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2.21, 0, -0.25)
size = Vector3(2.58, 10, 0.5)
material = SubResource("StandardMaterial3D_wall")

[node name="{wall_name}Right" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 2.21, 0, -0.25)
size = Vector3(2.58, 10, 0.5)
material = SubResource("StandardMaterial3D_wall")

[node name="{wall_name}Top" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 3.9375, -0.25)
size = Vector3(1.84, 2.125, 0.5)
material = SubResource("StandardMaterial3D_wall")

[node name="{wall_name}Bottom" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -2.5, -0.25)
size = Vector3(1.84, 5.0, 0.5)
material = SubResource("StandardMaterial3D_wall")'''

    new_content = re.sub(wall_pattern, replacement, content)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

fix_file('c:/wndr/repo/alex_fight/scenes/levels/hotel_siberia/stairwell_north.tscn', 'WallSouth')
fix_file('c:/wndr/repo/alex_fight/scenes/levels/hotel_siberia/stairwell_south.tscn', 'WallNorth')
print("Done!")
