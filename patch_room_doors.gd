extends SceneTree

func _init():
	var DOOR_SCENE = preload("res://entities/props/door.tscn")
	
	var scenes_to_patch = [
		{
			"path": "res://scenes/levels/hotel_siberia/rooms/single_room.tscn",
			"hole_pos": Vector3(-2.75, 1.025, -0.25),
			"door_pos": Vector3(-3.05, 0, -0.25),
			"door_basis": Basis(Vector3(0, 1, 0), -PI/2)
		},
		{
			"path": "res://scenes/levels/hotel_siberia/rooms/double_room.tscn",
			"hole_pos": Vector3(4.0, 1.025, 0.5),
			"door_pos": Vector3(4.3, 0, 0.5),
			"door_basis": Basis(Vector3(0, 1, 0), PI/2)
		},
		{
			"path": "res://scenes/levels/hotel_siberia/rooms/double_room_large.tscn",
			"hole_pos": Vector3(4.0, 1.025, 0.5),
			"door_pos": Vector3(4.3, 0, 0.5),
			"door_basis": Basis(Vector3(0, 1, 0), PI/2)
		}
	]
	
	for data in scenes_to_patch:
		var pack = load(data["path"]) as PackedScene
		if not pack:
			print("Could not load ", data["path"])
			continue
			
		var root = pack.instantiate()
		
		# 1. Add CorridorHole
		if not root.has_node("CorridorHole"):
			var hole = CSGBox3D.new()
			hole.name = "CorridorHole"
			hole.operation = CSGBox3D.OPERATION_SUBTRACTION
			hole.size = Vector3(1.2, 2.05, 1.0)
			hole.position = data["hole_pos"]
			root.add_child(hole)
			hole.owner = root
			print("Added CorridorHole to ", data["path"])
			
		# 2. Add MainDoor
		if not root.has_node("MainDoor"):
			var door = DOOR_SCENE.instantiate()
			door.name = "MainDoor"
			door.position = data["door_pos"]
			door.basis = data["door_basis"]
			root.add_child(door)
			door.owner = root
			
			# Make all children of instanced scene owned by root too, if needed
			# Usually not needed if they are part of the packed scene
			print("Added MainDoor to ", data["path"])
			
		var new_pack = PackedScene.new()
		new_pack.pack(root)
		ResourceSaver.save(new_pack, data["path"])
		print("Saved ", data["path"])
		
	quit()
