extends Node

func _ready() -> void:
	print("\n==================================================")
	print("  AUTOTEST: NORTH STAIRS 2D SIDE MAP")
	print("==================================================")
	
	var gen_script = load("res://scripts/levels/hotel_level_generator.gd")
	if not gen_script:
		print("❌ [FAILED] Could not load generator script")
		get_tree().quit(1)
		return
		
	var generator = Node3D.new()
	generator.set_script(gen_script)
	add_child(generator)
	
	generator._generate_level()
	
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	var space_state = generator.get_world_3d().direct_space_state
	if not space_state:
		print("❌ [FAILED] Could not get physics space state.")
		get_tree().quit(1)
		return
		
	var x_slices = [-2.5, 0.0, 2.5]
	var step = 0.2
	var min_z = -31.0
	var max_z = -24.0
	var min_y = 0.0
	var max_y = 6.0
	
	for x in x_slices:
		var slice_name = "WEST FLIGHT"
		if x == 0.0: slice_name = "NORTH FLIGHT"
		if x == 2.5: slice_name = "EAST FLIGHT"
			
		print("\n### SIDE-VIEW MAP AT X = %.1f (%s) ###\n" % [x, slice_name])
		print("Legend: '#' = Solid, '.' = Empty Space")
		
		# For a side view, Y should go top to bottom
		var y = max_y
		while y >= min_y:
			var row_str = "%5.1f | " % y
			var z = min_z
			while z <= max_z:
				var query = PhysicsPointQueryParameters3D.new()
				query.position = Vector3(x, y, z)
				var result = space_state.intersect_point(query)
				
				if result.is_empty():
					row_str += "."
				else:
					row_str += "#"
				z += step
			print(row_str)
			y -= step
			
		# Print Z axis labels
		var axis_str1 = "        "
		var axis_str2 = "        "
		var z_label = min_z
		while z_label <= max_z:
			var val = int(abs(z_label))
			var sign_char = "-" if z_label < 0 else "+"
			if int(round(z_label * 10)) % 10 == 0:
				axis_str1 += sign_char + "    "
				axis_str2 += str(val % 10) + "    "
			else:
				axis_str1 += " "
				axis_str2 += " "
			z_label += step
			
		print(axis_str1)
		print(axis_str2)

	print("\n==================================================")
	print("✅ [TEST PASSED] Side Map generated successfully!")
	get_tree().quit(0)
