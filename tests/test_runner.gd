extends Node

func _ready() -> void:
    print("==================================================")
    print("  JENKINS AUTOTEST: LEVEL MAP GENERATOR")
    print("==================================================")
    
    var gen_script = load("res://scripts/levels/hotel_level_generator.gd")
    if not gen_script:
        print("[FAILED] Could not load hotel_level_generator.gd")
        get_tree().quit(1)
        return
        
    var generator = Node3D.new()
    generator.set_script(gen_script)
    add_child(generator)
    
    generator._generate_level()
    
    # Wait for Godot to initialize collision shapes and update physics state
    await get_tree().physics_frame
    await get_tree().physics_frame
    await get_tree().physics_frame
    
    var space_state = generator.get_world_3d().direct_space_state
    if not space_state:
        print("[FAILED] Could not get physics space state.")
        get_tree().quit(1)
        return
        
    print("\n### HOTEL LEVEL GEOMETRY MAP (Y=1.0) ###\n")
    
    var step = 0.5
    var min_x = -14.0
    var max_x = 14.0
    var min_z = -32.0
    var max_z = 32.0
    
    var z = min_z
    while z <= max_z:
        var line = ""
        var x = min_x
        while x <= max_x:
            var pos = Vector3(x, 1.0, z)
            var p = PhysicsPointQueryParameters3D.new()
            p.position = pos
            p.collision_mask = 2 # Matches generator collision_layer=2
            
            var results = space_state.intersect_point(p, 1)
            if results.size() > 0:
                line += "#"
            else:
                if x > -13.0 and x < 13.0 and z > -31.0 and z < 31.0:
                    line += "."
                else:
                    line += " "
            x += step
        print(line)
        z += step
        
    print("\n[OK] Map generation test passed successfully.")
    get_tree().quit(0)
