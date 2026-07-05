extends SceneTree

var step = 0.5
var min_x = -12.0
var max_x = 12.0
var min_z = -35.0
var max_z = 35.0

func _init() -> void:
    var gen_script = load("res://scripts/levels/hotel_level_generator.gd")
    var generator = Node3D.new()
    generator.set_script(gen_script)
    root.add_child(generator)
    
    generator._generate_level()
    
    # Let physics update so CSG collision shapes are created
    await get_tree().physics_frame
    await get_tree().physics_frame
    await get_tree().physics_frame
    
    var heights = [0.1, 1.0, 3.5] # floor, 1m, ceiling
    var height_names = ["Floor Level (Y=0.1)", "1 Meter Height (Y=1.0)", "Ceiling/Wall Intersection (Y=3.5)"]
    
    var map_str = "Hotel Level Geometry Maps (Actual coordinates)\n\n"
    
    var space_state = generator.get_world_3d().direct_space_state
    
    for h_idx in range(heights.size()):
        var h = heights[h_idx]
        map_str += "### " + height_names[h_idx] + "\n```text\n"
        
        var z = min_z
        while z <= max_z:
            var line = ""
            var x = min_x
            while x <= max_x:
                var pos = Vector3(x, h, z)
                var p = PhysicsPointQueryParameters3D.new()
                p.position = pos
                p.collision_mask = 2 # Generator uses collision_layer=2 for walls/floors
                
                var results = space_state.intersect_point(p, 1)
                if results.size() > 0:
                    line += "#"
                else:
                    # Check if inside doorway or room bounding boxes.
                    # Since we only checking collision mask 2, it'll print '#' for solid walls
                    # We might want more details?
                    line += "."
                x += step
            map_str += line + "\n"
            z += step
        
        map_str += "```\n\n"
    
    var file = FileAccess.open("res://tests/generated_map.txt", FileAccess.WRITE)
    file.store_string(map_str)
    file.close()
    
    print("Map generated to res://tests/generated_map.txt")
    quit(0)
