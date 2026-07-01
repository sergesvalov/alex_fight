extends SceneTree

func _init():
    var generator = load("res://scripts/levels/hotel_level_generator.gd").new()
    generator.num_double_rooms = 1
    generator.num_single_rooms = 1
    
    var root = Node3D.new()
    root.name = "Root"
    root.add_child(generator)
    
    generator._generate_level()
    
    for floor_parent in generator.get_children():
        print("Floor: ", floor_parent.name)
        for child in floor_parent.get_children():
            if child is CSGBox3D and child.name.contains("Floor"):
                var top_y = child.global_transform.origin.y + (child.size.y / 2.0)
                print("  CSGBox3D Floor: ", child.name, " global Y top = ", top_y)
            elif child.name.contains("Room"):
                for room_child in child.get_children():
                    if room_child is CSGBox3D and room_child.name == "Floor":
                        var top_y = room_child.global_transform.origin.y + (room_child.size.y / 2.0)
                        var global_pos = child.transform * room_child.transform.origin
                        var global_top_y = global_pos.y + (room_child.size.y / 2.0)
                        print("  Room Floor: ", child.name, " global Y top = ", global_top_y)
    
    quit()
