extends SceneTree

func _init():
	var file = FileAccess.open("rebuild_log.txt", FileAccess.WRITE)
	file.store_line("Starting rebuild...")
	
	var path = "res://scenes/levels/hotel_siberia/base_hotel_level.tscn"
	var pack = load(path) as PackedScene
	if not pack:
		file.store_line("Could not load scene")
		quit()
		return
		
	var root = pack.instantiate()
	var nav = root.get_node_or_null("NavigationRegion3D")
	if not nav:
		file.store_line("No nav")
		quit()
		return
	
	var gen = nav.get_node_or_null("HotelGeometry")
	if not gen:
		file.store_line("No gen")
		quit()
		return
		
	var count = 0
	var children = gen.get_children()
	for child in children:
		if child.name != "InteractableObjects":
			gen.remove_child(child)
			child.free()
			count += 1
			file.store_line("Removed " + child.name)
			
	gen._generate_level()
	file.store_line("Generated level.")
	
	var new_pack = PackedScene.new()
	new_pack.pack(root)
	ResourceSaver.save(new_pack, path)
	file.store_line("Saved to " + path)
	file.close()
	quit()
