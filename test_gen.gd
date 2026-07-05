extends SceneTree

func _init():
	var file = FileAccess.open("generate_log.txt", FileAccess.WRITE)
	var scene = load("res://scenes/levels/hotel_siberia/base_hotel_level.tscn")
	if not scene:
		file.store_line("Failed to load scene")
		quit()
		return
	
	var inst = scene.instantiate()
	var gen = inst.get_node_or_null("NavigationRegion3D/HotelGeometry")
	if not gen:
		file.store_line("No generator found")
		quit()
		return
		
	# Call generate level manually
	gen._generate_level()
	
	file.store_line("Generated Floor Main is:")
	var floor = gen.get_node_or_null("GeneratedFloor_Main")
	if floor:
		file.store_line("Floor found! Children:")
		for c in floor.get_children():
			file.store_line("- " + c.name + " (" + str(c.position) + ")")
	else:
		file.store_line("ERROR: GeneratedFloor_Main not found!")
		
	file.close()
	quit()
