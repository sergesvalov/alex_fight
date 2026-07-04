extends Node
class_name DebugGeometry

## Helper script to print global coordinates of hotel rooms and doors for AI agents

static func print_room_alignments(root: Node) -> Array:
	var mismatches = []
	print("\n--- DEBUG GEOMETRY ALIGNMENT ---")
	
	# 1. Find all doors in rooms
	var doors_info = {}
	for child in root.get_children():
		if child.name.begins_with("SingleRoom") or child.name.begins_with("DoubleRoom"):
			var main_door = child.get_node_or_null("MainDoor")
			if main_door:
				var door_id = child.name
				doors_info[door_id] = {
					"room": child.name,
					"global_pos": main_door.global_position,
					"door_node": main_door
				}
			
	# 2. Find all corridor holes
	var holes_info = []
	for child in root.get_children():
		if child.name.begins_with("CorrWall") or child.name.begins_with("MainCorrRightWall") or child.name.begins_with("MainCorrLeftWall"):
			for wall_child in child.get_children():
				if wall_child is CSGBox3D and "Hole" in wall_child.name:
					holes_info.append({
						"wall_name": child.name,
						"global_pos": wall_child.global_position,
						"hole_node": wall_child
					})
					
	# 3. Match doors to closest holes
	for door_id in doors_info:
		var door_data = doors_info[door_id]
		var door_pos = door_data["global_pos"]
		
		var closest_hole = null
		var min_dist = 9999.0
		
		for hole in holes_info:
			# For 2D distance ignoring Y
			var dist = Vector2(door_pos.x, door_pos.z).distance_to(Vector2(hole["global_pos"].x, hole["global_pos"].z))
			if dist < min_dist:
				min_dist = dist
				closest_hole = hole
				
		if closest_hole:
			print("Room %s MainDoor: X=%.3f, Z=%.3f | Closest Hole (%s): X=%.3f, Z=%.3f | Diff: %.3f" % [
				door_id, door_pos.x, door_pos.z, 
				closest_hole["wall_name"], 
				closest_hole["global_pos"].x, closest_hole["global_pos"].z,
				min_dist
			])
			
			if min_dist > 0.05:
				mismatches.append("Mismatch in " + door_id + ": Door at " + str(door_pos) + ", Hole at " + str(closest_hole["global_pos"]))
		else:
			print("Room %s: No holes found!" % door_id)
			mismatches.append("No hole for " + door_id)
			
	print("--------------------------------\n")
	return mismatches
