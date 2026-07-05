@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/levels/hotel_siberia/hotel_level.tscn")
	var root = scene.instantiate()
	get_root().add_child(root)
	
	# wait for physics/ready
	await create_timer(0.5).timeout
	
	var gen = root.get_node_or_null("NavigationRegion3D/HotelGeometry")
	var parent = gen.get_node_or_null("GeneratedFloor_Main")
	if not parent:
		print("ERROR: GeneratedFloor_Main not found")
		quit()
		return
		
	var out = FileAccess.open("res://aabbs.txt", FileAccess.WRITE)
	for child in parent.get_children():
		if child is StaticBody3D:
			var col = null
			for c in child.get_children():
				if c is CollisionShape3D:
					col = c
					break
			if col and col.shape is BoxShape3D:
				var size = col.shape.size
				var pos = child.global_position
				var min_pos = pos - size / 2.0
				out.store_line(child.name + " : min=" + str(min_pos) + ", size=" + str(size))
	out.close()
	print("DONE AABBS")
	quit()
