extends Node

func _ready() -> void:
	print("--- ELEVATOR DOOR ALIGNMENT TEST ---")
	
	var shaft = load("res://scenes/levels/hotel_siberia/blocks/elevator_shaft.tscn").instantiate()
	var door = load("res://entities/props/elevator_door.tscn").instantiate()
	
	# Simulate generator logic
	shaft.add_child(door)
	door.position = Vector3(0, 0, 0.1)
	door.scale = Vector3(1.42, 1.0, 1.0)
	
	var hole = shaft.get_node("ElevatorGeometry/ElevatorDoorHole")
	var door_mesh = door.get_node("AnimatableBody3D/MeshInstance3D")
	
	var hole_pos = hole.position # Local to ElevatorGeometry
	var hole_size = hole.size
	
	# Door mesh is inside AnimatableBody3D which is inside door root
	var door_body = door.get_node("AnimatableBody3D")
	
	print("HOLE: pos = ", hole_pos, " size = ", hole_size)
	print("DOOR ROOT: pos = ", door.position, " scale = ", door.scale)
	print("DOOR MESH LOCAL: pos = ", door_mesh.position, " size = ", door_mesh.mesh.size)
	
	# Compute actual coordinates
	var hole_left = hole_pos.x - hole_size.x/2
	var hole_right = hole_pos.x + hole_size.x/2
	var hole_bottom = hole_pos.y - hole_size.y/2
	var hole_top = hole_pos.y + hole_size.y/2
	var hole_z_back = hole_pos.z - hole_size.z/2
	var hole_z_front = hole_pos.z + hole_size.z/2
	
	var door_world_x = door.position.x + (door_body.position.x + door_mesh.position.x) * door.scale.x
	var door_world_y = door.position.y + (door_body.position.y + door_mesh.position.y) * door.scale.y
	var door_world_z = door.position.z + (door_body.position.z + door_mesh.position.z) * door.scale.z
	
	var door_w = door_mesh.mesh.size.x * door.scale.x
	var door_h = door_mesh.mesh.size.y * door.scale.y
	var door_d = door_mesh.mesh.size.z * door.scale.z
	
	var door_left = door_world_x - door_w/2
	var door_right = door_world_x + door_w/2
	var door_bottom = door_world_y - door_h/2
	var door_top = door_world_y + door_h/2
	var door_z_back = door_world_z - door_d/2
	var door_z_front = door_world_z + door_d/2
	
	print("HOLE BOUNDS (X): ", hole_left, " to ", hole_right)
	print("DOOR BOUNDS (X): ", door_left, " to ", door_right)
	print("HOLE BOUNDS (Y): ", hole_bottom, " to ", hole_top)
	print("DOOR BOUNDS (Y): ", door_bottom, " to ", door_top)
	print("HOLE BOUNDS (Z): ", hole_z_back, " to ", hole_z_front)
	print("DOOR BOUNDS (Z): ", door_z_back, " to ", door_z_front)
	
	print("\n--- ASCII ART FRONT VIEW (X vs Y) ---")
	print("Legend: W = Wall, . = Hole (empty), D = Door inside hole, # = Door inside wall")
	for y in range(25, -2, -1):
		var wy = y * 0.1
		var line = ""
		for x in range(-15, 16):
			var wx = x * 0.1
			var in_hole = wx >= hole_left and wx <= hole_right and wy >= hole_bottom and wy <= hole_top
			var in_door = wx >= door_left and wx <= door_right and wy >= door_bottom and wy <= door_top
			if in_door and in_hole:
				line += "D"
			elif in_door:
				line += "#"
			elif in_hole:
				line += "."
			else:
				line += "W"
		print(line)
		
	print("\n--- ASCII ART SIDE VIEW (Z vs Y) ---")
	print("Legend: W = Wall, . = Hole (empty), D = Door inside hole, # = Door inside wall")
	for y in range(25, -2, -1):
		var wy = y * 0.1
		var line = ""
		for z in range(-10, 11):
			var wz = z * 0.1
			var in_hole = wz >= hole_z_back and wz <= hole_z_front and wy >= hole_bottom and wy <= hole_top
			var in_door = wz >= door_z_back and wz <= door_z_front and wy >= door_bottom and wy <= door_top
			if in_door and in_hole:
				line += "D"
			elif in_door:
				line += "#"
			elif in_hole:
				line += "."
			else:
				line += "W"
		print(line)
		
	get_tree().quit(0)
