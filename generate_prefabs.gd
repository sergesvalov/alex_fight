@tool
extends SceneTree

func _initialize():
	# Save North Stairs
	var root2 = Node3D.new()
	root2.name = "NorthStairsBlock"
	root2.set_script(load("res://scripts/levels/blocks/block.gd"))
	
	var combiner2 = CSGCombiner3D.new()
	combiner2.name = "StairsGeometry"
	combiner2.use_collision = true
	combiner2.collision_layer = 2
	root2.add_child(combiner2)
	combiner2.owner = root2
	
	var wall_mat = load("res://assets/textures/hotel_wallpaper.jpg")
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = wall_mat
	mat.uv1_scale = Vector3(20, 2, 2)
	mat.roughness = 0.9
	
	var west_wall = CSGBox3D.new()
	west_wall.name = "StairsWestWall"
	west_wall.size = Vector3(0.2, 3.5, 5.0)
	west_wall.position = Vector3(-1.80, 1.75, 2.5)
	west_wall.material = mat
	combiner2.add_child(west_wall)
	west_wall.owner = root2
	
	var east_wall = CSGBox3D.new()
	east_wall.name = "StairsEastWall"
	east_wall.size = Vector3(0.2, 3.5, 5.0)
	east_wall.position = Vector3(1.80, 1.75, 2.5)
	east_wall.material = mat
	combiner2.add_child(east_wall)
	east_wall.owner = root2
	
	var south_wall = CSGBox3D.new()
	south_wall.name = "StairsSouthWall"
	south_wall.size = Vector3(3.8, 3.5, 0.2)
	south_wall.position = Vector3(0.0, 1.75, 4.9)
	south_wall.material = mat
	combiner2.add_child(south_wall)
	south_wall.owner = root2
	
	var door_hole2 = CSGBox3D.new()
	door_hole2.name = "StairsDoorHole"
	door_hole2.operation = CSGShape3D.OPERATION_SUBTRACTION
	door_hole2.size = Vector3(2.0, 2.2, 1.0)
	door_hole2.position = Vector3(0.0, 1.1, 4.9)
	combiner2.add_child(door_hole2)
	door_hole2.owner = root2
	
	var light2 = OmniLight3D.new()
	light2.name = "StairsLight"
	light2.light_color = Color(1.0, 0.9, 0.8)
	light2.omni_range = 8.0
	light2.position = Vector3(0.0, 2.75, 2.5)
	root2.add_child(light2)
	light2.owner = root2
	
	var pack2 = PackedScene.new()
	pack2.pack(root2)
	var err2 = ResourceSaver.save(pack2, "res://scenes/levels/hotel_siberia/blocks/north_stairs.tscn")
	print("North Stairs save result: ", err2)

	# Save Double Room 401
	var root = Node3D.new()
	root.name = "DoubleRoomBlock"
	root.set_script(load("res://scripts/levels/blocks/block.gd"))
	
	var combiner = CSGCombiner3D.new()
	combiner.name = "RoomGeometry"
	combiner.use_collision = true
	combiner.collision_layer = 2
	root.add_child(combiner)
	combiner.owner = root
	
	var north_wall = CSGBox3D.new()
	north_wall.name = "RoomNorthWall"
	north_wall.size = Vector3(8.9, 3.5, 0.2)
	north_wall.position = Vector3(0.0, 1.75, 0.1)
	north_wall.material = mat
	combiner.add_child(north_wall)
	north_wall.owner = root
	
	var south_wall_room = CSGBox3D.new()
	south_wall_room.name = "RoomSouthWall"
	south_wall_room.size = Vector3(8.9, 3.5, 0.2)
	south_wall_room.position = Vector3(0.0, 1.75, 9.9)
	south_wall_room.material = mat
	combiner.add_child(south_wall_room)
	south_wall_room.owner = root
	
	var east_wall_room = CSGBox3D.new()
	east_wall_room.name = "RoomEastWall"
	east_wall_room.size = Vector3(0.2, 3.5, 10.0)
	east_wall_room.position = Vector3(4.35, 1.75, 5.0)
	east_wall_room.material = mat
	combiner.add_child(east_wall_room)
	east_wall_room.owner = root
	
	var door_hole = CSGBox3D.new()
	door_hole.name = "RoomDoorHole"
	door_hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	door_hole.size = Vector3(1.0, 2.2, 2.0)
	door_hole.position = Vector3(4.35, 1.1, 8.5)
	combiner.add_child(door_hole)
	door_hole.owner = root
	
	var pack = PackedScene.new()
	pack.pack(root)
	var err = ResourceSaver.save(pack, "res://scenes/levels/hotel_siberia/blocks/double_room.tscn")
	print("Double Room save result: ", err)
	quit()
