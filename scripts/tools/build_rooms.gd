extends SceneTree

func _init():
    print("Building rooms...")
    var scene_path = "res://scenes/levels/hotel_siberia/hotel_level.tscn"
    var packed = ResourceLoader.load(scene_path)
    if not packed:
        print("Failed to load scene")
        quit(1)
        return
        
    var root = packed.instantiate()
    var geom = root.get_node("NavigationRegion3D/HotelGeometry")
    
    # 1. Remove old corridor walls
    var cw_east = geom.get_node_or_null("CorridorWallEast")
    if cw_east: cw_east.queue_free()
    var cw_west = geom.get_node_or_null("CorridorWallWest")
    if cw_west: cw_west.queue_free()
    
    # Material
    var wall_mat = StandardMaterial3D.new()
    wall_mat.albedo_texture = load("res://assets/textures/hotel_wallpaper.jpg")
    wall_mat.uv1_scale = Vector3(20, 2, 2)
    wall_mat.roughness = 0.9
    
    var floor_mat = StandardMaterial3D.new()
    floor_mat.albedo_texture = load("res://assets/textures/hotel_carpet.jpg")
    floor_mat.uv1_scale = Vector3(10, 10, 10)
    
    # Helper to create a wall (CSG)
    var create_wall = func(name, pos, size):
        var csg = CSGBox3D.new()
        csg.name = name
        csg.position = pos
        csg.size = size
        csg.material = wall_mat
        csg.use_collision = true
        csg.collision_layer = 2
        geom.add_child(csg)
        csg.owner = root
        return csg
        
    var create_floor = func(name, pos, size):
        var csg = CSGBox3D.new()
        csg.name = name
        csg.position = pos
        csg.size = size
        csg.material = floor_mat
        csg.use_collision = true
        csg.collision_layer = 2
        geom.add_child(csg)
        csg.owner = root
        return csg

    # 2. Build Corridor Walls with gaps
    # West walls (x = -3.5)
    create_wall.call("CorrWallW1", Vector3(-3.5, 2, -8), Vector3(1, 4, 6))
    create_wall.call("CorrWallW2", Vector3(-3.5, 2, -18.75), Vector3(1, 4, 9.5))
    create_wall.call("CorrWallW3", Vector3(-3.5, 2, -31.25), Vector3(1, 4, 9.5))
    create_wall.call("CorrWallW4", Vector3(-3.5, 2, -42), Vector3(1, 4, 6))
    # East walls (x = 3.5)
    create_wall.call("CorrWallE1", Vector3(3.5, 2, -8), Vector3(1, 4, 6))
    create_wall.call("CorrWallE2", Vector3(3.5, 2, -18.75), Vector3(1, 4, 9.5))
    create_wall.call("CorrWallE3", Vector3(3.5, 2, -31.25), Vector3(1, 4, 9.5))
    create_wall.call("CorrWallE4", Vector3(3.5, 2, -42), Vector3(1, 4, 6))
    
    # 3. Build Rooms
    # Left Rooms (Large, 8x10). West side, center x = -8, z = -12.5, -25, -37.5
    var z_centers = [-12.5, -25.0, -37.5]
    for i in range(3):
        var z = z_centers[i]
        var prefix = "RoomL" + str(i+1)
        # Floor & Ceiling
        create_floor.call(prefix+"_Floor", Vector3(-8, 0, z), Vector3(8, 0.5, 10))
        create_floor.call(prefix+"_Ceil", Vector3(-8, 4.25, z), Vector3(8, 0.5, 10))
        # Walls
        create_wall.call(prefix+"_WallW", Vector3(-12, 2, z), Vector3(1, 4, 10))
        create_wall.call(prefix+"_WallN", Vector3(-8, 2, z - 5), Vector3(9, 4, 1))
        create_wall.call(prefix+"_WallS", Vector3(-8, 2, z + 5), Vector3(9, 4, 1))
        
    # Right Rooms (Small, 6x6). East side, center x = 7, z = -12.5, -25, -37.5
    for i in range(3):
        var z = z_centers[i]
        var prefix = "RoomR" + str(i+1)
        # Floor & Ceiling
        create_floor.call(prefix+"_Floor", Vector3(7, 0, z), Vector3(6, 0.5, 6))
        create_floor.call(prefix+"_Ceil", Vector3(7, 4.25, z), Vector3(6, 0.5, 6))
        # Walls
        create_wall.call(prefix+"_WallE", Vector3(10, 2, z), Vector3(1, 4, 6))
        create_wall.call(prefix+"_WallN", Vector3(7, 2, z - 3), Vector3(7, 4, 1))
        create_wall.call(prefix+"_WallS", Vector3(7, 2, z + 3), Vector3(7, 4, 1))

    # Add furniture
    var props = root.get_node_or_null("InteractableObjects")
    if not props:
        props = Node3D.new()
        props.name = "InteractableObjects"
        root.add_child(props)
        props.owner = root

    var bed_res = load("res://entities/props/bed.tscn")
    var chair_res = load("res://entities/props/chair.tscn")
    var table_res = load("res://entities/props/table.tscn")
    var wardrobe_res = load("res://entities/props/wardrobe.tscn")

    var spawn_prop = func(res, name_prefix, pos, rot_y):
        if not res: return
        var node = res.instantiate()
        node.name = name_prefix
        node.position = pos
        node.rotation.y = rot_y
        props.add_child(node)
        node.owner = root
        
    # Furnish Left Rooms (Large: 2 beds, 1 table, 3 chairs, 1 wardrobe)
    for i in range(3):
        var z = z_centers[i]
        var p = "L" + str(i+1) + "_"
        spawn_prop.call(bed_res, p+"Bed1", Vector3(-10.5, 0, z - 3), PI/2)
        spawn_prop.call(bed_res, p+"Bed2", Vector3(-10.5, 0, z + 3), PI/2)
        spawn_prop.call(wardrobe_res, p+"Wardrobe", Vector3(-11, 0, z), PI/2)
        spawn_prop.call(table_res, p+"Table", Vector3(-6, 0, z), 0)
        spawn_prop.call(chair_res, p+"Chair1", Vector3(-5, 0, z), -PI/2)
        spawn_prop.call(chair_res, p+"Chair2", Vector3(-7, 0, z - 0.5), PI/2)
        spawn_prop.call(chair_res, p+"Chair3", Vector3(-7, 0, z + 0.5), PI/2)

    # Furnish Right Rooms (Small: 1 bed, 1 table, 2 chairs)
    for i in range(3):
        var z = z_centers[i]
        var p = "R" + str(i+1) + "_"
        spawn_prop.call(bed_res, p+"Bed", Vector3(8.5, 0, z - 1.5), -PI/2)
        spawn_prop.call(table_res, p+"Table", Vector3(6, 0, z + 1.5), 0)
        spawn_prop.call(chair_res, p+"Chair1", Vector3(5, 0, z + 1.5), -PI/2)
        spawn_prop.call(chair_res, p+"Chair2", Vector3(7, 0, z + 1.5), PI/2)

    # Save
    var new_packed = PackedScene.new()
    new_packed.pack(root)
    ResourceSaver.save(new_packed, scene_path)
    print("Done building rooms and furniture.")
    quit(0)
