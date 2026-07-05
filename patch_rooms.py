import re

def patch_room(filepath, door_pos, door_rot, hole_pos):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Check if already patched
    if "CorridorHole" in content:
        print(f"{filepath} already patched.")
        return

    # 1. Add door scene dependency if not exists
    ext_id = None
    match = re.search(r'\[ext_resource type="PackedScene" path="res://entities/props/door.tscn" id="([^"]+)"\]', content)
    if match:
        ext_id = match.group(1)
    else:
        # Find next available id
        import uuid
        ext_id = "door_" + uuid.uuid4().hex[:6]
        ext_line = f'[ext_resource type="PackedScene" path="res://entities/props/door.tscn" id="{ext_id}"]\n'
        
        # Insert after the last ext_resource
        last_ext_idx = content.rfind('[ext_resource')
        if last_ext_idx != -1:
            end_of_line = content.find('\n', last_ext_idx) + 1
            content = content[:end_of_line] + ext_line + content[end_of_line:]
        else:
            first_node_idx = content.find('[node')
            content = content[:first_node_idx] + ext_line + content[first_node_idx:]

    # 2. Add CorridorHole node
    hole_node = f"""
[node name="CorridorHole" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {hole_pos[0]}, {hole_pos[1]}, {hole_pos[2]})
operation = 2
size = Vector3(1.2, 2.05, 1.0)
"""

    # 3. Add MainDoor node
    door_node = f"""
[node name="MainDoor" parent="." instance=ExtResource("{ext_id}")]
transform = Transform3D({door_rot}, {door_pos[0]}, {door_pos[1]}, {door_pos[2]})
"""

    # Append nodes to the end of the file
    content += hole_node + door_node

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
        
    print(f"Patched {filepath}")

# Single Room (Right side)
# door rotation: -PI/2 around Y
# cos(-90)=0, sin(-90)=-1
# basis: 
# [ 0, 0, -1]
# [ 0, 1,  0]
# [ 1, 0,  0]
rot_single = "0, 0, 1, 0, 1, 0, -1, 0, 0"
patch_room(
    "scenes/levels/hotel_siberia/rooms/single_room.tscn", 
    (-3.05, 0, -0.25), rot_single, (-2.75, 1.025, -0.25)
)

# Double Room (Left side)
# door rotation: PI/2 around Y
# cos(90)=0, sin(90)=1
# basis:
# [ 0, 0, 1]
# [ 0, 1, 0]
# [-1, 0, 0]
rot_double = "0, 0, -1, 0, 1, 0, 1, 0, 0"
patch_room(
    "scenes/levels/hotel_siberia/rooms/double_room.tscn", 
    (4.3, 0, 0.5), rot_double, (4.0, 1.025, 0.5)
)
patch_room(
    "scenes/levels/hotel_siberia/rooms/double_room_large.tscn", 
    (4.3, 0, 0.5), rot_double, (4.0, 1.025, 0.5)
)
