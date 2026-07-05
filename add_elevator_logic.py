import re

tscn_path = 'scenes/levels/hotel_siberia/blocks/elevator_shaft.tscn'

with open(tscn_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Update script on the root node
content = content.replace('ExtResource("3_script")', 'ExtResource("5_ctrl")')

# Add new ext_resources
match = re.search(r'\[gd_scene load_steps=(\d+) format=3\]', content)
if match:
    old_steps = int(match.group(1))
    new_steps = old_steps + 2
    content = content.replace(match.group(0), f'[gd_scene load_steps={new_steps} format=3]')

ext_resources = """
[ext_resource type="Script" path="res://scripts/levels/blocks/elevator_controller.gd" id="5_ctrl"]
[ext_resource type="PackedScene" uid="uid://door_123" path="res://entities/props/elevator_door.tscn" id="6_door"]
"""
last_ext_idx = content.rfind('[ext_resource')
end_of_ext = content.find('\n', last_ext_idx) + 1
content = content[:end_of_ext] + ext_resources.strip() + '\n' + content[end_of_ext:]

# Add door node at the end
# The door hole is at Z = 4.9. We'll place the door at Z = 4.9
# We'll scale it to fit the 2.0 width hole. The original door is 1.4 wide.
# So scale.x = 2.0 / 1.4 = 1.428
node_str = """
[node name="ElevatorDoor" parent="." instance=ExtResource("6_door")]
transform = Transform3D(1.428, 0, 0, 0, 1, 0, 0, 0, 1, -0.714, 0.0, 4.9)
"""
# The open offset for sliding door is usually applied to the AnimatableBody3D inside it, 
# so the scale might stretch the offset. We will just use it and it will slide further.
# Wait, sliding_door.gd has `open_offset = Vector3(1.4, 0, 0)`. With scale 1.428 it becomes ~2.0. Perfect.
# Position X: the hole is centered at X=0, width 2.0. The door's origin is at its center.
# If we want it to close exactly, it should be at X=0.
node_str = """
[node name="ElevatorDoor" parent="." instance=ExtResource("6_door")]
transform = Transform3D(1.428, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.0, 4.9)
"""

content += node_str

with open(tscn_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Door and controller added.")
