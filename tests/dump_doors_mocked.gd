extends SceneTree

func _init() -> void:
    var gen_script = load("res://scripts/levels/hotel_level_generator.gd")
    var generator = Node3D.new()
    generator.set_script(gen_script)
    root.add_child(generator)
    
    # Mock edited_scene_root to prevent crash
    get_tree().edited_scene_root = root
    
    generator._generate_level()
    
    var queue = [generator]
    while queue.size() > 0:
        var curr = queue.pop_back()
        var global_pos = curr.global_transform.origin if "global_transform" in curr else Vector3.ZERO
        var parent = curr.get_parent().name if curr.get_parent() else "None"
        
        var is_door = false
        if curr.name.find("Door") != -1 or curr.name.find("door") != -1:
            is_door = true
        elif curr is MeshInstance3D or curr is CSGShape3D:
            # Maybe it's a misplaced wall or wardrobe?
            if abs(global_pos.x) < 2.5 and abs(global_pos.z) < 2.0:
                print("FOUND_OBJECT_IN_MIDDLE: " + curr.name + " (" + curr.get_class() + ") at " + str(global_pos) + " Rot: " + str(curr.rotation_degrees if "rotation_degrees" in curr else Vector3.ZERO))
                
        if is_door:
            print("FOUND_DOOR: " + curr.name + " at " + str(global_pos) + " Rot: " + str(curr.rotation_degrees))
        
        for child in curr.get_children():
            queue.append(child)
            
    print("DONE_DUMPING")
    quit(0)
