@tool
extends EditorScript

func _run() -> void:
	print("--- Running Hotel Layout Verification Test ---")
	
	var generator = HotelLevelGenerator.new()
	var root = Node3D.new()
	root.add_child(generator)
	
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
	
	var err_count = 0
	
	# Verify Left Rooms (Double)
	var expected_left = {
		"DoubleRoomL_408": {"z": 5.0, "flip": true},
		"DoubleRoomL_406": {"z": -5.0, "flip": false},
		"DoubleRoomL_405": {"z": -15.0, "flip": false},
		"DoubleRoomL_403": {"z": -25.0, "flip": false},
		"DoubleRoomL_402": {"z": -41.0, "flip": false},
		"DoubleRoomL_401": {"z": -51.0, "flip": false},
	}
	
	for room_name in expected_left.keys():
		var node = generator.get_node_or_null(room_name)
		if not node:
			print("ERROR: Missing left room ", room_name)
			err_count += 1
			continue
		
		var exp_z = expected_left[room_name]["z"] * f_scale
		var act_z = node.transform.origin.z
		if abs(exp_z - act_z) > 0.01:
			print("ERROR: ", room_name, " Z mismatch! Expected ", exp_z, ", got ", act_z)
			err_count += 1
			
		var expected_scale_z = -1.0 if expected_left[room_name]["flip"] else 1.0
		if abs(node.scale.z - expected_scale_z) > 0.01:
			print("ERROR: ", room_name, " Flip mismatch! Expected ", expected_scale_z, ", got ", node.scale.z)
			err_count += 1
			
	# Verify Right Rooms (Single)
	var expected_right = {
		"SingleRoomR_421": {"z": 7.0, "flip": false},
		"SingleRoomR_420": {"z": 1.0, "flip": true},
		"SingleRoomR_417": {"z": -9.0, "flip": true},
		"SingleRoomR_416": {"z": -15.0, "flip": false},
		"SingleRoomR_415": {"z": -21.0, "flip": true},
		"SingleRoomR_413": {"z": -27.0, "flip": false},
		"SingleRoomR_412": {"z": -33.0, "flip": false},
		"SingleRoomR_411": {"z": -39.0, "flip": false},
		"SingleRoomR_410": {"z": -45.0, "flip": false},
	}
	
	for room_name in expected_right.keys():
		var node = generator.get_node_or_null(room_name)
		if not node:
			print("ERROR: Missing right room ", room_name)
			err_count += 1
			continue
		
		var exp_z = expected_right[room_name]["z"] * f_scale
		var act_z = node.transform.origin.z
		if abs(exp_z - act_z) > 0.01:
			print("ERROR: ", room_name, " Z mismatch! Expected ", exp_z, ", got ", act_z)
			err_count += 1
			
		var expected_scale_z = -1.0 if expected_right[room_name]["flip"] else 1.0
		if abs(node.scale.z - expected_scale_z) > 0.01:
			print("ERROR: ", room_name, " Flip mismatch! Expected ", expected_scale_z, ", got ", node.scale.z)
			err_count += 1
			
	# Verify Elevator and Maintenance
	var elev = generator.get_node_or_null("ElevatorShaftBlock")
	if elev:
		var act_z = elev.transform.origin.z
		var exp_z = -54.0 * f_scale
		if abs(act_z - exp_z) > 0.01:
			print("ERROR: ElevatorShaftBlock Z mismatch! Expected ", exp_z, ", got ", act_z)
			err_count += 1
	else:
		print("ERROR: Missing ElevatorShaftBlock")
		err_count += 1
		
	var maint = generator.get_node_or_null("MaintenanceRoomBlock")
	if maint:
		var act_z = maint.transform.origin.z
		var exp_z = -50.0 * f_scale
		if abs(act_z - exp_z) > 0.01:
			print("ERROR: MaintenanceRoomBlock Z mismatch! Expected ", exp_z, ", got ", act_z)
			err_count += 1
	else:
		print("ERROR: Missing MaintenanceRoomBlock")
		err_count += 1
		
	# Verify South Stairs
	var south_stairs = generator.get_node_or_null("StairwellSouth")
	if south_stairs:
		var act_z = south_stairs.transform.origin.z
		var exp_z = -4.0 * f_scale
		if abs(act_z - exp_z) > 0.01:
			print("ERROR: StairwellSouth Z mismatch! Expected ", exp_z, ", got ", act_z)
			err_count += 1
			
		var act_rot = south_stairs.rotation_degrees.y
		if abs(act_rot - (-90.0)) > 0.01:
			print("ERROR: StairwellSouth Rotation mismatch! Expected -90, got ", act_rot)
			err_count += 1
	else:
		print("ERROR: Missing StairwellSouth")
		err_count += 1
		
	# Verify North Stairs
	var north_stairs = generator.get_node_or_null("Stairwell_N")
	if north_stairs:
		var act_z = north_stairs.transform.origin.z
		var exp_z = -56.5 * f_scale
		if abs(act_z - exp_z) > 0.01:
			print("ERROR: Stairwell_N Z mismatch! Expected ", exp_z, ", got ", act_z)
			err_count += 1
	else:
		print("ERROR: Missing Stairwell_N")
		err_count += 1
		
	if err_count == 0:
		print("SUCCESS: Hotel layout perfectly matches the map specification!")
	else:
		print("FAILURE: Found ", err_count, " layout errors.")
		
	root.queue_free()
