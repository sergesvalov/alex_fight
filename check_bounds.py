import re
def get_bounds(filepath, global_z):
    with open(filepath, 'r') as f:
        content = f.read()
    min_z, max_z = float('inf'), float('-inf')
    for block in re.finditer(r'\[node name=".*?" type="CSGBox3D".*?\]\s+transform = Transform3D\((.*?)\).*?size = Vector3\((.*?)\)', content, re.DOTALL):
        trans = [float(x) for x in block.group(1).split(', ')]
        size = [float(x) for x in block.group(2).split(', ')]
        local_z = trans[11]
        s_z = size[2]
        left = local_z - (s_z / 2.0)
        right = local_z + (s_z / 2.0)
        g_left = left + global_z
        g_right = right + global_z
        min_z = min(min_z, g_left)
        max_z = max(max_z, g_right)
    return min_z, max_z
s_n_min, s_n_max = get_bounds('scenes/levels/hotel_siberia/stairwell_north.tscn', 10.0)
print(f'Stair North Z bounds: {s_n_min} to {s_n_max}')
