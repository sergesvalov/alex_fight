extends SceneTree

func _init() -> void:
    var gen_script = load("res://scripts/levels/hotel_level_generator.gd")
    var generator = Node3D.new()
    generator.set_script(gen_script)
    root.add_child(generator)
    
    generator._generate_level()
    
    var floor_main = generator.get_node("GeneratedFloor_Main")
    
    var file = FileAccess.open("user://dump_csg_boxes.txt", FileAccess.WRITE)
    
    var queue = [floor_main]
    while queue.size() > 0:
        var curr = queue.pop_back()
        if curr is CSGBox3D and curr.operation != CSGShape3D.OPERATION_SUBTRACTION:
            var global_pos = curr.global_transform.origin
            var size = curr.size
            # Check overlap with X=0, Z=10 (Stairwell N) or Z=-62 (Stairwell South)
            var overlap_n = abs(global_pos.x) < 2.0 and abs(global_pos.z - 10.0) < 2.0
            var overlap_s = abs(global_pos.x) < 2.0 and abs(global_pos.z + 62.0) < 2.0
            if overlap_n or overlap_s:
                var s = "Found overlapping Box: " + curr.name + " in " + curr.get_parent().name + "\n"
                s += "  Pos: " + str(global_pos) + " Size: " + str(size) + "\n"
                file.store_string(s)
        
        for child in curr.get_children():
            queue.append(child)
            
    file.close()
    print("Done dumping to user://dump_csg_boxes.txt")
    quit(0)
