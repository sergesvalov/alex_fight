import re
import os

def remove_doors_from_tscn(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # We want to remove [node name="MainDoor" ...] and its transform
    # We want to remove [node name="WCDoor" ...] or similar and its transform
    # The nodes are typically 2 lines: [node...] and transform=...
    
    # Regex to match [node name="*Door*" ...] and everything until the next [node
    # But wait, Godot nodes might have multiple properties.
    # It's safer to split by '[node ' and filter out the ones containing 'Door"' in the name,
    # EXCEPT 'DoorHole' which we want to keep!
    
    nodes = content.split('\n[node ')
    new_nodes = [nodes[0]] # Header and resources
    
    for node in nodes[1:]:
        # Extract node name
        match = re.search(r'^name="([^"]+)"', node)
        if match:
            node_name = match.group(1)
            if "Door" in node_name and "Hole" not in node_name:
                print(f"Removing {node_name} from {filepath}")
                continue # Skip this node
        new_nodes.append(node)
        
    new_content = '\n[node '.join(new_nodes)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)

files_to_process = [
    "scenes/levels/hotel_siberia/rooms/single_room.tscn",
    "scenes/levels/hotel_siberia/rooms/double_room.tscn",
    "scenes/levels/hotel_siberia/rooms/double_room_large.tscn"
]

for f in files_to_process:
    remove_doors_from_tscn(f)
