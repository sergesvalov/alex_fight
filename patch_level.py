import re

def process_tscn():
    with open('scenes/levels/hotel_siberia/hotel_level.tscn', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Update BoxShape3D_corridor_floor and BoxMesh_corridor_floor
    content = re.sub(r'(\[sub_resource type="BoxShape3D" id="BoxShape3D_corridor_floor"\]\nsize = Vector3\(6, 0.5, )40\)', r'\g<1>80)', content)
    content = re.sub(r'(\[sub_resource type="BoxMesh" id="BoxMesh_corridor_floor"\]\nmaterial = SubResource\("StandardMaterial3D_floor"\)\nsize = Vector3\(6, 0.5, )40\)', r'\g<1>80)', content)

    # 2. Update CorridorFloor and CorridorCeiling transform
    content = re.sub(r'(\[node name="CorridorFloor".*?\ntransform = Transform3D\(.*?, )-25\)', r'\g<1>-45)', content)
    content = re.sub(r'(\[node name="CorridorCeiling".*?\ntransform = Transform3D\(.*?, )-25\)', r'\g<1>-45)', content)

    # 3. Shift end-of-corridor elements by -40 in Z
    shift_nodes = [
        "SideCorridorFloor",
        "SideCorridorCeiling",
        "ElevatorWallS",
        "ElevatorShaft",
        "MaintenanceWallW",
        "MaintenanceRoom",
        "ElevatorLight",
        "MaintenanceLight",
        "Stairwell",
    ]
    for node in shift_nodes:
        # Find the node's transform line and subtract 40 from the Z value
        # The node block starts with [node name="..."] and the next line with transform
        pattern = r'(\[node name="' + node + r'".*?\]\ntransform = Transform3D\(1, 0, 0, 0, 1, 0, 0, 0, 1, [-\d.]+, [-\d.]+, )([-\d.]+)\)'
        def repl(m):
            z = float(m.group(2))
            return m.group(1) + str(z - 40.0) + ')'
        content = re.sub(pattern, repl, content)

    # Fix SideCorridorFloor and SideCorridorCeiling that have width of 9, they should be shifted too.
    # Wait, the code above does shift them!

    # 4. Generate new nodes
    rooms_left = [-12.5, -25.0, -37.5, -50.0, -62.5, -75.0]
    rooms_right = [-11.0, -19.0, -27.0, -35.0, -43.0, -51.0, -59.0, -67.0, -75.0]

    out = '\n'
    def make_wall(name, x, start_z, end_z):
        center_z = (start_z + end_z) / 2.0
        length = abs(end_z - start_z)
        return f'[node name="{name}" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, 2, {center_z})\nuse_collision = true\ncollision_layer = 2\nsize = Vector3(1, 4, {length})\nmaterial = SubResource("StandardMaterial3D_wall")\n\n'

    left_door_centers = [z + 0.5 for z in rooms_left]
    left_wall_start = -5.0
    for i, dc in enumerate(left_door_centers):
        door_start = dc + 1.0 # higher Z value (closer to 0)
        door_end = dc - 1.0
        out += make_wall(f'CorrWallW{i+1}', -3.5, left_wall_start, door_start)
        left_wall_start = door_end
    out += make_wall(f'CorrWallW{len(left_door_centers)+1}', -3.5, left_wall_start, -85.0)

    right_door_centers = [z for z in rooms_right]
    right_wall_start = -5.0
    for i, dc in enumerate(right_door_centers):
        door_start = dc + 1.0
        door_end = dc - 1.0
        out += make_wall(f'CorrWallE{i+1}', 3.5, right_wall_start, door_start)
        right_wall_start = door_end
    out += make_wall(f'CorrWallE{len(right_door_centers)+1}', 3.5, right_wall_start, -85.0)

    for i, z in enumerate(rooms_left):
        out += f'[node name="DoubleRoomL{i+1}" parent="NavigationRegion3D/HotelGeometry" instance=ExtResource("double_room")]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -7.5, 0, {z})\n\n'

    for i, z in enumerate(rooms_right):
        out += f'[node name="SingleRoomR{i+1}" parent="NavigationRegion3D/HotelGeometry" instance=ExtResource("single_room")]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 6.5, 0, {z})\n\n'

    # 5. Remove old nodes (CorrWallW1..4, CorrWallE1..4, DoubleRoomL1..3, SingleRoomR1..3)
    # The nodes to remove are exactly between CorridorCeiling block and SideCorridorFloor block.
    # Wait, SideCorridorFloor is right after CorrWallE4. So we can replace everything from [node name="CorrWallW1"] to the line before [node name="SideCorridorFloor"].
    # Wait, we also need to remove old rooms: DoubleRoomL1-L3 and SingleRoomR1-R3 which are between MaintenanceLight and Stairwell.
    
    # We will do targeted removal of node blocks.
    def remove_node(node_name, text):
        # Remove from [node name="node_name" ...] to the next [node name=...] or end of file
        # We need to be careful with children. Actually, all these are flat under NavigationRegion3D/HotelGeometry.
        # So we can match [node name="node_name".*?(?=\n\[node|\Z)
        pattern = r'\n\[node name="' + node_name + r'".*?(?=\n\[node|\Z)'
        return re.sub(pattern, '', text, flags=re.DOTALL)

    for i in range(1, 5):
        content = remove_node(f'CorrWallW{i}', content)
        content = remove_node(f'CorrWallE{i}', content)
    for i in range(1, 4):
        content = remove_node(f'DoubleRoomL{i}', content)
        content = remove_node(f'SingleRoomR{i}', content)

    # Insert new nodes right before [node name="Stairwell"
    # Actually, let's insert them right before [node name="MapDecal" or at the end of HotelGeometry
    content = content.replace('\n[node name="MapDecal"', out + '\n[node name="MapDecal"')

    # 6. Shift player and cassettes, dead bodies
    # VhsTape_1 to DoubleRoomL6 (Z=-75.0, X=-7.5, table is at -1.5, Z=4.5 local? No, DoubleRoom main table is Table1 at (-1.5, 0, 4.5) relative.
    # Global table pos: X = -7.5 - 1.5 = -9.0. Z = -75.0 + 4.5 = -70.5. Height = 1.0.
    content = re.sub(r'(\[node name="VhsTape_1".*?\ntransform = Transform3D\(.*?, )0, 1, -5\)', r'\g<1>-9, 1, -70.5)', content)
    
    # VhsTape_2 to Corridor (Z=-40)
    content = re.sub(r'(\[node name="VhsTape_2".*?\ntransform = Transform3D\(.*?, )0, 1, -15\)', r'\g<1>0, 1, -40)', content)
    
    # VhsTape_3 near Elevator (X=7.5, Z=-46) Wait, ElevatorLight is at Z=-86 after shift. Let's put tape at X=3, Z=-80.
    content = re.sub(r'(\[node name="VhsTape_3".*?\ntransform = Transform3D\(.*?, )0, 1, -35\)', r'\g<1>3, 1, -80)', content)
    
    # Player start in Room 408 (DoubleRoomL6 at Z=-75). Let's put at X=-7.5, Z=-75.
    content = re.sub(r'(\[node name="Player".*?\ntransform = Transform3D\(.*?, )0, 2, 0\)', r'\g<1>-7.5, 2, -75)', content)

    # Shift dead bodies if needed?
    # DeadBody_1 at Z=-12. Leave it.
    # DeadBody_2 at Z=-28. Leave it.

    # 7. Extend PatrolPoints
    # Point1 at 0, -10. Point2 at 0, -25. Point3 at 0, -40. Point4 at 0, -20.
    # Let's rewrite PatrolPoints block.
    patrol_points = '''[node name="Point1" type="Marker3D" parent="Enemies/PatrolPoints"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -20)

[node name="Point2" type="Marker3D" parent="Enemies/PatrolPoints"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -40)

[node name="Point3" type="Marker3D" parent="Enemies/PatrolPoints"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -60)

[node name="Point4" type="Marker3D" parent="Enemies/PatrolPoints"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -80)
'''
    content = re.sub(r'(\[node name="Point1" type="Marker3D" parent="Enemies/PatrolPoints"\].*?)(?=\n\[node name="Cerberus")', patrol_points + '\n', content, flags=re.DOTALL)

    # Shift Cerberus spawn point to Z=-80
    content = re.sub(r'(\[node name="Cerberus".*?\ntransform = Transform3D\(.*?, )0, 1, -30\)', r'\g<1>0, 1, -80)', content)

    with open('scenes/levels/hotel_siberia/hotel_level.tscn', 'w', encoding='utf-8') as f:
        f.write(content)

process_tscn()
