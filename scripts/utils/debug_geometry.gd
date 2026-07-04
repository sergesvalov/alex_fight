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
			
	print("--------------------------------\n")
	return mismatches
