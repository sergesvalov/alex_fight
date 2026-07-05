@tool
extends EditorScript

func _run():
	var files_to_process = [
		"res://scenes/levels/hotel_siberia/rooms/single_room.tscn",
		"res://scenes/levels/hotel_siberia/rooms/double_room.tscn",
		"res://scenes/levels/hotel_siberia/rooms/double_room_large.tscn"
	]

	for path in files_to_process:
		var pack = load(path) as PackedScene
		if not pack: continue
		var root = pack.instantiate()
		var changed = false
		
		# Find and remove any node containing "Door" but not "Hole"
		var nodes_to_remove = []
		_find_doors(root, nodes_to_remove)
		
		for node in nodes_to_remove:
			node.get_parent().remove_child(node)
			node.queue_free()
			changed = true
			print("Removed ", node.name, " from ", path)
			
		if changed:
			var new_pack = PackedScene.new()
			new_pack.pack(root)
			ResourceSaver.save(new_pack, path)
			print("Saved ", path)

func _find_doors(node: Node, list: Array):
	if "Door" in node.name and not "Hole" in node.name:
		list.append(node)
	for child in node.get_children():
		_find_doors(child, list)
