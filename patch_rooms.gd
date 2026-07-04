extends SceneTree

func _init():
	var scenes = [
		"res://scenes/levels/hotel_siberia/rooms/single_room.tscn",
		"res://scenes/levels/hotel_siberia/rooms/double_room.tscn",
		"res://scenes/levels/hotel_siberia/rooms/double_room_large.tscn"
	]
	
	for path in scenes:
		var pack = load(path) as PackedScene
		if not pack:
			print("Could not load ", path)
			continue
			
		var root = pack.instantiate()
		
		# Add RoomLightController
		if not root.has_node("RoomLightController"):
			var lc = Node.new()
			lc.name = "RoomLightController"
			lc.set_script(preload("res://scripts/levels/rooms/room_light_controller.gd"))
			root.add_child(lc)
			lc.owner = root
			lc.room_light = root.get_node_or_null("RoomLight")
			lc.wc_light = root.get_node_or_null("WC_Light")
			print("Added RoomLightController to ", path)
			
		# Add RoomLabelManager
		if not root.has_node("RoomLabelManager"):
			var lm = Node.new()
			lm.name = "RoomLabelManager"
			lm.set_script(preload("res://scripts/levels/rooms/room_label_manager.gd"))
			root.add_child(lm)
			lm.owner = root
			print("Added RoomLabelManager to ", path)
			
		# Remove old properties from CSGCombiner3D (like room_label etc, if they existed)
		# Actually the script room.gd update handles removing properties. We just resave.
		
		var new_pack = PackedScene.new()
		new_pack.pack(root)
		ResourceSaver.save(new_pack, path)
		print("Saved ", path)
		
	quit()
