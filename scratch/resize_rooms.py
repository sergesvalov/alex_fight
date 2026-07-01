import re

def modify_room(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    lines = content.split('\n')
    out_lines = []
    
    current_node = None
    
    # regexes
    node_re = re.compile(r'\[node name="([^"]+)"')
    size_re = re.compile(r'size = Vector3\(([^,]+),\s*([^,]+),\s*([^)]+)\)')
    transform_re = re.compile(r'transform = Transform3D\(([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^)]+)\)')

    # Furniture scale
    furniture_names = ["Bed", "Table", "Chair", "Wardrobe"]

    def format_float(val):
        s = f"{val:.5f}".rstrip('0').rstrip('.')
        if '.' not in s and 'e' not in s:
            s += '.0'
        return s

    for line in lines:
        node_match = node_re.search(line)
        if node_match:
            current_node = node_match.group(1)
        
        # Scale sizes
        size_match = size_re.search(line)
        if size_match:
            if current_node and not current_node.endswith("Hole") and current_node != "RoomLabel":
                x, y, z = float(size_match.group(1)), float(size_match.group(2)), float(size_match.group(3))
                # Only scale X and Z for walls/floors
                line = f"size = Vector3({format_float(x*1.2)}, {format_float(y)}, {format_float(z*1.2)})"
        
        # Scale transforms
        transform_match = transform_re.search(line)
        if transform_match:
            m11, m12, m13 = transform_match.group(1), transform_match.group(2), transform_match.group(3)
            m21, m22, m23 = transform_match.group(4), transform_match.group(5), transform_match.group(6)
            m31, m32, m33 = transform_match.group(7), transform_match.group(8), transform_match.group(9)
            ox, oy, oz = float(transform_match.group(10)), float(transform_match.group(11)), float(transform_match.group(12))
            
            # Check if this is furniture to apply 1.1 scale to basis
            is_furniture = any(current_node.startswith(f) for f in furniture_names) if current_node else False
            
            if is_furniture:
                # Apply 1.1 scale to basis vectors
                m11 = format_float(float(m11) * 1.1)
                m12 = format_float(float(m12) * 1.1)
                m13 = format_float(float(m13) * 1.1)
                m21 = format_float(float(m21) * 1.1)
                m22 = format_float(float(m22) * 1.1)
                m23 = format_float(float(m23) * 1.1)
                m31 = format_float(float(m31) * 1.1)
                m32 = format_float(float(m32) * 1.1)
                m33 = format_float(float(m33) * 1.1)

            # Scale origin X and Z by 1.2
            ox_new = format_float(ox * 1.2)
            oz_new = format_float(oz * 1.2)
            oy_new = format_float(oy)
            
            line = f"transform = Transform3D({m11}, {m12}, {m13}, {m21}, {m22}, {m23}, {m31}, {m32}, {m33}, {ox_new}, {oy_new}, {oz_new})"
            
        out_lines.append(line)
        
    with open(filepath, 'w') as f:
        f.write('\n'.join(out_lines))
    print(f"Scaled {filepath}")

modify_room('scenes/levels/hotel_siberia/rooms/single_room.tscn')
modify_room('scenes/levels/hotel_siberia/rooms/double_room.tscn')
