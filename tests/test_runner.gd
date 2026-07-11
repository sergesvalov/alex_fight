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
    
    print("==================================================")
    print("  JENKINS AUTOTEST: NORTH STAIRS CSG VALIDATION")
    print("==================================================")
    var stair_scene = load("res://scenes/levels/hotel_siberia/blocks/north_stairs.tscn")
    if not stair_scene:
        print("[FAILED] north_stairs.tscn not found")
        get_tree().quit(1)
        return

    var stair = stair_scene.instantiate()
    var root_node = Node3D.new()
    add_child(root_node)
    root_node.add_child(stair)

    # Force CSG to bake
    var csg = stair.get_node_or_null("StairsGeometry")
    if not csg:
        print("[FAILED] StairsGeometry node not found!")
        get_tree().quit(1)
        return
        
    csg._update_shape()
    
    var meshes = csg.get_meshes()
    if meshes.size() < 2:
        print("[FAILED] CSG get_meshes() did not return mesh array")
        get_tree().quit(1)
        return
        
    var mesh = meshes[1] as ArrayMesh
    if not mesh:
        print("[FAILED] CSG did not generate an ArrayMesh")
        get_tree().quit(1)
        return
        
    var faces = mesh.get_faces()
    if faces.size() == 0:
        print("❌ [FAILED] CSG Combiner returned 0 vertices! The boolean logic crashed!")
        
        print("\n--- Diagnostic: Isolating broken nodes ---")
        var flights = ["EastFlight", "NorthFlight", "WestFlight", "SouthWall_WestUnder", "SouthWall_WestOver", "SouthWall_EastOver"]
        for flight_name in flights:
            var node = csg.get_node_or_null(flight_name)
            if node:
                var parent = node.get_parent()
                parent.remove_child(node)
                csg._update_shape()
                var m = csg.get_meshes()
                if m.size() >= 2 and m[1].get_faces().size() > 0:
                    print("💡 FOUND IT! Removing '", flight_name, "' fixes the mesh!")
                parent.add_child(node)
                
        get_tree().quit(1)
        return
        
    print("✅ [OK] CSG Combiner successfully generated ", faces.size(), " vertices.")
    print("==================================================")

    get_tree().quit(0)
