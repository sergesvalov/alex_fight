import re
import math

def parse_vector3(s):
    v = s.replace("Vector3(", "").replace(")", "").split(",")
    return float(v[0].strip()), float(v[1].strip()), float(v[2].strip())

def parse_transform(s):
    v = s.replace("Transform3D(", "").replace(")", "").split(",")
    # xx, xy, xz, yx, yy, yz, zx, zy, zz, px, py, pz
    return [float(x.strip()) for x in v]

def parse_tscn(filepath):
    walls = []
    props = []
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    curr_name = ""
    curr_tf = None
    curr_size = None
    curr_type = None
    
    for line in lines:
        if line.startswith("[node name="):
            if curr_name and curr_tf:
                if curr_size:
                    walls.append({"name": curr_name, "tf": curr_tf, "size": curr_size})
                elif curr_type:
                    props.append({"name": curr_name, "tf": curr_tf, "type": curr_type})
                    
            match = re.search(r'name="([^"]+)"', line)
            curr_name = match.group(1) if match else ""
            curr_tf = None
            curr_size = None
            curr_type = None
            
            if "CSGBox3D" in line:
                curr_type = "wall"
            elif "ExtResource" in line:
                m_type = re.search(r'instance=ExtResource\("([^"]+)"\)', line)
                if m_type:
                    curr_type = m_type.group(1).split('_')[-1]
                    
        elif line.startswith("transform ="):
            curr_tf = parse_transform(line.split("=", 1)[1])
        elif line.startswith("size ="):
            curr_size = parse_vector3(line.split("=", 1)[1])
            
    if curr_name and curr_tf:
        if curr_size:
            walls.append({"name": curr_name, "tf": curr_tf, "size": curr_size})
        elif curr_type:
            props.append({"name": curr_name, "tf": curr_tf, "type": curr_type})
            
    return walls, props

db_walls, db_props = parse_tscn("scenes/levels/hotel_siberia/blocks/double_room.tscn")
sg_walls, sg_props = parse_tscn("scenes/levels/hotel_siberia/blocks/single_room.tscn")

with open("scripts/levels/hotel_level_generator.gd", "r", encoding='utf-8') as f:
    code = f.read()
    
global_rooms = []
blocks = code.split('func _generate_')
for b in blocks:
    if 'Room_' not in b: continue
    m = re.search(r'inst\.name = "(Double|Single)Room_(\d+)"', b)
    if not m: continue
    r_type = m.group(1).lower()
    r_num = m.group(2)
    m_pos = re.search(r'inst\.position = Vector3\(([^,]+),([^,]+),([^)]+)\)', b)
    if m_pos:
        px = float(m_pos.group(1).replace("* f_scale","").strip())
        py = float(m_pos.group(2).replace("* f_scale","").strip())
        pz = float(m_pos.group(3).replace("* f_scale","").strip())
        mirrored = 'inst.scale.z = -1.0' in b
        global_rooms.append({"type": r_type, "num": r_num, "pos": (px, py, pz), "mirrored": mirrored})

all_walls = []
all_props = []

for r in global_rooms:
    bx, by, bz = r["pos"]
    mirrored = r["mirrored"]
    z_sign = -1.0 if mirrored else 1.0
    
    walls = db_walls if r["type"] == "double" else sg_walls
    props = db_props if r["type"] == "double" else sg_props
    
    for w in walls:
        tf = w["tf"]
        lx, ly, lz = tf[9], tf[10], tf[11]
        lz *= z_sign
        all_walls.append({"name": w["name"], "pos": (bx+lx, by+ly, bz+lz), "size": w["size"], "type": "box"})
        
    for p in props:
        if p["type"] == "wall": continue
        tf = p["tf"]
        lx, ly, lz = tf[9], tf[10], tf[11]
        lz *= z_sign
        
        xx = tf[0]
        swapped = abs(xx) < 0.5
        all_props.append({"name": p["name"], "pos": (bx+lx, by+ly, bz+lz), "type": p["type"], "swapped": swapped})

