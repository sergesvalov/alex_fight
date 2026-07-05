extends SceneTree

func _init() -> void:
    var gen_script = load("res://scripts/levels/hotel_level_generator.gd")
    var generator = Node3D.new()
    generator.set_script(gen_script)
    root.add_child(generator)
    
    generator._generate_level()
    
    await get_tree().process_frame
    await get_tree().process_frame
    
    var file = FileAccess.open("res://tests/doors_dump.txt", FileAccess.WRITE)
    
    var queue = [generator]
    while queue.size() > 0:
        var curr = queue.pop_back()
        if curr.name.find("Door") != -1 or curr.scene_file_path.find("door.tscn") != -1:
            var global_pos = curr.global_transform.origin
            var parent = curr.get_parent().name if curr.get_parent() else "None"
            file.store_string("Found Door: " + curr.name + " (Parent: " + parent + ") at " + str(global_pos) + " Rot: " + str(curr.rotation_degrees) + "\n")
        
        for child in curr.get_children():
            queue.append(child)
            
    file.close()
    print("Done dumping to res://tests/doors_dump.txt")
    quit(0)
