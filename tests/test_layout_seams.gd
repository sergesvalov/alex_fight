extends Node

# Headless geometry "seam checker" - no CSG mesh generation and no rendering needed,
# since it only reads the *declared* transform/size of each wall box (CSGBox3D.size,
# BoxShape3D.size), which are plain script-readable properties available the instant
# a scene is instantiated. This exists because every wall/room bug found in August
# 2026 (elevator<->maintenance adjacency, a supposed "west wall dead zone", ramp
# endpoints) was diagnosed by hand on paper, with no engine available to check the
# arithmetic against. The dead-zone one turned out to be a bug in that hand
# arithmetic, not in the game - this script computes room footprints from the real
# wall nodes instead of from someone's assumption about which wall is "the outer one".
#
# Run via: godot --headless tests/test_layout_seams.tscn

var errors: int = 0

func _ready() -> void:
	print("==================================================")
	print("  AUTOTEST: LAYOUT SEAMS")
	print("==================================================")

	var f_scale = GlobalConfig.get_floor_scale() if GlobalConfig else 1.0

	_check_room_vs_building_wall(
		"res://scenes/levels/hotel_siberia/blocks/double_room.tscn",
		HotelLevelGenerator.DOUBLE_ROOM_BASE_X, false, "DoubleRoom", f_scale
	)
	_check_room_vs_building_wall(
		"res://scenes/levels/hotel_siberia/blocks/single_room.tscn",
		HotelLevelGenerator.SINGLE_ROOM_BASE_X, true, "SingleRoom", f_scale
	)

	_check_generated_floor(f_scale)

	print("==================================================")
	if errors > 0:
		print("❌ FAILED with ", errors, " seam error(s).")
		get_tree().quit(1)
	else:
		print("✅ All seams check out.")
		get_tree().quit(0)

# --- Room footprint vs. the building's own outer wall ---
# Finds every solid (non-hole) CSGBox3D under a room scene's RoomGeometry and takes
# the union of their X extents. This is the room's REAL footprint - it does not
# assume any particular node ("the west wall", "the WC partition") is the boundary.

func _find_csg_boxes(node: Node, out: Array) -> void:
	if node is CSGBox3D:
		out.append(node)
	for child in node.get_children():
		_find_csg_boxes(child, out)

func _room_true_x_range(scene_path: String) -> Vector2:
	var scene = load(scene_path)
	var inst = scene.instantiate()
	var boxes: Array = []
	_find_csg_boxes(inst, boxes)

	var min_x = INF
	var max_x = -INF
	for box in boxes:
		if box.operation == CSGBox3D.OPERATION_SUBTRACTION:
			continue  # a hole, not part of the room's solid footprint
		var half = box.size.x / 2.0
		var cx = box.transform.origin.x
		min_x = min(min_x, cx - half)
		max_x = max(max_x, cx + half)

	inst.free()
	return Vector2(min_x, max_x)

func _check_room_vs_building_wall(scene_path: String, base_x: float, is_east_side: bool, label: String, f_scale: float) -> void:
	var local_range = _room_true_x_range(scene_path)
	if local_range.x == INF:
		print("❌ FAIL: ", label, " - no solid CSGBox3D walls found under RoomGeometry")
		errors += 1
		return

	var global_min = (base_x + local_range.x) * f_scale
	var global_max = (base_x + local_range.y) * f_scale
	var half_x = (HotelLevelGenerator.BUILDING_WIDTH_X / 2.0) * f_scale

	if is_east_side:
		_assert_seam(half_x - global_max, label + " east edge <-> building east wall")
	else:
		_assert_seam(global_min - (-half_x), label + " west edge <-> building west wall")

# --- Generated-floor cross-structure checks (elevator/maintenance, south stairs) ---

