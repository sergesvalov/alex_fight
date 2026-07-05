@tool
extends EditorScript

func _run():
	var root = Node3D.new()
	root.name = "MaintenanceRoomBlock"
	
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
	# Wait, we need to save the material properly so it's a subresource, or just leave material empty 
	# and apply it in code? Actually, we can just load the texture in the scene or just create standard materials.
	# Let's just create standard materials.
	
	# Helper
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
		# mesh.material = mat # omit material for now to avoid resource duplication, or just let level generator apply it
		mi.mesh = mesh
		sb.add_child(mi)
		mi.owner = root
		
		root.add_child(sb)
		sb.owner = root
	
	# The Maintenance room was located at the origin of the world in the generator.
	# But if it's a separate entity, its origin (0,0,0) should probably be its own center, OR its top-left corner.
	# The old generator spawned maintenance room at:
	# `inst.transform.origin = Vector3(9.25 * f_scale, 0, maint_z)`
	# Wait, in my logic, I placed the walls absolutely at X=9.25, Z=-20.0, etc.
	# If we make it a reusable block, we should make its origin (0,0,0) the center of the block.
	# Or just keep it at absolute coordinates if the parent is at 0,0,0.
	# But a prefab should be local!
	# Let's define the local center.
	# Width is 3.0 (X from 7.75 to 10.75). Center X = 9.25.
	# Length is 10.0 (Z from -30.0 to -20.0). Center Z = -25.0.
	# Let's set the origin of the prefab to (0, 0, 0) locally, which means:
	# Inner South Wall: Local Z = 5.0. Local X = 0.0.
	# Inner West Wall: Local X = -1.5. Local Z = -5.0 to 5.0.
	
	# Local South Wall:
	# Center X = 0.0, Size X = 3.0
	# Center Z = 5.0
	create_box.call("Maint_Inner_South", Vector3(0.0, wall_y, 5.0), Vector3(3.0, height, thickness))
	
	# Local West Wall (runs along X = -1.5)
	# Part 1: North part (local Z = -5.0 to 1.0). Center Z = -2.0, Size Z = 6.0
	create_box.call("Maint_Inner_West_North", Vector3(-1.5, wall_y, -2.0), Vector3(thickness, height, 6.0))
	
	# Part 2: South part (local Z = 3.0 to 5.0). Center Z = 4.0, Size Z = 2.0
	create_box.call("Maint_Inner_West_South", Vector3(-1.5, wall_y, 4.0), Vector3(thickness, height, 2.0))
	
	# Part 3: Door Lintel (local Z = 1.0 to 3.0). Center Z = 2.0, Size Z = 2.0
	var door_h = 2.2
	var lintel_h = height - door_h
	var lintel_y = door_h + (lintel_h / 2.0)
	create_box.call("Maint_Inner_West_Lintel", Vector3(-1.5, lintel_y, 2.0), Vector3(thickness, lintel_h, 2.0))
	
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/levels/hotel_siberia/blocks/maintenance_room.tscn")
	print("Saved maintenance_room.tscn")
