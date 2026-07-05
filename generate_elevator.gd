@tool
extends EditorScript

func _run():
	var root = Node3D.new()
	root.name = "ElevatorBlock"
	
	# Attach the block script
	var script = load("res://scripts/levels/blocks/block.gd")
	root.set_script(script)
	
	var height = 4.0
	var thickness = 0.2
	var wall_y = height / 2.0
	var wall_mat = load("res://assets/textures/hotel_wallpaper.jpg")
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = wall_mat
	mat.uv1_scale = Vector3(15, 3, 1)
	
	var create_box = func(node_name: String, pos: Vector3, size: Vector3):
		var sb = StaticBody3D.new()
		sb.name = node_name
		sb.position = pos
		sb.collision_layer = 2
		
		var col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var shape = BoxShape3D.new()
		shape.size = size
		col.shape = shape
		sb.add_child(col)
		col.owner = root
		
		var mi = MeshInstance3D.new()
		mi.name = "MeshInstance3D"
		var mesh = BoxMesh.new()
		mesh.size = size
		mi.mesh = mesh
		sb.add_child(mi)
		mi.owner = root
		
		root.add_child(sb)
		sb.owner = root
	
	# To make the prefab reusable and clean, its origin will be X=5.3, Z=-27.5.
	# Global Center: X = 5.3, Z = -27.5
	# Local offset: Z = -27.5 - (-27.5) = 0.0
	# Local offset: X = 5.3 - 5.3 = 0.0
	
	# East Wall:
	# Global Center X = 7.55
	# Local X = 7.55 - 5.3 = 2.25
	# Length = 5.0 (Local Z from -2.5 to 2.5)
	create_box.call("Elevator_Inner_East", Vector3(2.25, wall_y, 0.0), Vector3(thickness, height, 5.0))
	
	# West Wall:
	# Global Center X = 3.05
	# Local X = 3.05 - 5.3 = -2.25
	# Length = 5.0
	create_box.call("Elevator_Inner_West", Vector3(-2.25, wall_y, 0.0), Vector3(thickness, height, 5.0))
	
	# South Wall (with Door):
	# Global Z = -25.0
	# Local Z = -25.0 - (-27.5) = 2.5
	# West Part: X from 3.05 to 4.3 -> Local X from -2.25 to -1.0. Length 1.25, Center -1.625.
	create_box.call("Elevator_Inner_South_West", Vector3(-1.625, wall_y, 2.5), Vector3(1.25, height, thickness))
	
	# East Part: X from 6.3 to 7.55 -> Local X from 1.0 to 2.25. Length 1.25, Center 1.625.
	create_box.call("Elevator_Inner_South_East", Vector3(1.625, wall_y, 2.5), Vector3(1.25, height, thickness))
	
	# Lintel: X from 4.3 to 6.3 -> Local X from -1.0 to 1.0. Length 2.0. Center 0.0.
	var door_h = 2.2
	var lintel_h = height - door_h
	var lintel_y = door_h + (lintel_h / 2.0)
	create_box.call("Elevator_Inner_South_Lintel", Vector3(0.0, lintel_y, 2.5), Vector3(2.0, lintel_h, thickness))
	
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/levels/hotel_siberia/blocks/elevator_shaft.tscn")
	print("Saved elevator_shaft.tscn")
