extends Node3D

var err_count = 0

func _ready() -> void:
	print("--- Running Hotel Doorway Physics Test ---")
	
	# Instance the level generator
	var generator_scene = load("res://scripts/levels/hotel_level_generator_geometry.gd")
	var generator = generator_scene.new()
	add_child(generator)
	
	var f_scale = GlobalConfig.get_floor_scale()
	
	generator.double_room_step *= f_scale
	generator.single_room_step *= f_scale
	generator.corridor_width *= f_scale
	generator.corridor_height *= f_scale
	generator.wall_thickness *= f_scale
	generator.floor_height *= f_scale
	generator.stairwell_south_offset *= f_scale
	generator.total_corridor_end_margin *= f_scale
	generator.side_corridor_z_start *= f_scale
	generator.side_corridor_z_end *= f_scale
	generator.side_corridor_depth *= f_scale
	generator.elev_shaft_depth *= f_scale
	generator.maint_room_depth *= f_scale
	generator.double_room_x *= f_scale
	generator.double_room_start_z *= f_scale
	generator.double_room_wall_len *= f_scale
	generator.single_room_x *= f_scale
	generator.single_room_start_z *= f_scale
	generator.single_room_wall_len *= f_scale
	
	print("Generating...")
	generator._generate_level()
	
	# Wait for physics frames so CSG nodes bake their collision meshes
	print("Baking CSG collisions...")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# Remove all doors so they don't block the capsule
	print("Removing doors...")
	var door_names = ["MainDoor", "WCDoor", "ElevatorDoor", "StairwellDoor", "StairwellDoor_South", "Door"]
	_remove_doors_recursively(generator, door_names)
	
	# Wait one more frame for queue_free to process
	await get_tree().physics_frame
	
	print("Running physics sweeps...")
	
	# Create physics shape for Player
	var space_state = get_world_3d().direct_space_state
	var shape = CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	
	# Y offset for player center
	var y_pos = 1.0 
	
	# Verify Left Rooms (Double)
	var left_rooms_z = [5.0, -5.0, -15.0, -25.0, -41.0, -51.0]
	for z_pos in left_rooms_z:
		var z = z_pos * f_scale
		_sweep_test(space_state, shape, Vector3(0.0, y_pos, z), Vector3(-6.0, y_pos, z), "Left Room at Z=" + str(z_pos))
		
	# Verify Right Rooms (Single)
	var right_rooms_z = [7.0, 1.0, -9.0, -15.0, -21.0, -27.0, -33.0, -39.0, -45.0]
	for z_pos in right_rooms_z:
		var z = z_pos * f_scale
		_sweep_test(space_state, shape, Vector3(0.0, y_pos, z), Vector3(6.0, y_pos, z), "Right Room at Z=" + str(z_pos))
		
	# Verify Elevator
	var elev_z = -54.0 * f_scale
	_sweep_test(space_state, shape, Vector3(0.0, y_pos, elev_z), Vector3(5.5, y_pos, elev_z), "Elevator")
	
	# Verify Maintenance
	var maint_z = -50.0 * f_scale
	_sweep_test(space_state, shape, Vector3(0.0, y_pos, maint_z), Vector3(6.0, y_pos, maint_z), "Maintenance Room")
	
	# Verify South Stairs
	var south_stair_z = -4.0 * f_scale
	_sweep_test(space_state, shape, Vector3(0.0, y_pos, south_stair_z), Vector3(6.0, y_pos, south_stair_z), "South Stairs")
	
	# Verify North Stairs
	var north_stair_z = -56.5 * f_scale
	_sweep_test(space_state, shape, Vector3(0.0, y_pos, north_stair_z + 2.0), Vector3(0.0, y_pos, north_stair_z - 3.0), "North Stairs")
	
	if err_count == 0:
		print("SUCCESS: All doorways are physically passable by the hero!")
	else:
		print("FAILURE: Found ", err_count, " blocked doorways.")
		
	# Quit automatically if successful, so CI doesn't hang.
	# Actually, since it's meant to be run manually, we will just quit after a short delay
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func _remove_doors_recursively(node: Node, door_names: Array) -> void:
	for child in node.get_children():
		var is_door = false
		for d_name in door_names:
			if child.name.begins_with(d_name):
				is_door = true
				break
		
		if is_door:
			child.queue_free()
		else:
			_remove_doors_recursively(child, door_names)

func _sweep_test(space_state: PhysicsDirectSpaceState3D, shape: Shape3D, start_pos: Vector3, end_pos: Vector3, test_name: String) -> void:
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), start_pos)
	params.motion = end_pos - start_pos
	# Check both layer 1 (default) and 2 (CSG) just in case
	params.collision_mask = 3 
	
	var result = space_state.cast_motion(params)
	
	# cast_motion returns an array of two floats [safe_fraction, unsafe_fraction].
	# 1.0 means it traveled the full distance without hitting anything.
	var safe_fraction = result[0]
	
	if safe_fraction < 0.95:
		print("ERROR: ", test_name, " is BLOCKED! Safe fraction: ", safe_fraction, ". Hit at roughly: ", start_pos + params.motion * safe_fraction)
		err_count += 1
