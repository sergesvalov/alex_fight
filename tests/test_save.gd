extends Node

# Checks saving and continuing:
#   - the same seed builds the same hotel (tape spots, floor 5's sealed room, floor 8's name
#     plates, the lift code) - which is what lets a save store progress and not the level
#   - a save written mid-game brings back every piece of progress after the state was wiped
#   - a continued game's level has the already-taken cassettes removed and the player by the
#     elevator of the floor the save was made on
#   - finishing the game deletes the save; an unreadable save is treated as no save
#
# Run via: godot --headless tests/test_save.tscn

var errors: int = 0

func _check(ok: bool, label: String) -> void:
	if ok:
		print("✅ PASS: ", label)
	else:
		print("❌ FAIL: ", label)
		errors += 1

func _build() -> Node3D:
	var generator := Node3D.new()
	generator.set_script(load("res://scripts/levels/hotel_level_generator.gd"))
	add_child(generator)
	return generator

# Everything the seed is supposed to decide, as one comparable value.
func _fingerprint(generator: Node3D) -> Array:
	var out: Array = [GameStateManager.lift_code]
	for f in range(2, 11):
		var floor_node: Node3D = generator.get_floor_node(f)
		for child in floor_node.get_children():
			if child.name.begins_with("Cassette_"):
				out.append([f, child.tape_id, child.position.snapped(Vector3.ONE * 0.01)])
	out.append(String(generator.get_floor_node(5).get_meta("sealed_room").name))
	for child in generator.get_floor_node(8).get_children():
		if child.name.begins_with("DoubleRoom_") or child.name.begins_with("SingleRoom_"):
			out.append(child.get_node("RoomDoor/AnimatableBody3D/RoomNumberLabel").text)
	return out

