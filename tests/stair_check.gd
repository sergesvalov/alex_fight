## Headless check script: verify north stairs CSG builds correctly
## Usage: godot --headless -s tests/stair_check.gd
extends SceneTree

func _init() -> void:
	print("=== STAIRWELL CSG CHECK ===")
	var stair_scene = load("res://scenes/levels/hotel_siberia/blocks/north_stairs.tscn")
	if not stair_scene:
		print("[FAILED] north_stairs.tscn not found")
		quit(1)
		return

	var stair = stair_scene.instantiate()
	var root_node = Node3D.new()
	root_node.add_child(stair)

	# Force CSG to bake
	var csg = stair.get_node_or_null("StairsGeometry")
	if not csg:
		print("[FAILED] StairsGeometry node not found!")
		quit(1)
		return
		
	csg._update_shape()
	
	var meshes = csg.get_meshes()
	if meshes.size() < 2:
		print("[FAILED] CSG get_meshes() did not return mesh array")
		quit(1)
		return
		
	var mesh = meshes[1] as ArrayMesh
	if not mesh:
		print("[FAILED] CSG did not generate an ArrayMesh")
		quit(1)
		return
		
	var faces = mesh.get_faces()
	if faces.size() == 0:
		print("❌ [FAILED] CSG Combiner returned 0 vertices! The boolean logic crashed!")
		
		print("\n--- Diagnostic: Isolating broken nodes ---")
		var flights = ["EastFlight", "NorthFlight", "WestFlight", "SouthWall_WestUnder", "SouthWall_WestOver", "SouthWall_EastOver"]
		for flight_name in flights:
			var node = csg.get_node_or_null(flight_name)
			if node:
				var parent = node.get_parent()
				parent.remove_child(node)
				csg._update_shape()
				var m = csg.get_meshes()
				if m.size() >= 2 and m[1].get_faces().size() > 0:
					print("💡 FOUND IT! Removing '", flight_name, "' fixes the mesh!")
				parent.add_child(node)
				
		quit(1)
		return
		
	print("✅ [OK] CSG Combiner successfully generated ", faces.size(), " vertices.")
	print("================================")
	quit(0)
