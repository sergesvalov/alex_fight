import re

files = [
    'entities/props/bed.tscn',
    'entities/props/chair.tscn',
    'entities/props/table.tscn',
    'entities/props/wardrobe.tscn'
]

def format_float(val):
    # Format float cleanly
    s = f"{val:.5f}".rstrip('0').rstrip('.')
    if '.' not in s and 'e' not in s:
        s += '.0'
    return s

for filepath in files:
    with open(filepath, 'r') as f:
        content = f.read()

    def repl_size(m):
        x, y, z = float(m.group(1)), float(m.group(2)), float(m.group(3))
        return f"size = Vector3({format_float(x*1.5)}, {format_float(y*1.5)}, {format_float(z*1.5)})"
    content = re.sub(r'size = Vector3\(([^,]+),\s*([^,]+),\s*([^)]+)\)', repl_size, content)

    def repl_transform(m):
        m11, m12, m13 = m.group(1), m.group(2), m.group(3)
        m21, m22, m23 = m.group(4), m.group(5), m.group(6)
        m31, m32, m33 = m.group(7), m.group(8), m.group(9)
        x, y, z = float(m.group(10)), float(m.group(11)), float(m.group(12))
        return f"transform = Transform3D({m11}, {m12}, {m13}, {m21}, {m22}, {m23}, {m31}, {m32}, {m33}, {format_float(x*1.5)}, {format_float(y*1.5)}, {format_float(z*1.5)})"

    content = re.sub(r'transform = Transform3D\(([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^)]+)\)', repl_transform, content)

    with open(filepath, 'w') as f:
        f.write(content)
    print(f"Scaled {filepath}")
