def replace_in_file(filepath, search_str, replace_str):
    with open(filepath, 'r') as f:
        content = f.read()
    content = content.replace(search_str, replace_str)
    with open(filepath, 'w') as f:
        f.write(content)

# single_room.tscn
# MainDoorHole: Z must be 0.45 (currently 0.60000 after scale script)
# DoorHole in WC_WallS: X must be 0.48 (currently 0.60000)
replace_in_file('scenes/levels/hotel_siberia/rooms/single_room.tscn', 
                'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.0, -0.75, 0.6)', 
                'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.0, -0.75, 0.45)')

replace_in_file('scenes/levels/hotel_siberia/rooms/single_room.tscn', 
                'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.6, -0.75, 0.0)', 
                'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.48, -0.75, 0.0)')

# double_room.tscn
# MainDoorHole: Z must be 0.75 (currently 0.60000)
# DoorHole in WC_WallW: Z must be 0.36 (currently 0.24000)
replace_in_file('scenes/levels/hotel_siberia/rooms/double_room.tscn', 
                'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.0, -0.75, 0.6)', 
                'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.0, -0.75, 0.75)')

replace_in_file('scenes/levels/hotel_siberia/rooms/double_room.tscn', 
                'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.0, -0.75, 0.24)', 
                'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.0, -0.75, 0.36)')

print("Holes aligned!")
