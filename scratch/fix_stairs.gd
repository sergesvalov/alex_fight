extends SceneTree

func _init():
    var packed = load("res://scenes/levels/hotel_siberia/hotel_level.tscn")
    var scene = packed.instantiate()
    
    var stairwell = scene.get_node("NavigationRegion3D/HotelGeometry/Stairwell")
    
    # 1. Fix Ramp1_Down
    var r1_down = stairwell.get_node("Ramp1_Down")
    r1_down.transform.origin = Vector3(-3, -2, -3)
    r1_down.transform.basis = Basis(Vector3.UP, -PI/2)
    r1_down.polygon = PackedVector2Array([Vector2(0, 2), Vector2(3, 0), Vector2(0, 0)])
    
    # 2. Fix Ramp2_Down
    var r2_down = stairwell.get_node("Ramp2_Down")
    r2_down.transform.origin = Vector3(3, -4, -6)
    r2_down.transform.basis = Basis(Vector3.UP, PI/2)
    r2_down.polygon = PackedVector2Array([Vector2(0, 2), Vector2(3, 0), Vector2(0, 0)])
    
    # 3. Add Ramp3_Down if it doesn't exist
    if not stairwell.has_node("Ramp3_Down"):
        var r3_down = CSGPolygon3D.new()
        r3_down.name = "Ramp3_Down"
        stairwell.add_child(r3_down)
        r3_down.owner = scene
        r3_down.transform.origin = Vector3(-3, -6, -3)
        r3_down.transform.basis = Basis(Vector3.UP, -PI/2)
        r3_down.polygon = PackedVector2Array([Vector2(0, 2), Vector2(3, 0), Vector2(0, 0)])
        r3_down.depth = 2.0
        # Copy material from r1_down
        r3_down.material = r1_down.material
        
    # 4. Fix Teleport collision shapes
    var new_shape = BoxShape3D.new()
    new_shape.size = Vector3(6, 4, 1)
    
    var t_upper = stairwell.get_node("TeleportUpper/CollisionShape3D")
    t_upper.shape = new_shape
    t_upper.transform.origin = Vector3(0, 2, 0)
    
    var t_lower = stairwell.get_node("TeleportLower/CollisionShape3D")
    t_lower.shape = new_shape
    t_lower.transform.origin = Vector3(0, 2, 0)
    
    # Save the scene
    var new_packed = PackedScene.new()
    new_packed.pack(scene)
    var err = ResourceSaver.save(new_packed, "res://scenes/levels/hotel_siberia/hotel_level.tscn")
    if err == OK:
        print("Successfully fixed stair geometry and teleporters!")
    else:
        print("Failed to save scene: ", err)
        
    quit(0)