prop_sizes = {
    "bed": (2.0, 0.5, 2.0),
    "wardrobe": (1.0, 2.0, 1.0),
    "table": (1.0, 1.0, 1.0),
    "chair": (0.5, 1.0, 0.5),
    "door": (1.0, 2.2, 0.1), # Assuming door is natively thin in X, wide in Z
}

def render_map(y_level):
    min_x, max_x = -15.0, 15.0
    min_z, max_z = -45.0, 50.0
    step = 0.5
    
    w = int((max_x - min_x) / step)
    h = int((max_z - min_z) / step)
    grid = [[" " for _ in range(w)] for _ in range(h)]
    
    for r in all_walls:
        if "Hole" in r["name"]: continue
        px, py, pz = r["pos"]
        sx, sy, sz = r["size"]
        
        if y_level >= py - sy/2 and y_level <= py + sy/2:
            x1 = int(math.floor((px - sx/2 - min_x) / step))
            x2 = int(math.ceil((px + sx/2 - min_x) / step))
            z1 = int(math.floor((pz - sz/2 - min_z) / step))
            z2 = int(math.ceil((pz + sz/2 - min_z) / step))
            
            x1 = max(0, min(w-1, x1)); x2 = max(0, min(w-1, x2))
            z1 = max(0, min(h-1, z1)); z2 = max(0, min(h-1, z2))
            
            for zi in range(z1, z2):
                for xi in range(x1, x2):
                    grid[zi][xi] = "#"
                    
    for r in all_walls:
        if "Hole" not in r["name"]: continue
        px, py, pz = r["pos"]
        sx, sy, sz = r["size"]
        
        if y_level >= py - sy/2 and y_level <= py + sy/2:
            x1 = int(math.floor((px - sx/2 - min_x) / step))
            x2 = int(math.ceil((px + sx/2 - min_x) / step))
            z1 = int(math.floor((pz - sz/2 - min_z) / step))
            z2 = int(math.ceil((pz + sz/2 - min_z) / step))
            
            x1 = max(0, min(w-1, x1)); x2 = max(0, min(w-1, x2))
            z1 = max(0, min(h-1, z1)); z2 = max(0, min(h-1, z2))
            
            for zi in range(z1, z2):
                for xi in range(x1, x2):
                    grid[zi][xi] = " "
                    
    for p in all_props:
        px, py, pz = p["pos"]
        sx, sy, sz = prop_sizes.get(p["type"], (1,1,1))
        
        if p.get("swapped", False):
            sx, sz = sz, sx
            
        if y_level >= py - sy/2 and y_level <= py + sy/2:
            x1 = int(math.floor((px - sx/2 - min_x) / step))
            x2 = int(math.ceil((px + sx/2 - min_x) / step))
            z1 = int(math.floor((pz - sz/2 - min_z) / step))
            z2 = int(math.ceil((pz + sz/2 - min_z) / step))
            
            x1 = max(0, min(w-1, x1)); x2 = max(0, min(w-1, x2))
            z1 = max(0, min(h-1, z1)); z2 = max(0, min(h-1, z2))
            
            char = "D" if p["type"] == "door" else p["type"][0].upper()
            for zi in range(z1, z2):
                for xi in range(x1, x2):
                    grid[zi][xi] = char
                    
    res = ""
    for zi in range(h):
        res += "".join(grid[zi]).rstrip() + "\n"
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
- **D**: Door. The interactive doors placed at room entrances and WCs. 
"""

with open(".agents/AGENTS.md", "r", encoding="utf-8") as f:
    agents_text = f.read()

agents_text = re.sub(r'(?s)## Actual Geometry Maps.*', output, agents_text)

with open(".agents/AGENTS.md", "w", encoding="utf-8") as f:
    f.write(agents_text)

print("Updated AGENTS.md successfully!")

