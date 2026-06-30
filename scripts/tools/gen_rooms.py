rooms_text = ""

# West corridor walls (x = -3.5)
west_walls = [
    ("CorrWallW1", -3.5, -8, 1, 6),
    ("CorrWallW2", -3.5, -18.75, 1, 9.5),
    ("CorrWallW3", -3.5, -31.25, 1, 9.5),
    ("CorrWallW4", -3.5, -42, 1, 6)
]
# East corridor walls (x = 3.5)
east_walls = [
    ("CorrWallE1", 3.5, -8, 1, 6),
    ("CorrWallE2", 3.5, -18.75, 1, 9.5),
    ("CorrWallE3", 3.5, -31.25, 1, 9.5),
    ("CorrWallE4", 3.5, -42, 1, 6)
]

def make_wall(name, x, z, size_x, size_z):
    return f'''
[node name="{name}" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, 2, {z})
use_collision = true
collision_layer = 2
size = Vector3({size_x}, 4, {size_z})
material = SubResource("StandardMaterial3D_wall")
'''

def make_floor(name, x, y, z, size_x, size_z):
    return f'''
[node name="{name}" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})
use_collision = true
collision_layer = 2
size = Vector3({size_x}, 0.5, {size_z})
material = SubResource("StandardMaterial3D_floor")
'''

for w in west_walls + east_walls:
    rooms_text += make_wall(*w)

z_centers = [-12.5, -25.0, -37.5]
for i in range(3):
    z = z_centers[i]
    p = f"RoomL{i+1}"
    rooms_text += make_floor(p+"_Floor", -8, 0, z, 8, 10)
    rooms_text += make_floor(p+"_Ceil", -8, 4.25, z, 8, 10)
    rooms_text += make_wall(p+"_WallW", -12, 2, z, 1, 10)
    rooms_text += make_wall(p+"_WallN", -8, 2, z - 5, 9, 1)
    rooms_text += make_wall(p+"_WallS", -8, 2, z + 5, 9, 1)

for i in range(3):
    z = z_centers[i]
    p = f"RoomR{i+1}"
    rooms_text += make_floor(p+"_Floor", 7, 0, z, 6, 6)
    rooms_text += make_floor(p+"_Ceil", 7, 4.25, z, 6, 6)
    rooms_text += make_wall(p+"_WallE", 10, 2, z, 1, 6)
    rooms_text += make_wall(p+"_WallN", 7, 2, z - 3, 7, 1)
    rooms_text += make_wall(p+"_WallS", 7, 2, z + 3, 7, 1)

with open("rooms_geometry.txt", "w") as f:
    f.write(rooms_text)

print("Generated rooms_geometry.txt")
