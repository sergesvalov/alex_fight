@tool
extends SceneTree

func _init():
	var level_gen = load("res://scripts/levels/hotel_level_generator.gd").new()
	level_gen._generate_level()
	
	# After _generate_level, there is a "GeneratedFloor_Main" node
	var parent = level_gen.get_node("GeneratedFloor_Main")
	if not parent:
		print("Error: GeneratedFloor_Main not found")
		quit()
		return
	
	var aabbs = []
	for child in parent.get_children():
		if child is StaticBody3D:
			# Skip floor and ceiling
			if child.name == "Floor" or child.name == "Ceiling":
				continue
				
			var col = null
			for c in child.get_children():
				if c is CollisionShape3D:
					col = c
					break
			if col and col.shape is BoxShape3D:
				var size = col.shape.size
				var pos = child.position # pos is center
				var aabb = AABB(pos - size / 2.0, size)
				aabbs.append(aabb)

	var width = 21.5
	var length = 60.0
	var thickness = 0.2
	
	var min_x = -width/2 - thickness
	var max_x = width/2 + thickness
	var min_z = -length/2 - thickness
	var max_z = length/2 + thickness
	
	var levels = [1.0] # Let's just generate for Y=1.0 for simplicity, or we can do multiple
	var map_str = "## Actual Geometry Maps\n\n"
	
	# The grid resolution: 1 character = 0.5m
	var step = 0.5
	
	var start_x = floor(min_x / step) * step - step
	var end_x = ceil(max_x / step) * step + step
	var start_z = floor(min_z / step) * step - step
	var end_z = ceil(max_z / step) * step + step
	
	for y in levels:
		map_str += "### Map at Y=" + str(y) + "\n```text\n"
		
		var z = start_z
		while z <= end_z:
			var row = ""
			var x = start_x
			while x <= end_x:
				# The cell AABB represents a 0.5 x 0.5 square at height Y
				var cell_aabb = AABB(Vector3(x, y, z), Vector3(step, 0.1, step))
				
				var is_wall = false
				for aabb in aabbs:
					if cell_aabb.intersects(aabb):
						is_wall = true
						break
				
				if is_wall:
					row += "#"
				else:
					if x > min_x and x < max_x and z > min_z and z < max_z:
						row += "."
					else:
						row += " "
				
				# The image shows spaces between dots. Let's add a space between characters
				# wait, the image had `.` and `#` alternating?
				# Actually, wait. If we just output characters without spaces, does it look squeezed?
				# The user's image shows the dots are spaced out. Let's see if the image was just rendered in a font that spaced them, or if there were actual spaces.
				# Actually, the user's image shows `#` are touching horizontally! `#######` is continuous!
				# If `#` is continuous, but dots have spaces `. . .`, it means the font is just rendering dots smaller, or they literally typed `. `?
				# No, wait. In markdown code blocks, monospaced fonts make `.` and `#` the same width.
				# The image is from their editor or browser.
				# If I look closely at the image, there are spaces between the dots!
				# Wait, look at `#######`. There are no spaces between them!
				# If there are spaces between dots, how can `#` have no spaces, and yet they align perfectly?
				# Ah! Because it's NOT `. . . .`. It's `........`. The font just renders `.` very small and centered in its monospaced cell, making it look like there are spaces between them!
				# Yes, in many fonts, a dot is a single pixel in the middle of a 8-pixel wide character, so it looks like ` . `
				
				x += step
				
			map_str += row + "\n"
			z += step
			
		map_str += "```\n\n"
		
	var file = FileAccess.open("res://new_map.txt", FileAccess.WRITE)
	file.store_string(map_str)
	file.close()
	
	print("Map generated successfully.")
	quit()
