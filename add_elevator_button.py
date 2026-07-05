import re

tscn_path = 'scenes/levels/hotel_siberia/blocks/elevator_shaft.tscn'

with open(tscn_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Update load_steps
match = re.search(r'\[gd_scene load_steps=(\d+) format=3\]', content)
if match:
    old_steps = int(match.group(1))
    new_steps = old_steps + 3
    content = content.replace(match.group(0), f'[gd_scene load_steps={new_steps} format=3]')

# Add ext_resource for the button script
ext_resource_str = '[ext_resource type="Script" path="res://scripts/interactables/elevator_button.gd" id="4_btn"]\n'
last_ext_idx = content.rfind('[ext_resource')
end_of_ext = content.find('\n', last_ext_idx) + 1
content = content[:end_of_ext] + ext_resource_str + content[end_of_ext:]

# Add box shape subresource
sub_resource_str = """
[sub_resource type="BoxShape3D" id="BoxShape3D_button"]
size = Vector3(0.04, 0.1, 0.1)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_button"]
albedo_color = Color(0.8, 0.8, 0.8, 1)

[sub_resource type="BoxMesh" id="BoxMesh_button"]
material = SubResource("StandardMaterial3D_button")
size = Vector3(0.04, 0.1, 0.1)
"""
content = content.replace('[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_wall"]',
                          sub_resource_str.strip() + '\n\n[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_wall"]')


# Add node
node_str = """
[node name="ButtonFloor4" type="AnimatableBody3D" parent="ElevatorGeometry/ElevatorPanel"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.01, 0.0, 0.0)
collision_layer = 3
script = ExtResource("4_btn")

[node name="CollisionShape3D" type="CollisionShape3D" parent="ElevatorGeometry/ElevatorPanel/ButtonFloor4"]
shape = SubResource("BoxShape3D_button")

[node name="MeshInstance3D" type="MeshInstance3D" parent="ElevatorGeometry/ElevatorPanel/ButtonFloor4"]
mesh = SubResource("BoxMesh_button")

[node name="Label3D" type="Label3D" parent="ElevatorGeometry/ElevatorPanel/ButtonFloor4"]
transform = Transform3D(-4.37114e-08, 0, 1, 0, 1, 0, -1, 0, -4.37114e-08, 0.021, 0, 0)
text = "4"
font_size = 24
outline_size = 4
"""

content += node_str

with open(tscn_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Button added.")
