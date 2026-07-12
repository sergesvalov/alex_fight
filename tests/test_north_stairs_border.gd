extends Node

func _ready() -> void:
	print("\n==================================================")
	print("  AUTOTEST: NORTH STAIRS BORDER 2D MAP")
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
		
	print("\n### BORDER MAP: NORTH STAIRS SOUTH WALL (Z = -25.05) ###\n")
	print("Looking NORTH from the Horizontal Corridor.")
	print("Legend: '#' = Wall/Solid, '.' = Empty Space (Doorway)\n")
	
	var step = 0.2
	var min_x = -4.0
	var max_x = 5.0
	var min_y = 0.0
	var max_y = 7.0
	
	var map_str = ""
	
	var y = max_y
	while y >= min_y:
		var row_str = "%4.1f | " % y
		var x = min_x
		while x <= max_x:
			var query = PhysicsPointQueryParameters3D.new()
			query.position = Vector3(x, y, -25.05)
			var result = space_state.intersect_point(query)
			
			if result.is_empty():
				row_str += "."
			else:
				row_str += "#"
			x += step
		map_str += row_str + "\n"
		y -= step
		
	# Draw X axis labels
	var axis_str1 = "       "
	var axis_str2 = "       "
	var x = min_x
	while x <= max_x:
		if abs(fmod(x, 1.0)) < 0.1 or abs(fmod(x, 1.0)) > 0.9:
			var val = int(round(x))
			if val < 0:
				axis_str1 += "-"
				axis_str2 += str(abs(val))
			else:
				axis_str1 += "+"
				axis_str2 += str(val)
		else:
			axis_str1 += " "
			axis_str2 += " "
		x += step
		
	map_str += axis_str1 + "\n"
	map_str += axis_str2 + "\n"
	
	print(map_str)
	print("==================================================")
	print("✅ [TEST PASSED] Border map generated successfully!")
	get_tree().quit(0)
