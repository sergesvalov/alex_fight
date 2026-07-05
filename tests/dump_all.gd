extends SceneTree

func _init() -> void:
    var gen_script = load("res://scripts/levels/hotel_level_generator.gd")
    var generator = Node3D.new()
    generator.set_script(gen_script)
    root.add_child(generator)
    
    generator._generate_level()
    
    var file = FileAccess.open("res://tests/all_nodes_dump.txt", FileAccess.WRITE)
    
    var queue = [generator]
    while queue.size() > 0:
        var curr = queue.pop_back()
        var global_pos = curr.global_transform.origin if "global_transform" in curr else Vector3.ZERO
        var parent = curr.get_parent().name if curr.get_parent() else "None"
        file.store_string(curr.name + " (Parent: " + parent + ") type: " + curr.get_class() + " pos: " + str(global_pos) + "\n")
        
        for child in curr.get_children():
            queue.append(child)
            
    file.close()
    print("Done dumping to res://tests/all_nodes_dump.txt")
    quit(0)
