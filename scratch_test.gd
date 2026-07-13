extends SceneTree

func _init():
	print("Running scratch test...")
	var scene = preload("res://scenes/levels/hotel_siberia/blocks/north_stairs.tscn").instantiate()
	root.add_child(scene)
	
	# We must process physics frames
	await create_timer(1.0).timeout
	
	var space_state = scene.get_world_3d().direct_space_state
	
	# Test DoorHoleEast local coords
	# local pos is 2.8, 1.1, 4.9
	var pos = Vector3(2.8, 1.1, 4.9)
	var params = PhysicsPointQueryParameters3D.new()
	params.position = pos
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var hits = space_state.intersect_point(params)
	if hits.size() > 0:
		print("HIT AT DOORHOLE EAST!")
		var collider = hits[0].collider
		print("Collider: ", collider.name)
		print("Class: ", collider.get_class())
	else:
		print("NO HIT AT DOORHOLE EAST! (Success)")
	
	quit()
