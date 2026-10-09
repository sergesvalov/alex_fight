extends Node

# Checks the wake-up room (wake_up_room.gd) - the tutorial a new game starts in:
#   - a new game locks the starting room's door, takes the pistol out of the hero's hands and
#     puts it on the bathroom's washbasin
#   - the room's steps follow what has actually been done: bathroom door, pistol, tape, lock, out
#   - the lock gives way to shots and to nothing else, and the door then opens like any other
#   - opening it ends the room for good; a continued game never gets it
#
# Run via: godot --headless tests/test_wake_up_room.tscn

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

func _ready() -> void:
	print("==================================================")
	print("  AUTOTEST: WAKE-UP ROOM")
	print("==================================================")
	SaveManager.save_path = "user://test_savegame.json"
	SaveManager.new_game()

	var generator := _build()
	var floor4: Node3D = generator.get_floor_node(4)
	var wake = floor4.get_node_or_null("WakeUpRoom")
	_check(wake != null, "a new game has the wake-up room on floor 4")
	if wake == null:
		_finish()
		return
	for f in [3, 5]:
		_check(generator.get_floor_node(f).get_node_or_null("WakeUpRoom") == null, "floor " + str(f) + " has none")

	var room: Node3D = wake.room
	var room_door = room.get_node("RoomDoor/AnimatableBody3D")
	var wc_door = room.get_node("WCDoor/AnimatableBody3D")
	var lock = room_door.get_node_or_null("WakeUpLock")
	var pickup = wake.get_node_or_null("PistolPickup")
	var cassette = floor4.get_node_or_null("Cassette_0")
	var light: Light3D = room.get_node("MainRoomLight")
	_check(cassette != null and room.get_node("Wardrobe").global_position.distance_to(cassette.global_position) < 1.5,
		"it is the room with the first tape in its wardrobe")
	_check(room_door.locked and lock != null and pickup != null, "its door is locked, with a lock on it and the pistol lying inside")
	_check(light.light_energy > 0.0 and room.get_node("MainRoomLightMesh").visible, "the room's lamp is on from the start")

	# The bathroom is the room's north-west corner (single_room.tscn: WCEastWall, WCSouthWall).
	var pistol_in_room: Vector3 = room.global_transform.affine_inverse() * pickup.global_position
	_check(pistol_in_room.x > -3.65 and pistol_in_room.x < -1.45 and pistol_in_room.z > 0.2 and pistol_in_room.z < 2.4,
		"the pistol is in the bathroom")

	# --- The hero himself ---
	var player = load("res://entities/player/player.tscn").instantiate()
	add_child(player)
	wake.place_player(player)
	var player_in_room: Vector3 = room.global_transform.affine_inverse() * player.global_position
	var looking: Vector3 = room.global_basis.inverse() * (-player.global_basis.z)
	_check(player_in_room.x > 1.5 and player_in_room.x < 3.7 and player_in_room.z > 2.6 and player_in_room.z < 3.6,
		"he wakes beside the bed")
	_check(looking.z > 0.9, "facing it and the wall behind it, away from everything else")
	var pistol = player.get_node("CameraRig/Camera3D/WeaponHolder/LaserPistol")
	player.weapon.shoot()
	_check(not player.weapon.armed and not pistol.get_parent().visible and pistol.heat == 0.0, "with empty hands: shooting does nothing")

	# --- Step by step ---
	await get_tree().process_frame
	_check(wake.stage == wake.Stage.WC_DOOR, "first comes the bathroom door")
	room_door.interact(player)
	await get_tree().create_timer(0.7).timeout
	_check(not room_door.is_open, "the door to the corridor only rattles")

	wc_door.interact(player)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(wake.stage == wake.Stage.PISTOL, "the bathroom door open: the pistol is next")

	pickup.interact(player)
	await get_tree().create_timer(0.8).timeout
	_check(player.weapon.armed and pistol.get_parent().visible, "picking it up arms him")
	_check(wake.stage == wake.Stage.TAPE, "the tape is next")

	for i in range(lock.HITS_TO_BREAK - 1):
		lock.take_damage(20)
	_check(room_door.locked and not lock.is_broken, "the lock holds until its last hit")
	cassette.interact(player)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(wake.stage == wake.Stage.LOCK, "the tape taken: the lock is next")
	lock.take_damage(20)
	await get_tree().process_frame
	_check(not room_door.locked and wake.stage == wake.Stage.EXIT, "the last hit breaks it")
	_check(not GameStateManager.wake_up_done, "the room is not done until the door is open")

	room_door.interact(player)
	await get_tree().create_timer(0.7).timeout
	_check(room_door.is_open, "the door opens like any other")
	_check(GameStateManager.wake_up_done and floor4.get_node_or_null("WakeUpRoom") == null, "and the room is over")
	_check(room_door.get_node_or_null("WakeUpLock") == null, "the lock is gone")

	# --- A continued game ---
	SaveManager.save_game()
	player.free()
	generator.free()
	GameStateManager.wake_up_done = false # even a save made inside the room does not bring it back
	SaveManager.save_game()
	_check(SaveManager.load_game(), "the save loads")
	var resumed := _build()
	var resumed_floor: Node3D = resumed.get_floor_node(4)
	var any_locked: bool = false
	for child in resumed_floor.get_children():
		if child.name.begins_with("SingleRoom_") and child.get_node("RoomDoor/AnimatableBody3D").locked:
			any_locked = true
	_check(resumed_floor.get_node_or_null("WakeUpRoom") == null and not any_locked, "a continued game has no wake-up room and no locked door")
	_check(GameStateManager.wake_up_done, "and counts it as done")

	_finish()

func _finish() -> void:
	SaveManager.active = false
	SaveManager.resuming = false
	SaveManager.delete_save()
	print("==================================================")
	if errors > 0:
		print("❌ FAILED with ", errors, " error(s).")
		get_tree().quit(1)
	else:
		print("✅ The wake-up room works.")
		get_tree().quit(0)
