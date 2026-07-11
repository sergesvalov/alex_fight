extends Node

func _ready() -> void:
	print("\n==================================================")
	print("  JENKINS AUTOTEST: STAIRS 2D ASCII MAP")
	print("==================================================")
	
	var scene = load("res://scenes/levels/hotel_siberia/blocks/north_stairs.tscn")
	if not scene:
		print("❌ [FAILED] Could not load north_stairs.tscn")
		get_tree().quit(1)
		return
		
	var block = scene.instantiate()
	add_child(block)
	
	# Wait for physics frames to initialize CSG and collision
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	var space_state = block.get_world_3d().direct_space_state
	if not space_state:
		print("❌ [FAILED] Could not get physics space state.")
		get_tree().quit(1)
		return
	
	print("\n--- Map View (Looking North from South Wall) ---")
	print("Z goes from South (bottom) to North (top)")
	print("X goes from West (left) to East (right)\n")
	
	# Grid bounds (Local coords of the block)
	var x_min = -3.7
	var x_max = 3.7
	var z_min = 0.0 # North
	var z_max = 4.9 # South
	
	var step = 0.25 # Resolution of the map
	
	var map_str = ""
	
	# Loop Z from South (z_max) to North (z_min) so South is at the bottom of the printed map
	var current_z = z_max
	while current_z >= z_min:
		var line = ""
		var current_x = x_min
		while current_x <= x_max:
			var height = _get_height_at(space_state, current_x, current_z)
			if height == -1.0:
				line += " "
			elif height < 0.2:
				line += "."
			elif height < 1.0:
				line += "-"
			elif height < 1.7:
				line += "1"
			elif height < 2.5:
				line += "="
			elif height < 3.2:
				line += "2"
			elif height < 4.0:
				line += "#"
			else:
				line += "3"
			current_x += step
		map_str += line + "\n"
		current_z -= step
		
	print(map_str)
	print("\nLegend:")
	print(" . : Y ~ 0.0 (EastFloor)")
	print(" - : Y ~ 0.5 (EastFlight Slope)")
	print(" 1 : Y ~ 1.5 (NELanding)")
	print(" = : Y ~ 2.2 (NorthFlight Slope)")
	print(" 2 : Y ~ 3.0 (NWLanding)")
	print(" # : Y ~ 3.7 (WestFlight Slope)")
	print(" 3 : Y ~ 4.5 (WestFloor)")
	
	print("\n==================================================")
	print("Test complete.")
	get_tree().quit(0)

func _get_height_at(space_state: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	var start_pos = Vector3(x, 10.0, z)
	var end_pos = Vector3(x, -2.0, z)
	
	var p = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	p.collision_mask = 2 # Check for wall geometry
	
	var result = space_state.intersect_ray(p)
	if result:
		return result.position.y
	return -1.0
