extends SceneTree

func _init():
    var scene_path = "res://scenes/levels/hotel_siberia/base_hotel_level.tscn"
    var packed = load(scene_path)
    if not packed:
        print("Failed to load scene")
        quit(1)
        return
        
    var root = packed.instantiate()
    var geo = root.get_node("NavigationRegion3D/HotelGeometry")
    
    var csg_combiner = CSGCombiner3D.new()
    csg_combiner.name = "CorridorCSG"
    csg_combiner.use_collision = true
    csg_combiner.collision_layer = 2
    
    geo.add_child(csg_combiner)
    csg_combiner.owner = root
    
    var nodes_to_remove = []
    
    for child in geo.get_children():
        if child is StaticBody3D:
            var col_shape = child.get_node_or_null("CollisionShape3D")
            var mesh_inst = child.get_node_or_null("MeshInstance3D")
            
            if col_shape and mesh_inst and col_shape.shape is BoxShape3D:
                var csg_box = CSGBox3D.new()
                csg_box.name = child.name
                csg_box.transform = child.transform
                csg_box.size = col_shape.shape.size
                
                var mat = mesh_inst.get_surface_override_material(0)
                if not mat and mesh_inst.mesh and "material" in mesh_inst.mesh:
                    mat = mesh_inst.mesh.material
                
                if mat:
                    csg_box.material = mat
                    
                csg_combiner.add_child(csg_box)
                csg_box.owner = root
                
                nodes_to_remove.append(child)

    for child in nodes_to_remove:
        geo.remove_child(child)
        child.free() # Free immediately so it's gone before packing
        
    var new_packed = PackedScene.new()
    new_packed.pack(root)
    var err = ResourceSaver.save(new_packed, scene_path)
    if err == OK:
        print("Successfully saved refactored scene.")
    else:
        print("Failed to save scene. Error code: ", err)
        
    quit(0)
