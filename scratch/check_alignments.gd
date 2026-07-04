extends SceneTree

func _init():
	var scene = load("res://scenes/levels/hotel_siberia/base_hotel_level.tscn")
	var instance = scene.instantiate()
	var root = instance.find_child("HotelGeometry", true, false)
	if root:
		var mismatches = DebugGeometry.print_room_alignments(root)
		print("MISMATCHES: ", mismatches)
	else:
		print("HotelGeometry not found")
	quit()
