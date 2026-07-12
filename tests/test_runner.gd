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

    print("==================================================")
    print("  JENKINS AUTOTEST: ELEVATOR ALIGNMENT VALIDATION")
    print("==================================================")
    var shaft = load("res://scenes/levels/hotel_siberia/blocks/elevator_shaft.tscn").instantiate()
    var door = load("res://entities/props/elevator_door.tscn").instantiate()
    
    # Simulate generator logic
    shaft.add_child(door)
    door.position = Vector3(0, 0, 0.1)
    door.scale = Vector3(1.5, 1.05, 0.25)
    
    var hole = shaft.get_node("ElevatorGeometry/ElevatorDoorHole")
    var door_mesh = door.get_node("AnimatableBody3D/MeshInstance3D")
    
    var hole_pos = hole.position # Local to ElevatorGeometry
    var hole_size = hole.size
    
    var door_body = door.get_node("AnimatableBody3D")
    
    var hole_left = hole_pos.x - hole_size.x/2
    var hole_right = hole_pos.x + hole_size.x/2
    var hole_bottom = hole_pos.y - hole_size.y/2
    var hole_top = hole_pos.y + hole_size.y/2
    var hole_z_back = hole_pos.z - hole_size.z/2
    var hole_z_front = hole_pos.z + hole_size.z/2
    
    var door_world_x = door.position.x + (door_body.position.x + door_mesh.position.x) * door.scale.x
    var door_world_y = door.position.y + (door_body.position.y + door_mesh.position.y) * door.scale.y
    var door_world_z = door.position.z + (door_body.position.z + door_mesh.position.z) * door.scale.z
    
    var door_w = door_mesh.mesh.size.x * door.scale.x
    var door_h = door_mesh.mesh.size.y * door.scale.y
    var door_d = door_mesh.mesh.size.z * door.scale.z
    
    var door_left = door_world_x - door_w/2
    var door_right = door_world_x + door_w/2
    var door_bottom = door_world_y - door_h/2
    var door_top = door_world_y + door_h/2
    var door_z_back = door_world_z - door_d/2
    var door_z_front = door_world_z + door_d/2
    
    print("HOLE BOUNDS (X): ", hole_left, " to ", hole_right)
    print("DOOR BOUNDS (X): ", door_left, " to ", door_right)
    print("HOLE BOUNDS (Y): ", hole_bottom, " to ", hole_top)
    print("DOOR BOUNDS (Y): ", door_bottom, " to ", door_top)
    print("HOLE BOUNDS (Z): ", hole_z_back, " to ", hole_z_front)
    print("DOOR BOUNDS (Z): ", door_z_back, " to ", door_z_front)
    
    print("\n--- ASCII ART FRONT VIEW (X vs Y) ---")
    print("Legend: W = Wall, . = Hole (empty), D = Door inside hole, # = Door inside wall")
    for y_idx in range(25, -2, -1):
        var wy = y_idx * 0.1
        var line = ""
        for x_idx in range(-15, 16):
            var wx = x_idx * 0.1
            var in_hole = wx >= hole_left and wx <= hole_right and wy >= hole_bottom and wy <= hole_top
            var in_door = wx >= door_left and wx <= door_right and wy >= door_bottom and wy <= door_top
            if in_door and in_hole:
                line += "D"
            elif in_door:
                line += "#"
            elif in_hole:
                line += "."
            else:
                line += "W"
        print(line)
        
    print("\n--- ASCII ART SIDE VIEW (Z vs Y) ---")
    print("Legend: W = Wall, . = Hole (empty), D = Door inside hole, # = Door inside wall")
    for y_idx in range(25, -2, -1):
        var wy = y_idx * 0.1
        var line = ""
        for z_idx in range(-10, 11):
            var wz = z_idx * 0.1
            var in_hole = wz >= hole_z_back and wz <= hole_z_front and wy >= hole_bottom and wy <= hole_top
            var in_door = wz >= door_z_back and wz <= door_z_front and wy >= door_bottom and wy <= door_top
            if in_door and in_hole:
                line += "D"
            elif in_door:
                line += "#"
            elif in_hole:
                line += "."
            else:
                line += "W"
        print(line)

    print("✅ [OK] Elevator alignment visualization complete.")
    get_tree().quit(0)
