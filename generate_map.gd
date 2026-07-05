extends SceneTree

func _init():
	print("Generating map...")
	var f = FileAccess.open("new_map.txt", FileAccess.WRITE)
	
	var width = 21.5
	var length = 60.0
	var thickness = 0.2
	
	var min_x = -width/2 - thickness
	var max_x = width/2 + thickness
	var min_z = -length/2 - thickness
	var max_z = length/2 + thickness
	
	var map_str = ""
	
	var levels = [0.0, 1.0, 4.0]
	
	for y in levels:
		map_str += "### Map at Y=" + str(y) + "\n```text\n"
		
		# 60 units for Z (1 unit = 1m), 22 units for X (1 unit = 1m)
		# Actually, let's use a scale of 2 chars per meter for X to make it somewhat square
		for z in range(int(min_z)-1, int(max_z)+2):
			var row = ""
			for x in range(int(min_x)*2 - 2, int(max_x)*2 + 3):
				var real_x = float(x) / 2.0
				var real_z = float(z)
				
				var is_wall = false
				
				# Check if point is inside any wall
				if (real_x >= min_x and real_x <= max_x and real_z >= min_z and real_z <= max_z):
					if (real_x <= min_x + thickness or real_x >= max_x - thickness or
						real_z <= min_z + thickness or real_z >= max_z - thickness):
						is_wall = true
				
				if is_wall:
					row += "#"
				else:
					if real_x > min_x and real_x < max_x and real_z > min_z and real_z < max_z:
						row += "."
					else:
						row += " "
			map_str += row + "\n"
		map_str += "```\n\n"
		
	f.store_string(map_str)
	f.close()
	quit()
