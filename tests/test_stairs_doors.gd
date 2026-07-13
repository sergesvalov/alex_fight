extends Node

func _ready() -> void:
	print("\n==================================================")
	print("  AUTOTEST: STAIRS & DOORWAYS VALIDATION")
	print("==================================================")
	
	# Load generator
	var gen_script = load("res://scripts/levels/hotel_level_generator.gd")
	if not gen_script:
		print("❌ [FAILED] Could not load generator script")
		get_tree().quit(1)
		return
		
	var generator = Node3D.new()
	generator.set_script(gen_script)
	add_child(generator)
	
	print("⏳ Forcing CSG mesh generation (Headless workaround)...")
	_force_csg_update(generator)
	
	print("⏳ Waiting for CSG processing...")
	await get_tree().create_timer(1.0).timeout
	
	var space_state = generator.get_world_3d().direct_space_state
	if not space_state:
		print("❌ [FAILED] Could not get physics space state.")
		get_tree().quit(1)
		return
		
	var errors = 0
	
	print("\n--- Testing DoorHoleEast (Lower Entry) ---")
	# Expected DoorEast center is X=3.85, Y=1.1, Z=-25.1
	var east_door_pos = Vector3(3.85, 1.1, -25.1)
	errors += _test_point(space_state, east_door_pos, "Center of DoorHoleEast", false)
	errors += _test_point(space_state, east_door_pos + Vector3(0, 0.9, 0), "Top of DoorHoleEast", false)
	errors += _test_point(space_state, east_door_pos + Vector3(0, -0.9, 0), "Bottom of DoorHoleEast", false)
	
	print("\n--- Testing DoorHoleWest (Upper Exit) ---")
	# Expected DoorWest center is X=-1.75, Y=5.6, Z=-25.1
	var west_door_pos = Vector3(-1.75, 5.6, -25.1)
	errors += _test_point(space_state, west_door_pos, "Center of DoorHoleWest", false)
	
	print("\n--- Testing Solid Walls (Should return hit) ---")
	# Solid wall between doors
	var center_wall_pos = Vector3(1.05, 1.1, -25.1)
	errors += _test_point(space_state, center_wall_pos, "Center South Wall (Y=1.1)", true)
	
	var west_wall_pos = Vector3(-1.75, 1.1, -25.1)
	errors += _test_point(space_state, west_wall_pos, "West Wall under Door (Y=1.1)", true)
	
	var east_wall_pos = Vector3(3.85, 5.6, -25.1)
	errors += _test_point(space_state, east_wall_pos, "East Wall over Door (Y=5.6)", true)
	
	print("\n==================================================")
	if errors > 0:
		print("❌ Test FAILED with ", errors, " errors.")
		get_tree().quit(1 if errors > 0 else 0)
	else:
		print("✅ Test complete. All points passed.")
		get_tree().quit(0)

func _force_csg_update(node: Node) -> void:
	if node is CSGShape3D:
		node.get_meshes()
	for child in node.get_children():
		_force_csg_update(child)

func _test_point(space_state: PhysicsDirectSpaceState3D, pos: Vector3, label: String, expected_hit: bool) -> int:
	var p = PhysicsPointQueryParameters3D.new()
	p.position = pos
	p.collision_mask = 2 # Check for wall geometry
	
	var results = space_state.intersect_point(p, 1)
	var is_hit = results.size() > 0
	
	if is_hit == expected_hit:
		if is_hit:
			print("✅ PASS | ", label, " (", pos, ") -> WALL BLOCKED! (Expected) by ", results[0].collider.name)
		else:
			print("✅ PASS | ", label, " (", pos, ") -> OPENING CONFIRMED! (Expected)")
		return 0
	else:
		if is_hit:
			print("❌ FAIL | ", label, " (", pos, ") -> WALL BLOCKED! (UNEXPECTED) by ", results[0].collider.name)
		else:
			print("❌ FAIL | ", label, " (", pos, ") -> OPENING MISSING! (UNEXPECTED)")
		return 1
