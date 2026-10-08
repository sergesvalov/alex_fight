extends Node

# Checks the generated floor against the blueprint (assets/textures/hotel_map.jpg): where each
# room sits along the corridor, which end its door is at, that the WC is at the other end, and
# that the number plate on the door reads the room's own number from the corridor side.
#
# The table below is transcribed from the blueprint, NOT derived from the generator's own
# layout constants - comparing the generator against itself would pass no matter what it built.
# (Room 421 sat mirrored the wrong way for a long time because nothing compared the two.)
#
# Run via: godot --headless tests/test_map_layout.tscn

# room number -> [north edge Z, south edge Z, which end the door is at]
const DOUBLE_ROOMS := {
	401: [-30.0, -20.0, "S"],
	402: [-20.0, -10.0, "S"],
	403: [-10.0, 0.0, "N"],
	405: [0.0, 10.0, "S"],
	406: [10.0, 20.0, "S"],
	408: [20.0, 30.0, "N"],
}
const SINGLE_ROOMS := {
	410: [-20.0, -15.0, "S"],
	411: [-15.0, -10.0, "N"],
	412: [-10.0, -5.0, "S"],
	413: [-5.0, 0.0, "N"],
	415: [0.0, 5.0, "S"],
	416: [5.0, 10.0, "N"],
	417: [10.0, 15.0, "N"],
	420: [15.0, 20.0, "S"],
	421: [20.0, 25.0, "N"],
}

var errors: int = 0

func _ready() -> void:
	print("==================================================")
	print("  AUTOTEST: LEVEL VS BLUEPRINT")
	print("==================================================")

	var generator := Node3D.new()
	generator.set_script(load("res://scripts/levels/hotel_level_generator.gd"))
	add_child(generator)

	var floor_node = generator.find_child("GeneratedFloor_Main", true, false)
	if not floor_node:
		print("❌ FAIL: GeneratedFloor_Main not found")
		get_tree().quit(1)
		return

	var f_scale: float = GlobalConfig.get_floor_scale()
	# Doubles are west of the corridor (their door faces east, +X), singles are east of it.
	_check_rooms(floor_node, "DoubleRoom_", DOUBLE_ROOMS, 1.0, f_scale)
	_check_rooms(floor_node, "SingleRoom_", SINGLE_ROOMS, -1.0, f_scale)

	print("==================================================")
	if errors > 0:
		print("❌ FAILED with ", errors, " mismatch(es) against the blueprint.")
		get_tree().quit(1)
	else:
		print("✅ Level matches the blueprint.")
		get_tree().quit(0)

func _check(ok: bool, label: String) -> void:
	if ok:
		print("✅ PASS: ", label)
	else:
		print("❌ FAIL: ", label)
		errors += 1

func _check_rooms(floor_node: Node, prefix: String, rooms: Dictionary, corridor_dir_x: float, f_scale: float) -> void:
	for num in rooms:
		var north: float = rooms[num][0] * f_scale
		var south: float = rooms[num][1] * f_scale
		var door_end: String = rooms[num][2]
		var mid: float = (north + south) / 2.0

		var room = floor_node.get_node_or_null(prefix + str(num))
		if not room:
			_check(false, str(num) + " exists")
			continue

		var door: Node3D = room.get_node_or_null("RoomDoor")
		var wc_light: Node3D = room.get_node_or_null("WCLight")
		if not door or not wc_light:
			_check(false, str(num) + " has RoomDoor and WCLight")
			continue

		var door_z: float = door.global_position.z
		var wc_z: float = wc_light.global_position.z
		_check(door_z > north and door_z < south,
			"%d door inside its own span %.1f..%.1f (door Z=%.2f)" % [num, north, south, door_z])
		_check((door_z < mid) == (door_end == "N"),
			"%d door at the %s end (door Z=%.2f, room middle %.2f)" % [num, door_end, door_z, mid])
		_check(wc_z > north and wc_z < south and (wc_z < mid) != (door_z < mid),
			"%d WC at the opposite end from the door (WC Z=%.2f)" % [num, wc_z])

		var label: Label3D = door.get_node_or_null("AnimatableBody3D/RoomNumberLabel")
		if not label:
			_check(false, str(num) + " door has a number plate")
			continue
		_check(label.text == str(num), "%d number plate reads \"%s\"" % [num, label.text])
		var plate_basis: Basis = label.global_transform.basis
		_check(plate_basis.z.x * corridor_dir_x > 0.9, "%d number plate faces the corridor" % num)
		_check(plate_basis.determinant() > 0.0, "%d number plate is not mirrored" % num)