func _check_generated_floor(f_scale: float) -> void:
	var gen_script = load("res://scripts/levels/hotel_level_generator.gd")
	var generator := Node3D.new()
	generator.set_script(gen_script)
	# add_child() on a node already inside a live tree fires _ready() synchronously,
	# which is what actually runs _generate_level() - don't call it again here (it
	# would just free and rebuild everything a second time for nothing).
	add_child(generator)

	var floor_node = generator.find_child("GeneratedFloor_Main", true, false)
	if not floor_node:
		print("❌ FAIL: GeneratedFloor_Main not found - is generator.floor_number still 4?")
		errors += 1
		generator.queue_free()
		return

	_check_elevator_vs_maintenance(floor_node)
	_check_south_stairs_floor_slabs(floor_node, f_scale)
	_check_south_stairs_ramp_surfaces(floor_node, f_scale)

	generator.queue_free()

func _csgbox_x_range(box: CSGBox3D) -> Vector2:
	var half = box.size.x / 2.0
	var cx = box.global_transform.origin.x
	return Vector2(cx - half, cx + half)

# _create_static_box() never sets an explicit name on the CollisionShape3D it creates,
# so it gets whatever default Godot assigns - looking it up by the literal path
# "CollisionShape3D" is not reliable. Finding it by type is.
func _find_collision_shape(body: Node) -> CollisionShape3D:
	for child in body.get_children():
		if child is CollisionShape3D:
			return child
	return null

func _static_box_x_range(body: Node3D) -> Vector2:
	var coll: CollisionShape3D = _find_collision_shape(body)
	if not coll or not coll.shape:
		return Vector2(NAN, NAN)
	var half = coll.shape.size.x / 2.0
	var cx = body.global_transform.origin.x
	return Vector2(cx - half, cx + half)

func _check_elevator_vs_maintenance(floor_node: Node) -> void:
	var east_wall = floor_node.find_child("ElevatorEastWall", true, false)
	var maint_wall = floor_node.find_child("Maint_Inner_West_North", true, false)
	if not east_wall or not maint_wall:
		print("❌ FAIL: could not find ElevatorEastWall / Maint_Inner_West_North to compare")
		errors += 1
		return

	var elevator_range = _csgbox_x_range(east_wall)
	var maint_range = _static_box_x_range(maint_wall)
	_assert_seam(maint_range.x - elevator_range.y, "Elevator east wall <-> Maintenance west wall")

func _check_south_stairs_floor_slabs(floor_node: Node, f_scale: float) -> void:
	# The dog-leg ramps (SouthStairsRampA/B, see _generate_south_stairs_ramp) bridge
	# the gap between these two floor slabs, so the gap here should be the ramps'
	# designed run - not zero. This just confirms the slabs are where that ramp
	# math assumes they are, in case the two ever drift apart.
	var floor_sw = floor_node.find_child("Floor_SW", true, false)
	var landing = floor_node.find_child("Landing_SouthStairs", true, false)
	if not floor_sw or not landing:
		print("❌ FAIL: could not find Floor_SW / Landing_SouthStairs to compare")
		errors += 1
		return

	var sw_range = _static_box_x_range(floor_sw)
	var landing_range = _static_box_x_range(landing)
	var expected_run = (HotelLevelGenerator.SOUTH_STAIRS_LANDING_INNER_X - HotelLevelGenerator.SOUTH_STAIRS_RAMP_INNER_X) * f_scale
	var actual_run = landing_range.x - sw_range.y
	if abs(actual_run - expected_run) > 0.05:
		print("❌ FAIL: Floor_SW <-> Landing_SouthStairs gap = ", actual_run, "m, expected ", expected_run, "m (ramp run)")
		errors += 1
	else:
		print("✅ PASS: Floor_SW <-> Landing_SouthStairs gap = ", actual_run, "m (matches ramp run)")

# --- South stairs ramp WALKING SURFACE alignment ---
# _create_static_box positions a box by its geometric center, not its top (walkable) face -
# once a box is rotated to form a ramp, the top face sits away from the center perpendicular
# to the slope, not straight up. A version of the ramp that only matched centerlines to the
# floor/landing heights left a real, in-game-tested unwalkable step (~0.15m) where the ramp
# met the landing - blocking going up while going down still worked (a ledge you step down
# off doesn't stop you; one you'd have to step up onto does). This computes the actual
# world-space corner of each ramp's top face and checks it against the floor/landing surface
# it's supposed to meet, instead of trusting the box's declared center position.

