extends SceneTree

func _init():
	var gen = load("res://scripts/levels/hotel_level_generator.gd").new()
	var root = Node3D.new()
	var mat = StandardMaterial3D.new()
	gen._generate_elevator(root, 1.0, 5.0, 0.2, mat, 4)
	
	var inst = root.get_child(0)
	var door = inst.get_node("ElevatorDoor")
	var mesh = door.get_node("AnimatableBody3D/MeshInstance3D")
	var hole = inst.get_node("ElevatorGeometry/ElevatorDoorHole")
	
	print("--- ELEVATOR TRANSFORMS ---")
	print("Elevator Shaft Global X: ", inst.global_transform.origin.x)
	print("Hole Local X: ", hole.position.x)
	print("Hole Global X: ", hole.global_transform.origin.x)
	print("Door Root Global X: ", door.global_transform.origin.x)
	print("Door Mesh Global X: ", mesh.global_transform.origin.x)
	print("Door Mesh Scale X: ", mesh.global_transform.basis.get_scale().x)
	
	quit()
