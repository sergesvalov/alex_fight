extends SceneTree

func _init():
	var scene = load("res://scenes/levels/hotel_siberia/base_hotel_level.tscn")
	var root = scene.instantiate()
	var gen = root.get_node("HotelLevelGenerator")
	gen._generate_level()
	
	var file = FileAccess.open("C:/wndr/repo/alex_fight/door_dump.txt", FileAccess.WRITE)
	file.store_line("--- DOOR DUMP ---")
	_dump_doors(root, "", file)
	file.close()
	quit()

func _dump_doors(node: Node, path: String, file: FileAccess):
	if "Door" in node.name:
		var pos = "unknown"
		if node is Node3D:
			pos = str(node.global_transform.origin)
		file.store_line(path + node.name + " -> pos: " + pos)
	for child in node.get_children():
		_dump_doors(child, path + node.name + "/", file)
