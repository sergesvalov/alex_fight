extends SceneTree

func _init() -> void:
    print("Loading base_hotel_level.tscn...")
    var packed_scene = load("res://scenes/levels/hotel_siberia/base_hotel_level.tscn")
    var scene = packed_scene.instantiate()
    
    var generator = scene.get_node("NavigationRegion3D/HotelGeometry")
    if generator and generator.has_method("_generate_level"):
        print("Calling _generate_level()...")
        generator._generate_level()
        
        # Save scene
        var new_packed = PackedScene.new()
        new_packed.pack(scene)
        var err = ResourceSaver.save(new_packed, "res://scenes/levels/hotel_siberia/base_hotel_level.tscn")
        if err == OK:
            print("Successfully saved generated level.")
        else:
            print("Failed to save level: ", err)
    else:
        print("Could not find generator script on HotelGeometry.")
        
    quit()
