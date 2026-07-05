@tool
extends SceneTree

func _init():
	var level_gen = load("res://scripts/levels/hotel_level_generator.gd").new()
	level_gen._generate_level()
	var parent = level_gen.get_node_or_null("GeneratedFloor_Main")
	if not parent:
		print("ERROR: GeneratedFloor_Main not found")
		quit()
		return
		
	for child in parent.get_children():
		if child is StaticBody3D:
			var col = null
			for c in child.get_children():
				if c is CollisionShape3D:
					col = c
					break
			if col and col.shape is BoxShape3D:
				var size = col.shape.size
				var pos = child.position
				var min_pos = pos - size / 2.0
				print(child.name + " : min=" + str(min_pos) + ", size=" + str(size))
			else:
				print(child.name + " : NO BOX SHAPE")
	print("DONE AABBS")
	quit()
