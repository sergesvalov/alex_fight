extends Node

func _ready() -> void:
	print("\n==================================================")
	print("  AUTOTEST: NORTH STAIRS 2D TOP-DOWN MAP")
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
		
	var heights_to_test = [0.5, 2.0, 3.5, 4.4]
	var step = 0.2
	var min_x = -3.0
	var max_x = 5.0
	var min_z = -30.0
	var max_z = -25.0
	
	for y in heights_to_test:
		print("\n### TOP-DOWN MAP AT Y = %.1f ###\n" % y)
		print("Legend: '#' = Solid, '.' = Empty Space")
		
		var map_str = ""
		var z = min_z
		while z <= max_z:
			var row_str = "%5.1f | " % z
			var x = min_x
			while x <= max_x:
				var query = PhysicsPointQueryParameters3D.new()
				query.position = Vector3(x, y, z)
				var result = space_state.intersect_point(query)
				
				if result.is_empty():
					row_str += "."
				else:
					row_str += "#"
				x += step
			map_str += row_str + "\n"
			z += step
			
		var axis_str1 = "        "
		var axis_str2 = "        "
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
	print("✅ [TEST PASSED] Map generated successfully!")
	get_tree().quit(0)
