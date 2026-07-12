import re

with open('scenes/levels/hotel_siberia/blocks/north_stairs.tscn', 'r') as f:
    content = f.read()

nodes = content.split('\n\n')

new_nodes = []
combiner_walls = []
combiner_stairs = []

for node in nodes:
    if '[node name="NorthStairsBlock"' in node or '[ext_resource' in node or '[sub_resource' in node or '[gd_scene' in node:
        new_nodes.append(node)
    elif '[node name="StairsGeometry"' in node:
        new_nodes.append(node)
    elif 'StairsWestWall' in node or 'StairsEastWall' in node or 'StairsSouthWall' in node or 'DoorHole' in node:
        combiner_walls.append(node)
    elif 'EastFloor' in node or 'EastFlight' in node or 'NELanding' in node or 'NorthFlight' in node or 'NWLanding' in node or 'WestFlight' in node or 'WestFloor' in node:
        n = node.replace('parent="StairsGeometry"', 'parent="StairsInternal"')
        combiner_stairs.append(n)
    else:
        new_nodes.append(node)

combiner_internal = """[node name="StairsInternal" type="CSGCombiner3D" parent="."]
use_collision = true
collision_layer = 2"""

final_content = []
for n in new_nodes:
    if 'StairsGeometry' in n and 'CSGCombiner3D' in n:
        final_content.append(n)
        final_content.extend(combiner_walls)
        final_content.append(combiner_internal)
        final_content.extend(combiner_stairs)
    elif 'Light' in n:
        final_content.append(n)
    elif 'StairsGeometry' not in n:
        final_content.append(n)

with open('scenes/levels/hotel_siberia/blocks/north_stairs.tscn', 'w') as f:
    f.write('\n\n'.join(final_content))
