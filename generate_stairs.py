def generate_east_flight():
    lines = []
    lines.append('########## EAST FLIGHT ##########')
    for i in range(10):
        y_top = 0.15 * (i + 1)
        size_y = y_top
        pos_y = size_y / 2.0
        pos_z = 3.7 - (i * 0.25) - 0.125
        lines.append(f'[node name="EastStep_{i}" type="CSGBox3D" parent="StairsGeometry"]')
        lines.append(f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 2.5, {pos_y:.3f}, {pos_z:.3f})')
        lines.append(f'size = Vector3(2.4, {size_y:.3f}, 0.25)')
        lines.append(f'material = SubResource("StandardMaterial3D_floor")\n')
    return "\n".join(lines)

def generate_north_flight():
    lines = []
    lines.append('########## NORTH FLIGHT ##########')
    for i in range(10):
        size_y = 0.15 * (i + 1)
        pos_y = 1.5 + size_y / 2.0
        pos_x = 1.3 - (i * 0.26) - 0.13
        lines.append(f'[node name="NorthStep_{i}" type="CSGBox3D" parent="StairsGeometry"]')
        lines.append(f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {pos_x:.3f}, {pos_y:.3f}, 0.6)')
        lines.append(f'size = Vector3(0.26, {size_y:.3f}, 1.2)')
        lines.append(f'material = SubResource("StandardMaterial3D_floor")\n')
    return "\n".join(lines)

def generate_west_flight():
    lines = []
    lines.append('########## WEST FLIGHT ##########')
    for i in range(10):
        size_y = 0.15 * (i + 1)
        pos_y = 3.0 + size_y / 2.0
        pos_z = 1.2 + (i * 0.25) + 0.125
        lines.append(f'[node name="WestStep_{i}" type="CSGBox3D" parent="StairsGeometry"]')
        lines.append(f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2.5, {pos_y:.3f}, {pos_z:.3f})')
        lines.append(f'size = Vector3(2.4, {size_y:.3f}, 0.25)')
        lines.append(f'material = SubResource("StandardMaterial3D_floor")\n')
    return "\n".join(lines)

with open('stairs_output.txt', 'w') as f:
    f.write(generate_east_flight() + "\n" + generate_north_flight() + "\n" + generate_west_flight())
