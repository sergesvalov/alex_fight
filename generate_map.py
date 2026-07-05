width = 21.5
length = 60.0
thickness = 0.2

min_x = -width/2 - thickness
max_x = width/2 + thickness
min_z = -length/2 - thickness
max_z = length/2 + thickness

map_str = "## Actual Geometry Maps\n\n"

levels = [0.0, 1.0, 4.0]

for y in levels:
    map_str += f"### Map at Y={y}\n```text\n"
    
    # Range based on physical bounds
    for z in range(int(min_z)-1, int(max_z)+2):
        row = ""
        for x in range(int(min_x)*2 - 2, int(max_x)*2 + 3):
            real_x = float(x) / 2.0
            real_z = float(z)
            
            is_wall = False
            
            # Check if point is inside any wall
            if (real_x >= min_x and real_x <= max_x and real_z >= min_z and real_z <= max_z):
                if (real_x <= min_x + thickness or real_x >= max_x - thickness or
                    real_z <= min_z + thickness or real_z >= max_z - thickness):
                    is_wall = True
            
            if is_wall:
                row += "#"
            else:
                if real_x > min_x and real_x < max_x and real_z > min_z and real_z < max_z:
                    row += "."
                else:
                    row += " "
        map_str += row + "\n"
    map_str += "```\n\n"

with open("new_map.txt", "w") as f:
    f.write(map_str)
