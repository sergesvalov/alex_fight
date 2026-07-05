@tool
extends SceneTree

func _init():
	var root = Node3D.new()
	root.name = "ElevatorShaftBlock"
	root.set_script(load("res://scripts/levels/blocks/block.gd"))
	
	var combiner = CSGCombiner3D.new()
	combiner.name = "ElevatorGeometry"
	combiner.use_collision = true
	combiner.collision_layer = 2
	root.add_child(combiner)
	combiner.owner = root
	
	var wall_mat = load("res://assets/textures/hotel_wallpaper.jpg")
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = wall_mat
	mat.uv1_scale = Vector3(20, 2, 2)
	mat.roughness = 0.9
	
	var west_wall = CSGBox3D.new()
	west_wall.name = "ElevatorWestWall"
	west_wall.size = Vector3(0.2, 3.5, 5.0)
	west_wall.position = Vector3(-2.25, 1.75, 2.5)
	west_wall.material = mat
	combiner.add_child(west_wall)
	west_wall.owner = root
	
	var east_wall = CSGBox3D.new()
	east_wall.name = "ElevatorEastWall"
	east_wall.size = Vector3(0.2, 3.5, 5.0)
	east_wall.position = Vector3(2.25, 1.75, 2.5)
	east_wall.material = mat
	combiner.add_child(east_wall)
	east_wall.owner = root
	
	var south_wall = CSGBox3D.new()
	south_wall.name = "ElevatorSouthWall"
	south_wall.size = Vector3(4.7, 3.5, 0.2)
	south_wall.position = Vector3(0.0, 1.75, 4.9)
	south_wall.material = mat
	combiner.add_child(south_wall)
	south_wall.owner = root
	
	var door_hole = CSGBox3D.new()
	door_hole.name = "ElevatorDoorHole"
	door_hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	door_hole.size = Vector3(2.0, 2.2, 1.0)
	door_hole.position = Vector3(0.0, 1.1, 4.9)
	combiner.add_child(door_hole)
	door_hole.owner = root
	
	var light = OmniLight3D.new()
	light.name = "ElevatorLight"
	light.light_color = Color(0.9, 0.95, 1.0)
	light.omni_range = 8.0
	light.position = Vector3(0.0, 2.75, 2.5)
	root.add_child(light)
	light.owner = root
	
	var pack = PackedScene.new()
	pack.pack(root)
	ResourceSaver.save(pack, "res://scenes/levels/hotel_siberia/blocks/elevator_shaft.tscn")
	print("Elevator generated!")
	quit()
