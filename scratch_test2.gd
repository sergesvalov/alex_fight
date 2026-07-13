extends SceneTree

func _init():
	print("Running raycast test on North Stairs...")
	var scene = preload("res://scenes/levels/hotel_siberia/blocks/north_stairs.tscn").instantiate()
	root.add_child(scene)
	
	# Wait for physics to register CSG
	await create_timer(1.0).timeout
	
	var space_state = scene.get_world_3d().direct_space_state
	
	# Raycast from inside the room (Z=0.0) towards the South wall (Z=5.0)
	# Target the East door hole at X=2.8, Y=1.05
	var params = PhysicsRayQueryParameters3D.new()
	params.from = Vector3(2.8, 1.05, 0.0)
	params.to = Vector3(2.8, 1.05, 6.0)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	
	var hit = space_state.intersect_ray(params)
	if hit:
		print("HIT EAST! Collider: ", hit.collider.name, " at ", hit.position)
	else:
		print("NO HIT EAST! Hole is open.")

	# Target the West door hole at X=-2.8, Y=1.05
	params.from = Vector3(-2.8, 1.05, 0.0)
	params.to = Vector3(-2.8, 1.05, 6.0)
	var hit2 = space_state.intersect_ray(params)
	if hit2:
		print("HIT WEST! Collider: ", hit2.collider.name, " at ", hit2.position)
	else:
		print("NO HIT WEST! Hole is open.")
		
	# Target the solid wall at X=0.0, Y=1.05
	params.from = Vector3(0.0, 1.05, 0.0)
	params.to = Vector3(0.0, 1.05, 6.0)
	var hit3 = space_state.intersect_ray(params)
	if hit3:
		print("HIT CENTER! Collider: ", hit3.collider.name, " at ", hit3.position)
	else:
		print("NO HIT CENTER! (This is an error, wall should be solid)")

	quit()
