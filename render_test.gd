
extends SceneTree

func _init():
    var scene = preload("res://scenes/levels/hotel_siberia/base_hotel_level.tscn").instantiate()
    var root = Node.new()
    root.add_child(scene)
    
    var gen = scene.get_node("NavigationRegion3D/HotelGeometry")
    gen._ready()
    
    # Wait for ready and physics frames
    await get_tree().process_frame
    await get_tree().process_frame
    
    var cam = Camera3D.new()
    scene.add_child(cam)
    # Put camera inside room 401, looking at door
    cam.global_transform.origin = Vector3(-6.0, 1.5, 4.75)
    cam.look_at(Vector3(-3.5, 1.0, 4.75), Vector3.UP)
    
    # Render
    var subviewport = SubViewport.new()
    subviewport.size = Vector2(800, 600)
    subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    root.add_child(subviewport)
    cam.get_parent().remove_child(cam)
    subviewport.add_child(cam)
    
    await get_tree().process_frame
    await get_tree().process_frame
    
    var img = subviewport.get_texture().get_image()
    img.save_png("res://room_401_inside.png")
    
    # Now from corridor
    cam.global_transform.origin = Vector3(-1.0, 1.5, 4.75)
    cam.look_at(Vector3(-3.5, 1.0, 4.75), Vector3.UP)
    subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    await get_tree().process_frame
    await get_tree().process_frame
    
    img = subviewport.get_texture().get_image()
    img.save_png("res://room_401_outside.png")
    
    quit()

