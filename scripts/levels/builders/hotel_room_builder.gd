class_name HotelRoomBuilder
extends RefCounted

static func add_room_door(room_inst: Node3D, node_name: String, local_pos: Vector3, rot_y: float, number: String = "") -> void:
	var door_scene = load("res://entities/props/door.tscn")
	if not door_scene: return
	var door_inst = door_scene.instantiate()
	door_inst.name = node_name
	door_inst.position = local_pos
	door_inst.rotation.y = rot_y

	if number != "":
		var label = door_inst.get_node_or_null("AnimatableBody3D/RoomNumberLabel")
		if label:
			label.text = number
			if room_inst.scale.z < 0.0:
				label.scale.x = -1.0

	room_inst.add_child(door_inst)

static func generate_double_room(generator, parent: Node, f_scale: float, f_num: int, orig_num: int) -> void:
	var layout = HotelConstants.DOUBLE_ROOM_LAYOUT.get(orig_num)
	if not layout: return
	var scene = load("res://scenes/levels/hotel_siberia/blocks/double_room.tscn")
	if not scene: return
	var inst = scene.instantiate()
	var room_idx = orig_num % 100
	var final_num = f_num * 100 + room_idx
	inst.name = "DoubleRoom_" + str(final_num)

	inst.position = Vector3(HotelConstants.DOUBLE_ROOM_BASE_X * f_scale, 0, layout["z"] * f_scale)
	if layout["mirror"]:
		inst.scale.z = -1.0

	add_room_door(inst, "RoomDoor", Vector3(4.8, 0.0, 8.5), PI / 2.0, str(final_num))
	add_room_door(inst, "WCDoor", Vector3(2.35, 0.0, 4.9), 0.0)

	generator._bake_csg(inst)
	parent.add_child(inst)

static func generate_single_room(generator, parent: Node, f_scale: float, f_num: int, orig_num: int) -> void:
	var layout = HotelConstants.SINGLE_ROOM_LAYOUT.get(orig_num)
	if not layout: return
	var scene = load("res://scenes/levels/hotel_siberia/blocks/single_room.tscn")
	if not scene: return
	var inst = scene.instantiate()
	var room_idx = orig_num % 100
	var final_num = f_num * 100 + room_idx
	inst.name = "SingleRoom_" + str(final_num)

	inst.position = Vector3(HotelConstants.SINGLE_ROOM_BASE_X * f_scale, 0, layout["z"] * f_scale)
	if layout["mirror"]:
		inst.scale.z = -1.0

	add_room_door(inst, "RoomDoor", Vector3(-3.75, 0.0, 3.5), -PI / 2.0, str(final_num))
	add_room_door(inst, "WCDoor", Vector3(-2.55, 0.0, 2.5), 0.0)

	generator._bake_csg(inst)
	parent.add_child(inst)
