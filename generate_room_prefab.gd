@tool
extends SceneTree

func _init():
	var root = Node3D.new()
	root.name = "DoubleRoomBlock"
	root.set_script(load("res://scripts/levels/blocks/block.gd"))
	
	var combiner = CSGCombiner3D.new()
	combiner.name = "RoomGeometry"
	combiner.use_collision = true
	combiner.collision_layer = 2
	root.add_child(combiner)
	combiner.owner = root
	
	var wall_mat = load("res://assets/textures/hotel_wallpaper.jpg")
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = wall_mat
	mat.uv1_scale = Vector3(20, 2, 2)
	mat.roughness = 0.9
	
	# Dimensions based on bounds 8.9 x 10.0
	# Center of room is 0,0,0.
	# Z goes from 0 to 10 (since it's Z = 10m). Center Z = 5.0
	# X goes from -4.45 to 4.45.
	
	var north_wall = CSGBox3D.new()
	north_wall.name = "RoomNorthWall"
	north_wall.size = Vector3(8.9 + 0.2, 3.5, 0.2)
	north_wall.position = Vector3(0.0, 1.75, 0.1)
	north_wall.material = mat
	combiner.add_child(north_wall)
	north_wall.owner = root
	
	var south_wall = CSGBox3D.new()
	south_wall.name = "RoomSouthWall"
	south_wall.size = Vector3(8.9 + 0.2, 3.5, 0.2)
	south_wall.position = Vector3(0.0, 1.75, 9.9)
	south_wall.material = mat
	combiner.add_child(south_wall)
	south_wall.owner = root
	
	var east_wall = CSGBox3D.new()
	east_wall.name = "RoomEastWall"
	east_wall.size = Vector3(0.2, 3.5, 10.0)
	east_wall.position = Vector3(4.55, 1.75, 5.0)
	east_wall.material = mat
	combiner.add_child(east_wall)
	east_wall.owner = root
	
	var door_hole = CSGBox3D.new()
	door_hole.name = "RoomDoorHole"
	door_hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	door_hole.size = Vector3(1.0, 2.2, 2.0)
	door_hole.position = Vector3(4.55, 1.1, 8.5) # Placed at Z=8.5 (South part of East wall)
	combiner.add_child(door_hole)
	door_hole.owner = root
	
	var pack = PackedScene.new()
	pack.pack(root)
	var err = ResourceSaver.save(pack, "res://scenes/levels/hotel_siberia/blocks/double_room.tscn")
	print("Double Room save result: ", err)
	
	# Also save North Stairs since it failed previously
	var root2 = Node3D.new()
	root2.name = "NorthStairsBlock"
	var pack2 = PackedScene.new()
	pack2.pack(root2)
	var err2 = ResourceSaver.save(pack2, "res://scenes/levels/hotel_siberia/blocks/north_stairs.tscn")
	print("North Stairs save result: ", err2)
	quit()
