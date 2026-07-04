import sys

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    out_lines = []
    skip = False
    
    for line in lines:
        if line.startswith('[node name="Floor" ') or \
           line.startswith('[node name="Ceil" ') or \
           line.startswith('[node name="Occluder" type="OccluderInstance3D" parent="Floor"]') or \
           line.startswith('[node name="Occluder" type="OccluderInstance3D" parent="Ceil"]') or \
           line.startswith('[sub_resource type="BoxOccluder3D" id="BoxOccluder3D_Floor"]') or \
           line.startswith('[sub_resource type="BoxOccluder3D" id="BoxOccluder3D_Ceil"]'):
            skip = True
            continue
            
        if line.startswith('[node ') or line.startswith('[sub_resource ') or line.startswith('[ext_resource '):
            skip = False
            
        if skip:
            continue
            
        if 'floor_mesh = NodePath("Floor")' in line:
            continue
            
        out_lines.append(line)
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(out_lines)

process_file(r'c:\wndr\repo\alex_fight\scenes\levels\hotel_siberia\rooms\single_room.tscn')
process_file(r'c:\wndr\repo\alex_fight\scenes\levels\hotel_siberia\rooms\double_room.tscn')
print("Done processing .tscn files")
