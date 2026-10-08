extends Node

# Checks the floor-unlock chain end to end, on the real generator and GameStateManager:
#   - the elevator only ever delivers to unlocked floors, every locked button lands on floor 4
#   - a floor's tape count survives leaving the floor and coming back
#   - floor 3's three tapes open its corridor barrier and unlock floor 5
#   - every furnished floor (2..10) actually has three distinct tapes to find
#
# Run via: godot --headless tests/test_progression.tscn

var errors: int = 0

func _check(ok: bool, label: String) -> void:
	if ok:
		print("✅ PASS: ", label)
	else:
		print("❌ FAIL: ", label)
		errors += 1

func _routes() -> Array:
	var out: Array = []
	for i in range(1, 11):
		out.append(ElevatorController.route_floor(i))
	return out

func _collect(floor_num: int, tape_id: int) -> void:
	# Same two calls, same order, as vhs_tape.gd's interact().
	GameStateManager.collect_tape(tape_id)
	GameStateManager.add_to_inventory(floor_num, tape_id)

func _ready() -> void:
	print("==================================================")
	print("  AUTOTEST: PROGRESSION (TAPES / ELEVATOR / FLOORS)")
	print("==================================================")

	var generator := Node3D.new()
	generator.set_script(load("res://scripts/levels/hotel_level_generator.gd"))
	add_child(generator) # _ready() builds the level and seeds floor access at floor 4

	# --- Elevator, nothing unlocked yet ---
	_check(_routes() == [4, 4, 4, 4, 4, 4, 4, 4, 4, 4],
		"at the start every elevator button leads to floor 4: " + str(_routes()))

	# --- Tapes on every furnished floor ---
	for f in range(2, 11):
		var floor_node = generator.get_node_or_null("GeneratedFloor_" + ("Main" if f == 4 else str(f)))
		var ids: Array = []
		if floor_node:
			for child in floor_node.get_children():
				if child.name.begins_with("Cassette_"):
					ids.append(child.tape_id)
		ids.sort()
		_check(ids == [0, 1, 2], "floor %d has three distinct tapes: %s" % [f, str(ids)])

	# --- Floor 4 done -> secret door -> floor 3 ---
	for id in range(3):
		_collect(4, id)
	_check(GameStateManager.secret_portal_active, "floor 4's three tapes roll the secret door")
	var floor4 = generator.get_node("GeneratedFloor_Main")
	var secret_door: Node3D = floor4.get_node_or_null("SecretExitDoor")
	_check(secret_door != null, "the secret door actually exists on floor 4")
	var portal: Area3D = null
	for child in floor4.get_children():
		if child is Area3D and "target_floor" in child and "target_position" in child:
			portal = child
	_check(portal != null and portal.target_floor == 3 and portal.target_position != Vector3.ZERO,
		"its portal leads to a real spot on floor 3")
	if secret_door and portal:
		var half_x: float = HotelLevelGenerator.BUILDING_WIDTH_X / 2.0 * GlobalConfig.get_floor_scale()
		_check(absf(absf(secret_door.position.x) - half_x) < 0.2, "the secret door is in the building's outer wall")
		_check(absf(portal.position.x) > absf(secret_door.position.x),
			"the portal starts beyond the wall, not inside the room")
		# Not on a partition between two rooms: room edges along Z fall on multiples of 10m on
		# the west (double-room) side and of 5m on the east (single-room) side.
		var room_depth: float = 10.0 if secret_door.position.x < 0.0 else 5.0
		var from_edge: float = absf(fposmod(secret_door.position.z + room_depth / 2.0, room_depth) - room_depth / 2.0)
		_check(from_edge > 0.7, "the secret door is clear of the room partitions (%.2fm from the nearest)" % from_edge)
	_check(_routes() == [4, 4, 4, 4, 4, 4, 4, 4, 4, 4],
		"the secret door existing does not unlock anything by itself")

	# What secret_portal.gd does when the player steps through.
	GameStateManager.unlock_floor(3)
	GameStateManager.current_floor = 3
	_check(_routes() == [4, 4, 3, 4, 4, 4, 4, 4, 4, 4],
		"with floor 3 unlocked the elevator runs 3 <-> 4, everything else leads to 4: " + str(_routes()))
	_check(not GameStateManager.is_floor_unlocked(5), "floor 5 is still locked")

	# --- Tape count survives a detour to another floor ---
	_collect(3, 0)
	_collect(3, 1)
	GameStateManager.current_floor = 4
	_check(GameStateManager.tapes_found.size() == 3, "back on floor 4 its own count is 3/3")
	GameStateManager.current_floor = 3
	_check(GameStateManager.tapes_found.size() == 2, "returning to floor 3 restores its count to 2/3")

	# --- Floor 3 done -> barrier off, floor 5 unlocked ---
	_check(not GameStateManager.floor3_corridor_unlocked, "floor 3's corridor barrier is still up")
	_collect(3, 2)
	_check(GameStateManager.floor3_corridor_unlocked, "floor 3's third tape switches the corridor barrier off")
	_check(GameStateManager.is_floor_unlocked(5), "floor 3's third tape unlocks floor 5")
	_check(_routes() == [4, 4, 3, 4, 5, 4, 4, 4, 4, 4],
		"the elevator now reaches 3, 4 and 5, everything else leads to 4: " + str(_routes()))

	print("==================================================")
	if errors > 0:
		print("❌ FAILED with ", errors, " error(s).")
		get_tree().quit(1)
	else:
		print("✅ Progression chain works.")
		get_tree().quit(0)
