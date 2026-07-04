extends Node
class_name DebugGeometry

static func print_room_alignments(root: Node) -> Array:
	var mismatches = []
	print("\n--- DEBUG GEOMETRY ALIGNMENT ---")
	
	# 1. Find all doors in rooms
	var doors_info = {}
	for child in root.get_children():
		if child.name.begins_with("SingleRoom") or child.name.begins_with("DoubleRoom"):
			var main_door = child.get_node_or_null("MainDoor")
			if main_door:
				doors_info[child.name] = main_door
			
	# 2. Find Corridor Walls X coords
	var left_wall_x = 0.0
	var right_wall_x = 0.0
	var found_l = false
	var found_r = false
	
	for child in root.get_children():
		if child.name.begins_with("CorrWall_L"):
			left_wall_x = child.global_position.x
			found_l = true
		elif child.name.begins_with("CorrWall_R"):
			right_wall_x = child.global_position.x
			found_r = true
			
	# 3. Match doors to walls
	for door_id in doors_info:
		var door = doors_info[door_id]
		var door_pos = door.global_position
		
		var expected_x = left_wall_x if "DoubleRoom" in door_id else right_wall_x
		var diff = abs(door_pos.x - expected_x)
		
		print("Room %s MainDoor X=%.3f | Expected Wall X=%.3f | Diff=%.3f" % [door_id, door_pos.x, expected_x, diff])
		
		if diff > 0.05:
			mismatches.append("Mismatch in " + door_id + ": Door X=" + str(door_pos.x) + ", Wall X=" + str(expected_x))
			
	# 4. Find all Holes and Stairwell Doors to check Z alignment and floating doors
	var holes = []
	var cross_doors = []
	for child in root.get_children():
		if child is CSGBox3D and ("Wall" in child.name):
			for sub in child.get_children():
				if sub is CSGBox3D and sub.operation == CSGShape3D.OPERATION_SUBTRACTION:
					holes.append({"name": sub.name, "pos": sub.global_position, "parent_pos": child.global_position, "parent_name": child.name})
		
		if child.name.begins_with("StairwellDoor") or (child.name.begins_with("Door") and abs(child.global_position.x) < 1.0):
			cross_doors.append({"name": child.name, "pos": child.global_position})
			
	# 5. Check floating cross doors
	for door in cross_doors:
		var has_wall = false
		for child in root.get_children():
			if child is CSGBox3D and abs(child.global_position.z - door.pos.z) < 2.0 and abs(child.global_position.x) < 0.1:
				has_wall = true
				break
		if not has_wall:
			mismatches.append("Floating Door detected: " + door.name + " at Z=" + str(door.pos.z) + " with no surrounding wall!")
			
	# 6. Verify Hole Z matching (very basic distance check for room doors)
	for door_id in doors_info:
		var door = doors_info[door_id]
		var door_z = door.global_position.z
		var found_hole = false
		var closest_hole_dist = 9999.0
		for hole in holes:
			if "Stairwell" in hole.name: continue
			
			# The hole's global Z is roughly the parent wall's Z plus local hole Z if any
			# Since CSG holes are attached to the corridor wall, the wall spans the whole corridor, but Z is center
			# Actually, the hole's global position gives us exact Z
			var dist = abs(hole.pos.z - door_z)
			if dist < closest_hole_dist:
				closest_hole_dist = dist
				
			if dist < 0.1:
				found_hole = true
				break
				
		if not found_hole and closest_hole_dist < 2.0:
			mismatches.append("Z Mismatch in " + door_id + ": Closest hole is " + str(closest_hole_dist) + "m away!")
			
	print("--------------------------------\n")
	return mismatches
