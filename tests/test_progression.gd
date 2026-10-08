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

	# --- Tape narration: every reachable floor has real text, the rest fall back gracefully ---
	for f in [3, 4, 5, 6]:
		var ok := true
		for id in range(3):
			var tape: Dictionary = DialogSystem.get_tape(f, id)
			if tape.get("text", "") == "" or "ЗАГЛУШКА" in tape.get("title", "") or tape == DialogSystem.tape_data.get("damaged"):
				ok = false
		_check(ok, "floor %d has written narration for all three tapes" % f)
	_check(DialogSystem.get_tape(9, 0).get("title", "") != "",
		"a floor with no narration yet plays the 'damaged tape' fallback instead of nothing")

	# --- Tape location hints (what the CRT terminal lists) ---
	var hints5: Array = []
	for child in generator.get_floor_node(5).get_children():
		if child.name.begins_with("Cassette_"):
			hints5.append(child.location_hint)
	hints5.sort()
	_check(hints5 == ["tape_hint_maintenance", "tape_hint_sealed", "tape_hint_table"],
		"floor 5's tapes carry their location hints: " + str(hints5))
	_check(hints5.all(func(h): return UIStrings.get_string(h) != ""), "every hint has its text in ui_strings.json")

	# --- The extra robot of a finished floor appears on THAT floor ---
	var spawner := Node3D.new()
	spawner.set_script(load("res://scripts/levels/enemy_spawner.gd"))
	spawner.enemy_scene = load("res://entities/enemies/cerberus/cerberus.tscn")
	spawner.spawn_position = Vector3(1.05, 1.0, -25.0)
	add_child(spawner)
	var y_step: float = HotelLevelGenerator.BASE_FLOOR_TO_FLOOR_HEIGHT * GlobalConfig.get_floor_scale()

	# --- Floor 4 done -> secret door -> floor 3 ---
	for id in range(3):
		_collect(4, id)
	_check(spawner.get_child_count() == 1 and absf(spawner.get_child(0).global_position.y - 1.0) < 0.01,
		"floor 4's third tape brings one extra robot, on floor 4")
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
	_check(spawner.get_child_count() == 2 and absf(spawner.get_child(1).global_position.y - (1.0 - y_step)) < 0.01,
		"floor 3's third tape brings its extra robot on floor 3, not floor 4 (y=%.2f)" % spawner.get_child(spawner.get_child_count() - 1).global_position.y)

	# --- A tape picked up while another is still narrating is queued, not dropped ---
	DialogSystem.play_tape_for_floor(3, 0, Vector3.ZERO)
	DialogSystem.play_tape_for_floor(3, 1, Vector3.ZERO)
	_check(DialogSystem.is_playing and DialogSystem._tape_queue.size() == 1,
		"a second tape started mid-narration waits in the queue (%d queued)" % DialogSystem._tape_queue.size())
	DialogSystem._tape_queue.clear()
	_check(is_instance_valid(DialogSystem._holo_instance), "a playing tape has its hologram")
	DialogSystem.end_narrative()
	_check(DialogSystem._holo_instance == null and not DialogSystem.is_playing,
		"the hologram is removed when the narration ends")

	# --- The terminal archive opens up as tapes are recovered ---
	var needs: Array = DialogSystem.terminal_entries.map(func(e): return int(e.get("requires_tapes", -1)))
	var sorted_needs: Array = needs.duplicate()
	sorted_needs.sort()
	_check(needs.size() > 0 and needs[0] == 0 and needs == sorted_needs and needs.max() <= 27,
		"archive entries unlock progressively, the first one from the start: " + str(needs))
	_check(GameStateManager.is_floor_unlocked(5), "floor 3's third tape unlocks floor 5")
	_check(_routes() == [4, 4, 3, 4, 5, 4, 4, 4, 4, 4],
		"the elevator now reaches 3, 4 and 5, everything else leads to 4: " + str(_routes()))

	# --- Floor 5: the room-shuffling trap ---
	var trap_script = load("res://scripts/levels/blocks/room_shuffle_trap.gd")
	var floor5: Node3D = generator.get_node("GeneratedFloor_5")
	var traps: Array = []
	for child in floor5.get_children():
		if child.name.begins_with("RoomShuffleTrap_"):
			traps.append(child)
	_check(traps.size() == 15, "floor 5 has a trap in each of its 15 rooms (%d)" % traps.size())
	_check(generator.get_node("GeneratedFloor_6").get_children().filter(
		func(c): return c.name.begins_with("RoomShuffleTrap_")).is_empty(), "no other floor has the trap")

	var always_moves := true
	var all_reachable := true
	for tapes in range(3):
		var reached: Dictionary = {}
		for i in range(15):
			var dest: int = trap_script.destination_index(i, tapes, 15)
			if dest == i:
				always_moves = false
			reached[dest] = true
		if reached.size() != 15:
			all_reachable = false
	_check(always_moves, "entering a room never leaves you in that same room")
	_check(all_reachable, "every room, the sealed one included, is the destination of some door")

	var sealed_room: Node3D = floor5.get_meta("sealed_room") if floor5.has_meta("sealed_room") else null
	_check(sealed_room != null, "floor 5 has a sealed room")
	if sealed_room:
		var sealed_door = sealed_room.get_node("RoomDoor/AnimatableBody3D")
		_check(sealed_door.locked_from_corridor, "the sealed room's door is locked from the corridor")
		var tapes_inside: int = 0
		var tapes_on_floor: int = 0
		for child in floor5.get_children():
			if child.name.begins_with("Cassette_"):
				tapes_on_floor += 1
				var local: Vector3 = sealed_room.global_transform.affine_inverse() * child.global_position
				# Rooms are at most 10m deep and ~10m wide around their own origin.
				if absf(local.x) < 5.0 and local.z > 0.0 and local.z < (10.0 if sealed_room.name.begins_with("Double") else 5.0):
					tapes_inside += 1
		_check(tapes_inside == 1 and tapes_on_floor == 3,
			"exactly one of floor 5's three tapes is in the sealed room (%d of %d)" % [tapes_inside, tapes_on_floor])

		# --- Floor 5 done -> trap off, sealed door opens, floor 6 unlocked ---
		GameStateManager.current_floor = 5
		_check(not GameStateManager.is_floor_unlocked(6), "floor 6 is locked before floor 5 is done")
		for id in range(3):
			_collect(5, id)
		_check(GameStateManager.floor5_rooms_unlocked, "floor 5's three tapes switch the room trap off")
		_check(not sealed_door.locked_from_corridor, "the sealed room's door opens normally afterwards")
		_check(GameStateManager.is_floor_unlocked(6), "floor 5's three tapes unlock floor 6")
		_check(_routes() == [4, 4, 3, 4, 5, 6, 4, 4, 4, 4],
			"the elevator now reaches 3-6, everything else leads to 4: " + str(_routes()))

	# --- Floor 6, through the real pickup code: recordings come in order of finding, and the
	# --- robot of that floor (and only that floor) comes for the sound ---
	DialogSystem.end_narrative()
	DialogSystem._tape_queue.clear()
	GameStateManager.current_floor = 6
	generator._set_lit_floor(6) # what the generator does itself once the player is up there
	var floor6: Node3D = generator.get_floor_node(6)
	var listener := CharacterBody3D.new()
	listener.add_to_group("player")
	add_child(listener)
	listener.global_position = floor6.global_position + Vector3(1.0, 0.1, 5.0)

	var cassettes: Array = []
	for child in floor6.get_children():
		if child.name.begins_with("Cassette_"):
			cassettes.append(child)
	cassettes.sort_custom(func(a, b): return a.tape_id > b.tape_id) # take them in REVERSE: 2, 1, 0
	var robot6 = floor6.get_node_or_null("Cerberus")
	var robot5 = generator.get_floor_node(5).get_node_or_null("Cerberus")
	_check(robot6 != null and robot6.current_state != robot6.State.CHASE, "floor 6's robot is not hunting before any tape plays")

	cassettes[0].interact(listener)
	_check(robot6 != null and robot6.current_state == robot6.State.CHASE, "a tape playing on floor 6 brings floor 6's robot")
	_check(robot5 != null and robot5.current_state != robot5.State.CHASE, "floor 5's robot does not hear a tape played on floor 6")
	cassettes[1].interact(listener)
	cassettes[2].interact(listener)
	var floor6_ids: Array = []
	for entry in GameStateManager.collected_tapes:
		if entry["floor"] == 6:
			floor6_ids.append(entry["id"])
	_check(floor6_ids == [0, 1, 2] and GameStateManager.tapes_found == [0, 1, 2],
		"tapes taken as cassettes 2,1,0 still play recordings 1,2,3 in that order: " + str(floor6_ids))
	_check(cassettes.all(func(c): return c.is_queued_for_deletion()), "taken cassettes leave the level")

	print("==================================================")
	if errors > 0:
		print("❌ FAILED with ", errors, " error(s).")
		get_tree().quit(1)
	else:
		print("✅ Progression chain works.")
		get_tree().quit(0)
