import re

with open('scripts/levels/hotel_level_generator.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    match = re.search(r'inst\.name = "(?:Double|Single)Room_(\d+)"', line)
    if match:
        room_num = match.group(1)
        # Find the next line which should be parent.add_child(inst)
        if i+1 < len(lines) and 'parent.add_child(inst)' in lines[i+1]:
            new_lines.append(lines[i+1])
            new_lines.append(f'\t\tvar door = inst.get_node_or_null("RoomDoor")\n')
            new_lines.append(f'\t\tif door:\n')
            new_lines.append(f'\t\t\tdoor.set_door_number("{room_num}")\n')
            i += 1 # skip next line
    i += 1

with open('scripts/levels/hotel_level_generator.gd', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print("Done!")
