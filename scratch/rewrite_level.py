import re

def process_file():
    with open('scenes/levels/hotel_siberia/base_hotel_level.tscn', 'r', encoding='utf-8') as f:
        content = f.read()

    start_str = '[node name="HotelGeometry" type="Node3D" parent="NavigationRegion3D"]\nscript = ExtResource("99_generator")'
    end_str = '[node name="InteractableObjects" type="Node3D" parent="."]'

    start_idx = content.find(start_str)
    if start_idx == -1:
        # try without script
        start_str = '[node name="HotelGeometry" type="Node3D" parent="NavigationRegion3D"]'
        start_idx = content.find(start_str)
        
    end_idx = content.find(end_str)

    if start_idx == -1 or end_idx == -1:
        print("Could not find start or end block")
        return

    before = content[:start_idx]
    after = content[end_idx:]

    out = []
    out.append('[node name="HotelGeometry" type="Node3D" parent="NavigationRegion3D"]')
    out.append('script = ExtResource("99_generator")')
    out.append('generate = false')
    out.append('num_double_rooms = 6')
    out.append('num_single_rooms = 9')
    out.append('double_room_step = 10.0')
    out.append('single_room_step = 6.0')
    out.append('corridor_width = 7.0')
    out.append('corridor_height = 4.25')
    out.append('')

    # Re-insert the static elements
    out.append('[node name="SideCorridorFloor" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry"]')
    out.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.5, 0, 7.5)')
    out.append('use_collision = true')
    out.append('collision_layer = 2')
    out.append('size = Vector3(9, 0.5, 4)')
    out.append('material = SubResource("StandardMaterial3D_floor")')
    out.append('')
    
    out.append('[node name="SideCorridorCeiling" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry"]')
    out.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.5, 4.25, 7.5)')
    out.append('use_collision = true')
    out.append('collision_layer = 2')
    out.append('size = Vector3(9, 4, 1)')
    out.append('material = SubResource("StandardMaterial3D_wall")')
    out.append('')

    out.append('[node name="ElevatorWallS" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry"]')
    out.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.5, 2, 5.5)')
    out.append('use_collision = true')
    out.append('collision_layer = 2')
    out.append('size = Vector3(9, 4, 1)')
    out.append('material = SubResource("StandardMaterial3D_wall")')
    out.append('')
    out.append('[node name="ElevatorDoorHole" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry/ElevatorWallS"]')
    out.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.75, 0)')
    out.append('operation = 2')
    out.append('size = Vector3(3, 2.5, 2)')
    out.append('')
    
    out.append('[node name="ElevatorShaft" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry"]')
    out.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.5, 2, 2.5)')
    out.append('use_collision = true')
    out.append('collision_layer = 2')
    out.append('size = Vector3(6, 4, 5)')
    out.append('material = SubResource("StandardMaterial3D_wall")')
    out.append('flip_faces = true')
    out.append('')

    out.append('[node name="MaintenanceWallW" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry"]')
    out.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 2, 7.5)')
    out.append('use_collision = true')
    out.append('collision_layer = 2')
    out.append('size = Vector3(1, 4, 5)')
    out.append('material = SubResource("StandardMaterial3D_wall")')
    out.append('')
    out.append('[node name="MaintenanceDoorHole" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry/MaintenanceWallW"]')
    out.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.75, 0)')
    out.append('operation = 2')
    out.append('size = Vector3(2, 2.5, 1.5)')
    out.append('')

    out.append('[node name="MaintenanceRoom" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry"]')
    out.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 15, 2, 7.5)')
    out.append('use_collision = true')
    out.append('collision_layer = 2')
    out.append('size = Vector3(6, 4, 5)')
    out.append('material = SubResource("StandardMaterial3D_wall")')
    out.append('flip_faces = true')
    out.append('')

    out.append('[node name="ElevatorLight" type="OmniLight3D" parent="NavigationRegion3D/HotelGeometry"]')
    out.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.5, 3.5, 4.0)')
    out.append('light_color = Color(0.9, 0.95, 1, 1)')
    out.append('omni_range = 8.0')
    out.append('')
    
    out.append('[node name="MaintenanceLight" type="OmniLight3D" parent="NavigationRegion3D/HotelGeometry"]')
    out.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 15, 3.5, 7.5)')
    out.append('light_color = Color(1, 0.9, 0.7, 1)')
    out.append('omni_range = 8.0')
    out.append('')

    out.append('[node name="Stairwell_N" parent="NavigationRegion3D/HotelGeometry" instance=ExtResource("stairwell")]')
    out.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 5.0)')
    out.append('')



    out.append('[node name="CorrWallNorthEnd" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry"]')
    out.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -3.5, 2, 5.0)') 
    out.append('use_collision = true')
    out.append('collision_layer = 2')
    out.append('size = Vector3(1, 4, 10)')
    out.append('material = SubResource("StandardMaterial3D_wall")')
    out.append('')



    out.append('[node name="MapDecal" type="MeshInstance3D" parent="NavigationRegion3D/HotelGeometry"]')
    out.append('transform = Transform3D(-4.37114e-08, 0, -1, 0, 1, 0, 1, 0, -4.37114e-08, 2.99, 2, -10.0)')
    out.append('mesh = SubResource("QuadMesh_map")')
    out.append('')

    # NOW THE PROCEDURAL STUFF
    out.append('[node name="CorridorFloor" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry"]')
    out.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -22.5)')
    out.append('use_collision = true')
    out.append('collision_layer = 2')
    out.append('size = Vector3(7, 0.5, 65)') # From +10 to -55
    out.append('material = SubResource("StandardMaterial3D_floor")')
    out.append('')
    
    out.append('[node name="CorridorCeiling" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry"]')
    out.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 4.25, -22.5)')
    out.append('use_collision = true')
    out.append('collision_layer = 2')
    out.append('size = Vector3(7, 0.5, 65)')
    out.append('material = SubResource("StandardMaterial3D_floor")')
    out.append('')

    def add_wall(name, x, y, z_center, size_z):
        out.append(f'[node name="{name}" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry"]')
        out.append(f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z_center})')
        out.append('use_collision = true')
        out.append('collision_layer = 2')
        out.append(f'size = Vector3(1, 4, {size_z})')
        out.append('material = SubResource("StandardMaterial3D_wall")')
        out.append('')

    L_centers = [ -5.0 - i*10.0 for i in range(6) ] 
    
    prev_z = 0.0
    for i, c in enumerate(L_centers):
        gap_start = c + 1.25
        gap_end = c - 0.25
        length = prev_z - gap_start
        center = (prev_z + gap_start) / 2.0
        if length > 0:
            add_wall(f"CorrWallW{i+1}", -3.5, 2, center, length)
        prev_z = gap_end
    
    length = prev_z - (-55.0)
    center = (prev_z + -55.0) / 2.0
    if length > 0:
        add_wall(f"CorrWallW_End", -3.5, 2, center, length)

    R_centers = [ -3.0 - i*6.0 for i in range(9) ]
    prev_z = 0.0
    for i, c in enumerate(R_centers):
        gap_start = c + 1.25
        gap_end = c - 0.25
        length = prev_z - gap_start
        center = (prev_z + gap_start) / 2.0
        if length > 0:
            add_wall(f"CorrWallE{i+1}", 3.5, 2, center, length)
        prev_z = gap_end
    
    length = prev_z - (-55.0)
    center = (prev_z + -55.0) / 2.0
    if length > 0:
        add_wall(f"CorrWallE_End", 3.5, 2, center, length)

    dbl_labels = ["401", "402", "403", "405", "406", "408"]
    for i, c in enumerate(L_centers):
        out.append(f'[node name="DoubleRoomL{i+1}" parent="NavigationRegion3D/HotelGeometry" instance=ExtResource("double_room")]')
        out.append(f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -7.5, 0, {c})')
        out.append(f'room_number = "{dbl_labels[i]}"')
        out.append('')

    sngl_labels = ["410", "411", "412", "413", "415", "416", "417", "420", "421"]
    for i, c in enumerate(R_centers):
        out.append(f'[node name="SingleRoomR{i+1}" parent="NavigationRegion3D/HotelGeometry" instance=ExtResource("single_room")]')
        out.append(f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 6.5, 0, {c})')
        out.append(f'room_number = "{sngl_labels[i]}"')
        out.append('')

    corridor_end_z = min(L_centers[-1], R_centers[-1])
    stair_z = corridor_end_z - 10.0
    
    out.append('[node name="Stairwell_S" parent="NavigationRegion3D/HotelGeometry" instance=ExtResource("stairwell")]')
    out.append(f'transform = Transform3D(-1, 0, -8.74228e-08, 0, 1, 0, 8.74228e-08, 0, -1, 0, 0, {stair_z})')
    out.append('')
    
    out.append('[node name="CorrWallSouthEnd" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry"]')
    out.append(f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2, {stair_z - 1.5})') 
    out.append('use_collision = true')
    out.append('collision_layer = 2')
    out.append('size = Vector3(6, 4, 1)')
    out.append('material = SubResource("StandardMaterial3D_wall")')
    out.append('')

    new_content = before + "\n".join(out) + after
    
    # We must ensure there are no lingering RoomLabels!
    # They should all be gone since we completely replace the HotelGeometry block.

    with open('scenes/levels/hotel_siberia/base_hotel_level.tscn', 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Rewritten base_hotel_level.tscn cleanly.")

process_file()
