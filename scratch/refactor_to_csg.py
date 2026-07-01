import re
import os

file_path = "scenes/levels/hotel_siberia/base_hotel_level.tscn"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Subresource mapping
mesh_map = {
    "BoxMesh_floor": {"size": "Vector3(10, 0.5, 10)", "material": 'SubResource("StandardMaterial3D_floor")'},
    "BoxMesh_wall": {"size": "Vector3(10, 4, 1)", "material": 'SubResource("StandardMaterial3D_wall")'},
    "BoxMesh_wall_half": {"size": "Vector3(3.5, 4, 1)", "material": 'SubResource("StandardMaterial3D_wall")'},
    "BoxMesh_corridor_floor": {"size": "Vector3(6, 0.5, 40)", "material": 'SubResource("StandardMaterial3D_floor")'},
    "BoxMesh_corridor_wall": {"size": "Vector3(1, 4, 40)", "material": 'SubResource("StandardMaterial3D_wall")'},
    "BoxMesh_corridor_wall_end": {"size": "Vector3(6, 4, 1)", "material": 'SubResource("StandardMaterial3D_wall")'},
}

# Regex to find StaticBody3D blocks
# A block starts with [node name="..." type="StaticBody3D" parent="NavigationRegion3D/HotelGeometry"]
# and ends right before the next [node
pattern = re.compile(
    r'\[node name="([^"]+)" type="StaticBody3D" parent="NavigationRegion3D/HotelGeometry"\]\n(.*?)(?=\n\[node|$)',
    re.DOTALL
)

def replace_block(match):
    name = match.group(1)
    body = match.group(2)
    
    # Check if this is one of our target bodies (it has a MeshInstance3D with a BoxMesh)
    mesh_match = re.search(r'\[node name="MeshInstance3D" type="MeshInstance3D" parent="[^"]+"\]\nmesh = SubResource\("([^"]+)"\)', body)
    if not mesh_match:
        return match.group(0) # don't modify
    
    mesh_id = mesh_match.group(1)
    if mesh_id not in mesh_map:
        return match.group(0)
    
    # Extract transform if it exists
    transform_match = re.search(r'transform = (.*)', body)
    transform_str = transform_match.group(1) if transform_match else None
    
    # Construct CSGBox3D
    size = mesh_map[mesh_id]["size"]
    material = mesh_map[mesh_id]["material"]
    
    res = f'[node name="{name}" type="CSGBox3D" parent="NavigationRegion3D/HotelGeometry/CorridorCSG"]\n'
    if transform_str:
        res += f'transform = {transform_str}\n'
    res += f'size = {size}\n'
    res += f'material = {material}\n'
    
    return res

new_content = pattern.sub(replace_block, content)

# Also, we need to add the CorridorCSG node itself before the first child of HotelGeometry
# Let's insert it after [node name="HotelGeometry" type="Node3D" parent="NavigationRegion3D"]
csg_node = """
[node name="CorridorCSG" type="CSGCombiner3D" parent="NavigationRegion3D/HotelGeometry"]
use_collision = true
collision_layer = 2
"""
new_content = new_content.replace('[node name="HotelGeometry" type="Node3D" parent="NavigationRegion3D"]', '[node name="HotelGeometry" type="Node3D" parent="NavigationRegion3D"]\n' + csg_node)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(new_content)

print("Refactored to CSG!")