func _static_box_top_y(body: Node3D) -> float:
	var coll: CollisionShape3D = _find_collision_shape(body)
	if not coll or not coll.shape:
		return NAN
	return body.global_transform.origin.y + coll.shape.size.y / 2.0

func _ramp_surface_at_local_x(ramp: Node3D, x_sign: float) -> Vector3:
	var coll: CollisionShape3D = _find_collision_shape(ramp)
	if not coll or not coll.shape:
		return Vector3(NAN, NAN, NAN)
	var half_len = coll.shape.size.x / 2.0
	var half_thick = coll.shape.size.y / 2.0
	var local_corner = Vector3(x_sign * half_len, half_thick, 0.0)  # top face, at the given end
	return ramp.global_transform * local_corner

func _assert_surface_match(actual_y: float, expected_y: float, label: String, tolerance: float = 0.03) -> void:
	if is_nan(actual_y) or is_nan(expected_y):
		print("❌ FAIL: ", label, " - could not measure geometry (missing CollisionShape3D)")
		errors += 1
	elif abs(actual_y - expected_y) > tolerance:
		print("❌ FAIL: ", label, " - height mismatch: ", actual_y, "m vs ", expected_y, "m (diff ", actual_y - expected_y, "m) - unwalkable step")
		errors += 1
	else:
		print("✅ PASS: ", label, " - surfaces align (", actual_y, "m vs ", expected_y, "m)")

func _check_south_stairs_ramp_surfaces(floor_node: Node, f_scale: float) -> void:
	var ramp_a = floor_node.find_child("SouthStairsRampA", true, false)
	var ramp_b = floor_node.find_child("SouthStairsRampB", true, false)
	var floor_sw = floor_node.find_child("Floor_SW", true, false)
	var landing = floor_node.find_child("Landing_SouthStairs", true, false)
	if not ramp_a or not ramp_b or not floor_sw or not landing:
		print("❌ FAIL: could not find ramp/floor/landing nodes for surface check")
		errors += 1
		return

	var floor_surface_y = _static_box_top_y(floor_sw)
	var landing_surface_y = _static_box_top_y(landing)

	# RampA: rotation = +angle_up, so its local +X end is the high (landing) end and
	# local -X end is the low (Floor_SW) end.
	var ramp_a_low = _ramp_surface_at_local_x(ramp_a, -1.0)
	var ramp_a_high = _ramp_surface_at_local_x(ramp_a, 1.0)
	_assert_surface_match(ramp_a_low.y, floor_surface_y, "RampA bottom <-> Floor_SW surface")
	_assert_surface_match(ramp_a_high.y, landing_surface_y, "RampA top <-> Landing surface")

	# RampB: rotation = -angle_up, so its local +X end is the low (landing) end and
	# local -X end is the high (next floor's surface) end.
	var ramp_b_low = _ramp_surface_at_local_x(ramp_b, 1.0)
	var ramp_b_high = _ramp_surface_at_local_x(ramp_b, -1.0)
	_assert_surface_match(ramp_b_low.y, landing_surface_y, "RampB bottom <-> Landing surface")
	var expected_top = HotelLevelGenerator.BASE_FLOOR_TO_FLOOR_HEIGHT * f_scale
	_assert_surface_match(ramp_b_high.y, expected_top, "RampB top <-> next floor's surface")

# --- Shared assertion ---
# A "seam" between two adjacent pieces should be a small, ~0.1m natural clearance
# (same tolerance used all over this generator) - never a multi-meter dead zone,
# and never negative beyond a tiny float-precision margin (i.e. no interpenetration).

func _assert_seam(gap: float, label: String, max_gap: float = 0.3, min_gap: float = -0.05) -> void:
	if is_nan(gap):
		print("❌ FAIL: ", label, " - could not measure geometry (missing CollisionShape3D)")
		errors += 1
	elif gap > max_gap:
		print("❌ FAIL: ", label, " - gap = ", gap, "m (> ", max_gap, "m) - looks like a dead zone")
		errors += 1
	elif gap < min_gap:
		print("❌ FAIL: ", label, " - gap = ", gap, "m (< ", min_gap, "m) - geometry overlaps/interpenetrates")
		errors += 1
	else:
		print("✅ PASS: ", label, " - gap = ", gap, "m")
