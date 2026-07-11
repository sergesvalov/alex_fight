@tool
extends EditorScript

func _run():
	print("\n=== RUNNING NORTH STAIRS CSG TEST ===")
	var scene = load("res://scenes/levels/hotel_siberia/blocks/north_stairs.tscn")
	if not scene:
		print("FAILED to load scene.")
		return
		
	var inst = scene.instantiate()
	var root = Node3D.new()
	root.add_child(inst)
	
	var csg = inst.get_node_or_null("StairsGeometry")
	if not csg:
		print("FAILED: StairsGeometry not found.")
		return
		
	# Force CSG to bake
	csg._update_shape()
	var meshes = csg.get_meshes()
	
	if meshes.size() < 2:
		print("FAILED: get_meshes() did not return an array mesh.")
		root.queue_free()
		return
		
	var mesh = meshes[1] as ArrayMesh
	if mesh:
		var faces = mesh.get_faces()
		if faces.size() == 0:
			print("❌ FAILED: CSGCombiner3D returned an EMPTY mesh (0 vertices).")
			
			print("Attempting to isolate the broken node...")
			var flights = ["EastFlight", "NorthFlight", "WestFlight"]
			
			for flight_name in flights:
				var node = csg.get_node_or_null(flight_name)
				if node:
					var parent = node.get_parent()
					parent.remove_child(node)
					csg._update_shape()
					var m = csg.get_meshes()
					if m.size() >= 2 and m[1].get_faces().size() > 0:
						print("💡 FOUND IT! Removing '", flight_name, "' fixes the mesh! The error is in this node.")
					parent.add_child(node) # put it back
					
			print("Checking if it's the doors...")
			var doors = ["SouthWall_WestUnder", "SouthWall_WestOver", "SouthWall_EastOver"]
			for door in doors:
				var node = csg.get_node_or_null(door)
				if node:
					var parent = node.get_parent()
					parent.remove_child(node)
					csg._update_shape()
					var m = csg.get_meshes()
					if m.size() >= 2 and m[1].get_faces().size() > 0:
						print("💡 FOUND IT! Removing '", door, "' fixes the mesh!")
					parent.add_child(node)
			
			print("If no 'FOUND IT' messages appeared, multiple nodes might be causing issues together.")
			
		else:
			print("✅ OK: CSGCombiner3D generated ", faces.size(), " vertices successfully! The geometry is NOT empty.")
			print("If you still don't see it in the game, the issue is not in CSG geometry, but in instantiation logic.")
	else:
		print("FAILED: No ArrayMesh found.")
		
	root.queue_free()
	print("=== TEST FINISHED ===\n")
