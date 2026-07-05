import re

def parse_vector3(s):
    v = s.replace("Vector3(", "").replace(")", "").split(",")
    return float(v[0]), float(v[1]), float(v[2])

def parse_transform(s):
    v = s.replace("Transform3D(", "").replace(")", "").split(",")
    return float(v[9]), float(v[10]), float(v[11])

rooms = []
with open("rooms_geometry.txt", "r") as f:
    lines = f.readlines()
    curr_name = ""
    curr_pos = None
    curr_size = None
    for line in lines:
        if line.startswith("[node name="):
            if curr_name and curr_pos and curr_size:
                rooms.append({"name": curr_name, "pos": curr_pos, "size": curr_size, "type": "box"})
            curr_name = re.search(r'name="([^"]+)"', line).group(1)
            curr_pos = None
            curr_size = None
        elif line.startswith("transform ="):
            curr_pos = parse_transform(line.split("=", 1)[1])
        elif line.startswith("size ="):
            curr_size = parse_vector3(line.split("=", 1)[1])
    if curr_name and curr_pos and curr_size:
        rooms.append({"name": curr_name, "pos": curr_pos, "size": curr_size, "type": "box"})

props = []
prop_sizes = {
    "bed": (2.0, 0.5, 2.0),
    "wardrobe": (1.0, 2.0, 1.0),
    "table": (1.0, 1.0, 1.0),
    "chair": (0.5, 1.0, 0.5),
}
with open("props_geometry.txt", "r") as f:
    lines = f.readlines()
    curr_name = ""
    curr_pos = None
    curr_type = ""
    for line in lines:
        if line.startswith("[node name="):
            if curr_name and curr_pos:
                props.append({"name": curr_name, "pos": curr_pos, "size": prop_sizes.get(curr_type, (1,1,1)), "type": curr_type})
            curr_name = re.search(r'name="([^"]+)"', line).group(1)
            if "ExtResource" in line:
                curr_type = re.search(r'instance=ExtResource\("([^"]+)"\)', line)
                if curr_type:
                    curr_type = curr_type.group(1)
            curr_pos = None
        elif line.startswith("transform ="):
            curr_pos = parse_transform(line.split("=", 1)[1])
    if curr_name and curr_pos:
        props.append({"name": curr_name, "pos": curr_pos, "size": prop_sizes.get(curr_type, (1,1,1)), "type": curr_type})

def render_map(y_level):
    min_x, max_x = -15.0, 15.0
    min_z, max_z = -45.0, 0.0
    step = 0.5
    
    w = int((max_x - min_x) / step)
    h = int((max_z - min_z) / step)
    grid = [[" " for _ in range(w)] for _ in range(h)]
    
    # Render boxes
    for r in rooms:
        px, py, pz = r["pos"]
        sx, sy, sz = r["size"]
        
        if y_level >= py - sy/2 and y_level <= py + sy/2:
            x1 = int((px - sx/2 - min_x) / step)
            x2 = int((px + sx/2 - min_x) / step)
            z1 = int((pz - sz/2 - min_z) / step)
            z2 = int((pz + sz/2 - min_z) / step)
            
            x1 = max(0, min(w-1, x1))
            x2 = max(0, min(w-1, x2))
            z1 = max(0, min(h-1, z1))
            z2 = max(0, min(h-1, z2))
            
            char = "#" if "Wall" in r["name"] else "."
            for zi in range(z1, z2):
                for xi in range(x1, x2):
                    grid[zi][xi] = char
                    
    # Render props
    for p in props:
        px, py, pz = p["pos"]
        sx, sy, sz = p["size"]
        
        if y_level >= py - sy/2 and y_level <= py + sy/2:
            x1 = int((px - sx/2 - min_x) / step)
            x2 = int((px + sx/2 - min_x) / step)
            z1 = int((pz - sz/2 - min_z) / step)
            z2 = int((pz + sz/2 - min_z) / step)
            
            x1 = max(0, min(w-1, x1))
            x2 = max(0, min(w-1, x2))
            z1 = max(0, min(h-1, z1))
            z2 = max(0, min(h-1, z2))
            
            char = p["type"][0].upper()
            for zi in range(z1, z2):
                for xi in range(x1, x2):
                    grid[zi][xi] = char
                    
    res = ""
    for zi in range(h):
        res += "".join(grid[zi]) + "\n"
    return res

output = "\n\n## Actual Geometry Maps\n\n"
output += "### Map at Floor Level (Y=0.0)\n```text\n" + render_map(0.0) + "```\n\n"
output += "### Map at 1 Meter (Y=1.0)\n```text\n" + render_map(1.0) + "```\n\n"
output += "### Map at Wall/Ceiling intersection (Y=4.0)\n```text\n" + render_map(4.0) + "```\n\n"

output += """
### Object Descriptions
- **#**: Walls (Solid CSGBox3D structures defining the rooms and corridors).
- **.**: Floor/Ceiling areas.
- **B**: Bed. A large interactable furniture object where characters can rest or hide.
- **W**: Wardrobe. A tall wooden storage unit.
- **T**: Table. A standard desk/table.
- **C**: Chair. An interactable physics object.
- **Doorways**: The empty gaps in the walls between rooms and corridors represent the main doors and WC doors. 
"""

with open(".agents/AGENTS.md", "a") as f:
    f.write(output)

print("Appended maps to .agents/AGENTS.md")
