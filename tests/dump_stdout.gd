extends SceneTree

func _init() -> void:
    var gen_script = load("res://scripts/levels/hotel_level_generator.gd")
    var generator = Node3D.new()
    generator.set_script(gen_script)
    root.add_child(generator)
    
    generator._generate_level()
    
    var queue = [generator]
    while queue.size() > 0:
        var curr = queue.pop_back()
        var global_pos = curr.global_transform.origin if "global_transform" in curr else Vector3.ZERO
        var parent = curr.get_parent().name if curr.get_parent() else "None"
        if curr.name.find("Door") != -1 or curr.name.find("door") != -1:
            print("FOUND_DOOR: " + curr.name + " at " + str(global_pos))
        
        for child in curr.get_children():
            queue.append(child)
            
    print("DONE_DUMPING")
    quit(0)
