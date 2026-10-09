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
	for f in range(2, 11):
		var ok := true
		for id in range(3):
			var tape: Dictionary = DialogSystem.get_tape(f, id)
			if tape.get("text", "") == "" or "ЗАГЛУШКА" in tape.get("title", "") or tape == DialogSystem.tape_data.get("damaged"):
				ok = false
		_check(ok, "floor %d has written narration for all three tapes" % f)
	_check(DialogSystem.get_tape(1, 0) == DialogSystem.tape_data.get("damaged"),
		"a floor with no tapes written (the empty floor 1) plays the 'damaged tape' fallback")

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
	var y_step: float = HotelConstants.BASE_FLOOR_TO_FLOOR_HEIGHT * GlobalConfig.get_floor_scale()

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
		var half_x: float = HotelConstants.BUILDING_WIDTH_X / 2.0 * GlobalConfig.get_floor_scale()
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
	var needs: Array = DialogSystem.terminal_entries.filter(func(e): return not e.get("lab", false)).map(func(e): return int(e.get("requires_tapes", -1)))
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

		# The hint: an open door lights the lamp over the door of the room it leads to.
		var hint_from = traps[0]
		var hint_to = traps[hint_from.destination_index(0, GameStateManager.tapes_found.size(), traps.size())]
		var lamps_lit = func(): return traps.filter(func(t): return t.door_lamp != null and t.door_lamp.visible)
		_check(traps.all(func(t): return t.door_lamp != null) and lamps_lit.call().is_empty(), "every room on floor 5 has a lamp over its door, dark at first")
		hint_from._on_door_state_changed(true)
		_check(lamps_lit.call() == [hint_to], "opening a door lights the lamp of the room it really leads to")
		hint_from._on_door_state_changed(false)
		_check(lamps_lit.call().is_empty(), "closing it puts the lamp out")

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
	# The sleeper nearest to the first cassette: where the tapes lie is random, and one further
	# than hearing range from a particular sleeper would make this check a coin toss.
	var robot6: Node = null
	for candidate in floor6.get_children():
		if candidate.name.begins_with("Sleeper_") and (robot6 == null or candidate.global_position.distance_to(cassettes[0].global_position) < robot6.global_position.distance_to(cassettes[0].global_position)):
			robot6 = candidate
	var sleepers: Array = floor6.get_children().filter(func(c): return c.name.begins_with("Sleeper_"))
	_check(sleepers.size() == 4 and floor6.get_node_or_null("Cerberus") == null, "floor 6 has four sleepers and no patrolling robot")
	if robot6:
		robot6.take_damage(1)
	_check(is_instance_valid(robot6) and not robot6.is_queued_for_deletion(), "a shot does nothing to a sleeper while it is asleep")
	var robot5 = generator.get_floor_node(5).get_node_or_null("Cerberus")
	_check(robot6 != null and robot6.state_machine.current_state_name != "INVESTIGATE", "floor 6's robot is not on its way anywhere before any tape plays")

	cassettes[0].interact(listener)
	_check(robot6 != null and robot6.state_machine.current_state_name == "INVESTIGATE" and robot6._noise_position.distance_to(cassettes[0].global_position) < 0.01, "a tape playing on floor 6 sends floor 6's robot to the spot it was played at")
	_check(robot5 != null and robot5.state_machine.current_state_name != "INVESTIGATE", "floor 5's robot does not hear a tape played on floor 6")
	# A patrol robot cannot be destroyed: a hit blinds it for a while, and its own laser puts
	# the player back by the elevator of the robot's floor.
	if robot5:
		robot5.take_damage(1)
		_check(is_instance_valid(robot5) and not robot5.is_queued_for_deletion() and robot5.state_machine.current_state_name == "STUNNED",
			"a shot blinds a patrol robot instead of destroying it")
		robot5.hear_noise(robot5.global_position + Vector3(2, 0, 0))
		_check(robot5.state_machine.current_state_name == "STUNNED", "a blinded robot hears nothing")
		robot5._stun_left = 0.0
		robot5._physics_process(0.016)
		_check(robot5.state_machine.current_state_name == "RETURN", "the blindness passes and the robot goes back to its post")
		var prey := CharacterBody3D.new()
		add_child(prey)
		prey.global_position = robot5.global_position + Vector3(0, 0, 3)
		robot5.player = prey
		robot5.return_to_elevator(prey)
		var floor5_lift: Vector3 = generator.get_floor_node(5).global_position + Vector3(HotelConstants.ELEVATOR_CENTER_X, 0.1, HotelConstants.ELEVATOR_CENTER_Z + 2.0) * GlobalConfig.get_floor_scale()
		_check(prey.global_position.distance_to(floor5_lift) < 0.01, "a patrol robot's laser returns the player to its floor's elevator")
		prey.queue_free()
	# Caught: an awake sleeper within arm's reach puts the player back by the elevator.
	listener.global_position = robot6.global_position + Vector3(0.6, 0.0, 0.0)
	robot6._physics_process(0.016)
	_check(listener.global_position.distance_to(robot6.return_position) < 0.01, "an awake sleeper that reaches the player returns him to the elevator")
	_check(absf(robot6.return_position.x - HotelConstants.ELEVATOR_CENTER_X) < 0.01 and absf(robot6.return_position.y - floor6.global_position.y) < 0.5, "that spot is in front of floor 6's own elevator")
	cassettes[1].interact(listener)
	cassettes[2].interact(listener)
	var floor6_ids: Array = []
	for entry in GameStateManager.collected_tapes:
		if entry["floor"] == 6:
			floor6_ids.append(entry["id"])
	_check(floor6_ids == [0, 1, 2] and GameStateManager.tapes_found == [0, 1, 2],
		"tapes taken as cassettes 2,1,0 still play recordings 1,2,3 in that order: " + str(floor6_ids))
	_check(cassettes.all(func(c): return c.is_queued_for_deletion()), "taken cassettes leave the level")
	_check(GameStateManager.is_floor_unlocked(7) and not GameStateManager.is_floor_unlocked(8), "floor 6's three tapes unlock floor 7, and only floor 7")
	_check(GameStateManager.floor6_sleepers_off, "floor 6's three tapes switch the sleepers off")
	var still_asleep: Node = sleepers[3]
	still_asleep._physics_process(0.016) # one tick: a sleeper already on its way turns back
	still_asleep.hear_noise(still_asleep.global_position + Vector3(2, 0, 0))
	_check(still_asleep.state_machine.current_state_name != "INVESTIGATE", "a switched-off sleeper no longer wakes to sound")

	# --- Floor 7: the blackouts ---
	GameStateManager.current_floor = 7
	var floor7: Node3D = generator.get_floor_node(7)
	var blackout = floor7.get_node_or_null("BlackoutTrap")
	_check(blackout != null and blackout.lights.size() > 40 and blackout.lamp_meshes.size() > 40 and generator.get_floor_node(6).get_node_or_null("BlackoutTrap") == null,
		"floor 7, and only floor 7, has the blackout trap wired to its lights")
	_check(blackout.period_for(0) > blackout.period_for(1) and blackout.period_for(1) > blackout.period_for(2), "each tape found makes the blackouts come sooner")
	var a_light: Light3D = blackout.lights[0]
	var lit_energy: float = a_light.light_energy
	listener.global_position = floor7.global_position + Vector3(1.0, 0.1, 5.0)
	var stood_at: Vector3 = listener.global_position
	blackout._enter(blackout.Phase.DARK)
	_check(is_zero_approx(a_light.light_energy) and not blackout.lamp_meshes[0].visible, "in a blackout the floor's lights and lamp panels go dark")
	listener.velocity = Vector3.ZERO
	blackout._process(1.0)
	_check(listener.global_position == stood_at, "standing still through the dark is safe")
	listener.velocity = Vector3(3.0, 0.0, 0.0)
	blackout._process(0.1)
	_check(listener.global_position.distance_to(blackout.return_position) < 0.01, "moving in the dark puts the player back by the elevator")
	_check(is_equal_approx(a_light.light_energy, lit_energy) and blackout.lamp_meshes[0].visible, "the lights come back afterwards")
	listener.velocity = Vector3.ZERO
	for id in range(3):
		_collect(7, id)
	_check(GameStateManager.floor7_lights_steady and GameStateManager.is_floor_unlocked(8) and not GameStateManager.is_floor_unlocked(9),
		"floor 7's three tapes stop the blackouts and unlock floor 8")
	blackout._enter(blackout.Phase.DARK)
	blackout._process(0.1)
	_check(blackout.phase == blackout.Phase.LIT and is_equal_approx(a_light.light_energy, lit_energy), "after that the trap keeps the lights on")

	# --- Floor 8: name yourself ---
	GameStateManager.current_floor = 8
	listener.name = "Player" # the doorway triggers go by the player node's name
	var floor8: Node3D = generator.get_floor_node(8)
	var name_traps: Array = floor8.get_children().filter(func(c): return c.name.begins_with("NameDoorTrap_"))
	var own_traps: Array = name_traps.filter(func(c): return c.is_own_room)
	_check(name_traps.size() == 15 and own_traps.size() == 1, "floor 8 has a name trigger in each of its 15 rooms, exactly one of them the hero's own")
	var own_room: Node3D = floor8.get_meta("own_room") if floor8.has_meta("own_room") else null
	var plates: Array = []
	for child in floor8.get_children():
		if child.name.begins_with("DoubleRoom_") or child.name.begins_with("SingleRoom_"):
			plates.append(child.get_node("RoomDoor/AnimatableBody3D/RoomNumberLabel").text)
	var unique_plates: Dictionary = {}
	for plate in plates:
		unique_plates[plate] = true
	_check(plates.size() == 15 and unique_plates.size() == 15 and plates.count("НЕЧАЕВ") == 1
		and own_room != null and own_room.get_node("RoomDoor/AnimatableBody3D/RoomNumberLabel").text == "НЕЧАЕВ",
		"its door plates are 15 different surnames, the hero's on his own room")
	var hints8: Array = []
	for child in floor8.get_children():
		if child.name.begins_with("Cassette_"):
			hints8.append(child.location_hint)
	hints8.sort()
	_check(hints8 == ["tape_hint_maintenance", "tape_hint_own_room", "tape_hint_own_room"],
		"one of floor 8's tapes is in the maintenance room, the other two in the hero's room: " + str(hints8))
	var wrong_trap = name_traps.filter(func(c): return not c.is_own_room)[0]
	listener.global_position = wrong_trap.global_position
	wrong_trap._on_body_entered(listener)
	_check(listener.global_position == wrong_trap.global_position, "walking out of a room (no doorway crossed first) does nothing")
	wrong_trap._on_threshold_entered(listener)
	wrong_trap._on_body_entered(listener)
	_check(listener.global_position.distance_to(wrong_trap.return_position) < 0.01, "entering somebody else's room puts the player back by the elevator")
	listener.global_position = own_traps[0].global_position
	own_traps[0]._on_threshold_entered(listener)
	own_traps[0]._on_body_entered(listener)
	_check(listener.global_position == own_traps[0].global_position, "entering his own room does not")
	for id in range(3):
		_collect(8, id)
	_check(GameStateManager.floor8_named and GameStateManager.is_floor_unlocked(2) and not GameStateManager.is_floor_unlocked(9) and not GameStateManager.is_floor_unlocked(1),
		"floor 8's three tapes open every door and unlock floor 2 - not 9, and never floor 1")
	listener.global_position = wrong_trap.global_position
	wrong_trap._on_threshold_entered(listener)
	wrong_trap._on_body_entered(listener)
	_check(listener.global_position == wrong_trap.global_position, "after that any room can be entered")

	# --- Floor 2: "that night" - sleepers and blackouts together ---
	var floor2: Node3D = generator.get_floor_node(2)
	var sleepers2: Array = floor2.get_children().filter(func(c): return c.name.begins_with("Sleeper_"))
	var blackout2 = floor2.get_node_or_null("BlackoutTrap")
	_check(sleepers2.size() == 4 and blackout2 != null and blackout2.floor_num == 2, "floor 2 has both the sleepers and the blackouts")
	GameStateManager.current_floor = 2
	generator._set_lit_floor(2)
	sleepers2[0].hear_noise(sleepers2[0].global_position + Vector3(3, 0, 0))
	_check(sleepers2[0].state_machine.current_state_name == "INVESTIGATE", "floor 2's sleepers are live even though floor 6's were switched off")
	blackout2._enter(blackout2.Phase.DARK)
	blackout2._process(0.1)
	_check(blackout2.phase == blackout2.Phase.DARK, "floor 2's blackouts run even though floor 7's were stopped")
	for id in range(3):
		_collect(2, id)
	blackout2._process(0.1)
	_check(GameStateManager.floor2_done and blackout2.phase == blackout2.Phase.LIT, "floor 2's three tapes end that night: the lights stay on")
	sleepers2[1].hear_noise(sleepers2[1].global_position + Vector3(3, 0, 0))
	_check(sleepers2[1].state_machine.current_state_name != "INVESTIGATE", "...and its sleepers no longer wake")
	_check(GameStateManager.is_floor_unlocked(9) and not GameStateManager.is_floor_unlocked(10), "floor 2's three tapes unlock floor 9")

	# --- Floor 9: the sweeping units ---
	GameStateManager.current_floor = 9
	var floor9: Node3D = generator.get_floor_node(9)
	var sweep = floor9.get_node_or_null("SweepCameraTrap")
	_check(sweep != null and generator.get_floor_node(8).get_node_or_null("SweepCameraTrap") == null, "floor 9, and only floor 9, has the sweeping units")
	_check(sweep.active_count() == 2, "two units run at first")
	var sleepers9: Array = floor9.get_children().filter(func(c): return c.name.begins_with("Sleeper_"))
	_check(sleepers9.size() == 2 and sleepers9.all(func(s): return s.off_flag == &"floor9_cameras_off"),
		"floor 9 also has two sleepers, switched off by its own tapes")
	var bar_at: float = sweep.bar_z(0, sweep._time)
	listener.global_position = floor9.global_position + Vector3(1.0, 0.1, bar_at)
	sweep._process(0.0)
	_check(listener.global_position.distance_to(sweep.return_position) < 0.01, "standing in a bar of light puts the player back by the elevator")
	sweep._grace = 0.0
	listener.global_position = floor9.global_position + Vector3(-8.0, 0.1, sweep.bar_z(0, sweep._time))
	var in_room: Vector3 = listener.global_position
	sweep._process(0.0)
	_check(listener.global_position == in_room, "the same spot along the floor but inside a room is safe - the bars only cover the corridor")
	_collect(9, 0)
	_check(sweep.active_count() == 3, "each tape found switches on one more unit")
	_collect(9, 1)
	_collect(9, 2)
	_check(GameStateManager.floor9_cameras_off and GameStateManager.is_floor_unlocked(10), "floor 9's three tapes stop the units and unlock floor 10")
	listener.global_position = floor9.global_position + Vector3(1.0, 0.1, sweep.bar_z(0, sweep._time))
	var after_off: Vector3 = listener.global_position
	sweep._process(0.0)
	_check(listener.global_position == after_off, "after that the corridor is safe")
	_check(_routes() == [4, 2, 3, 4, 5, 6, 7, 8, 9, 10], "the elevator now reaches every furnished floor: " + str(_routes()))

	# --- Floor 10: the edge ---
	GameStateManager.current_floor = 10
	var floor10: Node3D = generator.get_floor_node(10)
	var edge = floor10.get_node_or_null("EdgeWallTrap")
	_check(edge != null and floor9.get_node_or_null("EdgeWallTrap") == null, "floor 10, and only floor 10, has the edge")
	var blackout10 = floor10.get_node_or_null("BlackoutTrap")
	_check(blackout10 != null and blackout10.floor_num == 10 and blackout10.off_flag == &"floor10_edge_stopped",
		"floor 10 also has the blackouts, stopped by its own tapes")
	if blackout10:
		listener.global_position = floor10.global_position + Vector3(1.0, 0.1, -20.0)
		edge._process(0.0)
		var dark_z: float = edge.edge_z
		blackout10.phase = blackout10.Phase.DARK
		edge._process(5.0)
		_check(is_equal_approx(edge.edge_z, dark_z), "the edge stands still while the lights are out")
		blackout10.phase = blackout10.Phase.LIT
	listener.global_position = floor10.global_position + Vector3(1.0, 0.1, -20.0)
	edge._process(0.0)
	var start_z: float = edge.edge_z
	edge._process(10.0)
	_check(edge.edge_z < start_z and is_equal_approx(start_z - edge.edge_z, 10.0 * edge.speed_for(0)), "the edge creeps north at a steady pace")
	_check(edge.speed_for(0) < edge.speed_for(1) and edge.speed_for(1) < edge.speed_for(2), "each tape found makes it faster")
	edge._process(1000.0)
	_check(is_equal_approx(edge.edge_z, edge.NORTH_LIMIT_Z) and edge.NORTH_LIMIT_Z > HotelConstants.ELEVATOR_CENTER_Z + 3.0, "it stops short of the elevator")
	_collect(10, 0)
	edge._process(0.0)
	_check(is_equal_approx(edge.edge_z, edge.SOUTH_Z), "a tape found throws it back to the south end")
	listener.global_position = floor10.global_position + Vector3(1.0, 0.1, edge.edge_z - 0.1)
	edge._process(0.0)
	_check(listener.global_position.distance_to(edge.return_position) < 0.01 and is_equal_approx(edge.edge_z, edge.SOUTH_Z),
		"touching the edge puts the player back by the elevator and resets it")
	_collect(10, 1)
	_collect(10, 2)
	edge._process(1.0)
	_check(GameStateManager.floor10_edge_stopped and not edge._wall.visible, "floor 10's three tapes stop the edge for good")
	_check(not GameStateManager.is_floor_unlocked(1), "floor 10's tapes do not open floor 1 - that takes the code on the roof")

	# --- The roof: stair exits, the lift machine room, the code that opens floor 1 ---
	_check(GameStateManager.is_floor_unlocked(11), "floor 10's three tapes open the roof (the stair gates' \"floor 11\")")
	var roof: Node3D = generator.get_floor_node(11)
	var roof_parts: Array = roof.get_children().map(func(c): return String(c.name))
	_check(["Parapet_West", "Parapet_East", "Parapet_North", "Parapet_South"].all(func(p): return roof_parts.has(p)), "the roof has its parapet on all four sides")
	_check(["NorthExitDoor", "NorthExitGate", "NorthExit_Cap", "SouthExitDoor", "SouthExitGate", "SouthExit_Cap"].all(func(p): return roof_parts.has(p)),
		"both stairwells come out through a bulkhead with a door and a floor gate")
	_check(roof.get_node("NorthExitGate").floor_num == 11 and roof.get_node("SouthExitGate").floor_num == 11, "those gates treat the roof as floor 11")
	_check(["Roof_Main", "Roof_SW", "Roof_SE"].all(func(p): return roof_parts.has(p))
		and roof.get_node("Roof_Main").position.z + roof.get_node("Roof_Main/CollisionShape3D").shape.size.z / 2.0 < 27.6,
		"the roof slab is cut open over the south stairs' top flight")
	_check(["MachineRoomDoor", "MachineRoom_Cap", "LiftCodePlate"].all(func(p): return roof_parts.has(p)), "the lift machine room is there, with a door and the code plate")
	var plate = roof.get_node("LiftCodePlate")
	_check(GameStateManager.lift_code.length() == 4 and GameStateManager.lift_code.is_valid_int() and plate.get_node("Text").text.contains(GameStateManager.lift_code),
		"the plate shows the game's four-digit lift code: " + GameStateManager.lift_code)
	_check(ElevatorController.route_floor(1) == 4, "before the code is read, the floor 1 button still leads to floor 4")
	plate.interact(listener)
	_check(GameStateManager.lobby_unlocked and ElevatorController.route_floor(1) == 1, "reading the code sends the elevator to floor 1")
	_check(_routes() == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "every button of the elevator now goes where it says: " + str(_routes()))

	# --- Floor 1: the lobby ---
	var lobby: Node3D = generator.get_floor_node(1)
	var lobby_parts: Array = lobby.get_children().map(func(c): return String(c.name))
	_check(["Lobby_WestWall_N", "Lobby_WestWall_S", "Lobby_Corridor_N", "Lobby_Corridor_S", "Lobby_EastWall", "Reception_Desk", "Aquarium",
		"LowerLiftPanel", "LowerLift_DoorL", "Entrance_DoorL", "TurretKillZone", "SouthStairsDoor", "SouthStairsRampA"].all(func(p): return lobby_parts.has(p)),
		"the lobby has its hall walls, reception, aquarium, second lift, entrance with turrets and the second staircase")
	var desk: Node3D = lobby.get_node("Reception_Desk")
	var tank: Node3D = lobby.get_node("Aquarium")
	var lift2: Node3D = lobby.get_node("LowerLiftPanel")
	var zone: Node3D = lobby.get_node("TurretKillZone")
	_check(absf(desk.position.z) < 0.1 and absf(zone.position.z) < 0.1 and zone.position.x < HotelConstants.CORRIDOR_WEST_EDGE_X and desk.position.x > 0.0,
		"the corridor to the entrance runs west, straight across the hall from the reception")
	_check(tank.position.x > desk.position.x and tank.position.z > 2.6 and tank.position.z < 8.0 and tank.get_node_or_null("Creature") != null,
		"the aquarium stands against the east wall right next to the reception, with something in it")
	_check(lift2.position.x > desk.position.x and absf(lift2.position.z) < 1.5, "the second lift is in the east wall behind the desk")
	GameStateManager.lobby_unlocked = false
	lift2.interact(listener)
	_check(not GameStateManager.lower_lift_called, "without the roof code the second lift's panel does nothing")
	GameStateManager.lobby_unlocked = true
	lift2.go_to(-1, listener)
	_check(GameStateManager.lower_lift_called, "with the code the lift goes")
	listener.global_position = zone.global_position
	zone._on_turret_zone_entered(listener)
	_check(listener.global_position.distance_to(zone.return_position) < 0.01
		and absf(zone.return_position.x - HotelConstants.ELEVATOR_CENTER_X) < 0.01,
		"the entrance turrets put the player back by the lobby's elevator")

	# --- The laboratory: two levels under the lobby, three consoles, the way out ---
	var lab_docs: Array = DialogSystem.terminal_entries.filter(func(e): return e.get("lab", false))
	_check(lab_docs.size() == 3 and lab_docs.any(func(e): return "якоря" in e["text"]), "the lab has three documents of its own, one of which says what the Cerberus units are for")
	_check(["Lab_Floor1", "Lab_Floor2", "Lab1_Desk_0_0", "Lab1_Crate_8", "CrtTerminal", "Lab1_LiftPanel", "Lab2_LiftPanel",
		"Lab2_Tank_0_N", "Lab2_Tank_3_S", "Lab2_Installation", "Lab2_Console_1", "Lab2_Console_3"].all(func(p): return lobby.get_node_or_null(p) != null),
		"both lab levels are built: desks, crates and a terminal above; tanks, the installation and three consoles below")
	lift2.go_to(-1, listener)
	_check(absf(listener.global_position.y - (lobby.global_position.y - 4.5)) < 0.3 and GameStateManager.lab_reached, "the lobby's panel, given the code, takes the player down to level -1")
	lobby.get_node("Lab1_LiftPanel").go_to(-2, listener)
	_check(absf(listener.global_position.y - (lobby.global_position.y - 9.0)) < 0.3, "level -1's panel takes him down to level -2")
	_check(lobby.get_node("Lab2_LiftPanel").here == -2 and lobby.get_node("Lab1_LiftPanel").here == -1 and lift2.here == 1 and lift2.stops.size() == 3, "every stop has one panel that knows all three stops")
	lobby.get_node("Lab2_LiftPanel").go_to(1, listener)
	_check(absf(listener.global_position.y - lobby.global_position.y) < 0.3, "and level -2's panel brings him straight back to the lobby")
	lobby.get_node("Lab2_Console_2").interact(listener)
	_check(GameStateManager.lab_consoles_off == 0, "the consoles do not work out of order")
	lobby.get_node("Lab2_Console_1").interact(listener)
	listener.global_position = zone.global_position
	var at_door: Vector3 = listener.global_position
	zone._on_turret_zone_entered(listener)
	_check(GameStateManager.lab_consoles_off == 1 and listener.global_position == at_door and GameStateManager.current_state != GameStateManager.GameState.WIN,
		"console 1 switches the lobby turrets off - but the door leads nowhere yet")
	lobby.get_node("Lab2_Console_2").interact(listener)
	lobby.get_node("Lab2_Console_3").interact(listener)
	lobby.get_node("Lab2_Installation")._process(0.016)
	_check(GameStateManager.lab_consoles_off == 3 and not lobby.get_node("Lab2_Installation/Column").visible, "console 3 stops the installation: the column goes dark")
	zone._on_turret_zone_entered(listener)
	_check(GameStateManager.current_state == GameStateManager.GameState.WIN, "after that, walking out through the main entrance ends the game")


	print("==================================================")
	if errors > 0:
		print("❌ FAILED with ", errors, " error(s).")
		get_tree().quit(1)
	else:
		print("✅ Progression chain works.")
		get_tree().quit(0)
