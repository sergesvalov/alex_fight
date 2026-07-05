extends SceneTree

func _init():
	var file = FileAccess.open("generate_log.txt", FileAccess.WRITE)
	file.store_line("Starting test run...")
	var scene = load("res://scenes/levels/hotel_siberia/hotel_level.tscn")
	if not scene:
		file.store_line("Failed to load scene")
		quit()
		return
	
	file.store_line("Instantiating scene...")
	var root = scene.instantiate()
	get_root().add_child(root)
	
	var gen = root.get_node_or_null("NavigationRegion3D/HotelGeometry")
	file.store_line("Generator node: " + str(gen))
	
	var player = root.get_node_or_null("Player")
	if player:
		file.store_line("Player position at start: " + str(player.global_position))
	
	# Try calling _ready on root if not called automatically?
	# Godot SceneTree should call it when added to root.
	
	await create_timer(1.0).timeout
	
	if player:
		file.store_line("Player position after 1 second: " + str(player.global_position))
		
	if gen:
		var floor = gen.get_node_or_null("GeneratedFloor_Main")
		file.store_line("Floor generated: " + str(floor != null))
		if floor:
			file.store_line("Floor children count: " + str(floor.get_child_count()))
			for c in floor.get_children():
				file.store_line("- " + c.name + " at " + str(c.global_position))
				
	file.close()
	quit()