func _ready() -> void:
	print("==================================================")
	print("  AUTOTEST: SAVING AND CONTINUING")
	print("==================================================")
	SaveManager.save_path = "user://test_savegame.json"
	SaveManager.delete_save()
	_check(not SaveManager.has_save() and SaveManager.summary().is_empty(), "with no save file there is nothing to continue")

	# --- The seed decides the hotel ---
	SaveManager.new_game()
	var seed_a: int = GameStateManager.world_seed
	var first := _build()
	var print_a: Array = _fingerprint(first)
	first.free()
	var second := _build()
	_check(_fingerprint(second) == print_a, "the same seed builds the same hotel: tapes, sealed room, name plates, lift code")
	second.free()
	GameStateManager.world_seed = seed_a + 1
	var third := _build()
	_check(_fingerprint(third) != print_a, "a different seed builds a different one")
	third.free()

	# --- Progress, saved and brought back ---
	GameStateManager.world_seed = seed_a
	var generator := _build()
	var floor4: Node3D = generator.get_floor_node(4)
	var taken_ids: Array = []
	for child in floor4.get_children():
		if child.name.begins_with("Cassette_") and taken_ids.size() < 2:
			taken_ids.append(child.tape_id)
			child.interact(null)
	GameStateManager.unlock_floor(3)
	GameStateManager.unlock_floor(5)
	GameStateManager.current_floor = 5
	GameStateManager.floor3_corridor_unlocked = true
	GameStateManager.secret_portal_active = true
	GameStateManager.secret_portal_target = Vector3(1.5, -4.0, 2.25)
	GameStateManager.lab_consoles_off = 2
	DialogSystem._alex_lines_fired["floor4_start"] = true
	SaveManager.save_game()
	var summary: Dictionary = SaveManager.summary()
	_check(SaveManager.has_save() and summary.get("floor") == 5 and summary.get("tapes") == 2, "the save reports where the game stands: " + str(summary))
	var saved_tapes: Array = GameStateManager.collected_tapes.duplicate(true)
	generator.free()

	SaveManager.new_game() # wipes the state (and, being a new game, the file)...
	_check(GameStateManager.collected_tapes.is_empty() and GameStateManager.current_floor == 4 and not GameStateManager.floor3_corridor_unlocked
		and GameStateManager.taken_cassettes.is_empty() and not SaveManager.has_save(), "a new game starts from nothing and removes the old save")
	# ...so put the saved file back the way a second launch would find it.
	GameStateManager.world_seed = seed_a
	for id in range(2):
		GameStateManager.taken_cassettes.append([4, taken_ids[id]])
		GameStateManager.collected_tapes.append(saved_tapes[id])
	GameStateManager.unlock_floor(3)
	GameStateManager.unlock_floor(5)
	GameStateManager.current_floor = 5
	GameStateManager.floor3_corridor_unlocked = true
	GameStateManager.secret_portal_active = true
	GameStateManager.secret_portal_target = Vector3(1.5, -4.0, 2.25)
	GameStateManager.lab_consoles_off = 2
	DialogSystem._alex_lines_fired["floor4_start"] = true
	SaveManager.save_game()
	SaveManager.active = false
	for field in SaveManager.SAVED_FIELDS: # the state a fresh launch has before loading
		SaveManager._apply(field, SaveManager._defaults[field])
	DialogSystem._alex_lines_fired.clear()

	_check(SaveManager.load_game(), "the save loads")
	_check(GameStateManager.world_seed == seed_a and GameStateManager.current_floor == 5 and GameStateManager.collected_tapes == saved_tapes
		and GameStateManager.taken_cassettes.size() == 2 and GameStateManager.is_floor_unlocked(3) and GameStateManager.is_floor_unlocked(5)
		and not GameStateManager.is_floor_unlocked(6) and GameStateManager.floor3_corridor_unlocked and GameStateManager.secret_portal_active
		and GameStateManager.secret_portal_target.is_equal_approx(Vector3(1.5, -4.0, 2.25)) and GameStateManager.lab_consoles_off == 2
		and DialogSystem._alex_lines_fired.has("floor4_start"),
		"loading brings back the seed, floor, tapes, unlocked floors, trap flags, the secret door and the lines already said")
	_check(GameStateManager.collected_tapes is Array[Dictionary] and typeof(GameStateManager.current_floor) == TYPE_INT
		and typeof(GameStateManager.collected_tapes[0]["id"]) == TYPE_INT, "loaded values have their proper types back, not JSON's floats")

	# --- The continued game's level ---
	var player := CharacterBody3D.new()
	player.name = "Player"
	add_child(player)
	get_tree().current_scene = self # _move_player() looks the player up under the current scene
	var continued := _build()
	var left: Array = []
	for child in continued.get_floor_node(4).get_children():
		if child.name.begins_with("Cassette_"):
			left.append(child.tape_id)
	_check(left.size() == 1 and not taken_ids.has(left[0]), "the two cassettes already taken are gone from the rebuilt floor, the third is still there")
	_check(GameStateManager.current_floor == 5, "rebuilding the level does not put a continued game back on floor 4")
	await get_tree().process_frame # _move_player() is deferred
	var floor5_y: float = continued.get_floor_node(5).global_position.y
	_check(absf(player.global_position.y - floor5_y) < 0.5 and absf(player.global_position.x - HotelConstants.ELEVATOR_CENTER_X) < 0.01,
		"the player continues by floor 5's elevator: " + str(player.global_position))

	# --- The end, and a broken file ---
	SaveManager.active = true
	SaveManager.save_game()
	GameStateManager.change_state(GameStateManager.GameState.WIN)
	_check(not SaveManager.has_save() and not SaveManager.active, "finishing the game deletes the save")
	var broken := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	broken.store_string("{ not a save")
	broken.close()
	_check(not SaveManager.has_save() and not SaveManager.load_game(), "an unreadable save file counts as no save")
	SaveManager.delete_save()

	print("==================================================")
	if errors > 0:
		print("❌ FAILED with ", errors, " error(s).")
		get_tree().quit(1)
	else:
		print("✅ Saving and continuing work.")
		get_tree().quit(0)
