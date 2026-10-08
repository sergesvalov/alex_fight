class_name HotelTrapBuilder
extends RefCounted

static func make_doorway_trigger(room: Node3D, is_double: bool, trigger_script: Script) -> Area3D:
	var doorway: Vector3 = Vector3(4.8, 1.1, 8.5) if is_double else Vector3(-3.75, 1.1, 3.5)
	var inward_x: float = -1.0 if is_double else 1.0

	var trigger = Area3D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = 1 # Player layer
	trigger.set_script(trigger_script)
	trigger.position = room.transform * (doorway + Vector3(inward_x * 0.65, 0, 0))
	var inner_shape = BoxShape3D.new()
	inner_shape.size = Vector3(0.6, 2.2, 1.2)
	var inner_coll = CollisionShape3D.new()
	inner_coll.shape = inner_shape
	trigger.add_child(inner_coll)

	var threshold = Area3D.new()
	threshold.name = "Threshold"
	threshold.collision_layer = 0
	threshold.collision_mask = 1
	threshold.position = Vector3(-inward_x * 0.65, 0, 0)
	var threshold_shape = BoxShape3D.new()
	threshold_shape.size = Vector3(0.5, 2.2, 1.0)
	var threshold_coll = CollisionShape3D.new()
	threshold_coll.shape = threshold_shape
	threshold.add_child(threshold_coll)
	trigger.add_child(threshold)
	return trigger

static func add_name_doors(generator, parent: Node3D, f_num: int, f_scale: float) -> void:
	var trap_script = load("res://scripts/levels/blocks/name_door_trap.gd")
	var nums: Array = HotelConstants.DOUBLE_ROOM_LAYOUT.keys() + HotelConstants.SINGLE_ROOM_LAYOUT.keys()
	nums.sort()
	var own_num: int = nums[randi() % nums.size()]
	var other_names: Array = Array(UIStrings.get_string("floor8_other_names").split(",", false))
	other_names.shuffle()
	for num in nums:
		var is_double: bool = HotelConstants.DOUBLE_ROOM_LAYOUT.has(num)
		var room: Node3D = parent.get_node_or_null(("DoubleRoom_" if is_double else "SingleRoom_") + str(f_num * 100 + num % 100))
		if not room:
			continue
		var is_own: bool = num == own_num
		var label: Label3D = room.get_node_or_null("RoomDoor/AnimatableBody3D/RoomNumberLabel")
		if label:
			label.text = UIStrings.get_string("floor8_own_name") if is_own else str(other_names.pop_back())
			label.font_size = 36
		var trap: Area3D = make_doorway_trigger(room, is_double, trap_script)
		trap.name = "NameDoorTrap_" + str(num)
		trap.is_own_room = is_own
		trap.return_position = parent.global_position + Vector3(HotelConstants.ELEVATOR_CENTER_X * f_scale, 0.1, (HotelConstants.ELEVATOR_CENTER_Z + 2.0) * f_scale)
		parent.add_child(trap)
		if is_own:
			parent.set_meta("own_room", room)

static func add_room_shuffle_trap(generator, parent: Node3D, f_num: int) -> void:
	var trap_script = load("res://scripts/levels/blocks/room_shuffle_trap.gd")
	var traps: Array = []
	var nums: Array = HotelConstants.DOUBLE_ROOM_LAYOUT.keys() + HotelConstants.SINGLE_ROOM_LAYOUT.keys()
	nums.sort()
	for num in nums:
		var is_double: bool = HotelConstants.DOUBLE_ROOM_LAYOUT.has(num)
		var room: Node3D = parent.get_node_or_null(("DoubleRoom_" if is_double else "SingleRoom_") + str(f_num * 100 + num % 100))
		if not room:
			continue
		var trap: Area3D = make_doorway_trigger(room, is_double, trap_script)
		trap.name = "RoomShuffleTrap_" + str(num)
		trap.room = room
		trap.traps = traps
		trap.index = traps.size()
		trap.inside_local = Vector3(2.5, 0.1, 7.5) if is_double else Vector3(-1.5, 0.1, 3.6)
		trap.facing_yaw = PI / 2.0 if is_double else -PI / 2.0

		traps.append(trap)
		parent.add_child(trap)

	if traps.is_empty():
		return
	var sealed_room: Node3D = traps[randi() % traps.size()].room
	parent.set_meta("sealed_room", sealed_room)
	generator._sealed_room_door = sealed_room.get_node_or_null("RoomDoor/AnimatableBody3D")
	if generator._sealed_room_door:
		generator._sealed_room_door.locked_from_corridor = not GameStateManager.floor5_rooms_unlocked

static func add_blackout_trap(parent: Node3D, f_num: int, lights: Array, f_scale: float) -> void:
	var trap = Node3D.new()
	trap.name = "BlackoutTrap"
	trap.set_script(load("res://scripts/levels/blocks/blackout_trap.gd"))
	trap.floor_num = f_num
	trap.off_flag = &"floor7_lights_steady" if f_num == 7 else &"floor2_done"
	trap.lights = lights
	trap.lamp_meshes = parent.find_children("*LightMesh", "MeshInstance3D", true, false)
	trap.return_position = parent.global_position + Vector3(HotelConstants.ELEVATOR_CENTER_X * f_scale, 0.1, (HotelConstants.ELEVATOR_CENTER_Z + 2.0) * f_scale)
	parent.add_child(trap)

static func add_floor_wide_trap(generator, parent: Node3D, f_num: int, f_scale: float) -> void:
	var trap = Node3D.new()
	if f_num == 9:
		trap.name = "SweepCameraTrap"
		trap.set_script(load("res://scripts/levels/blocks/sweep_camera_trap.gd"))
		trap.corridor_x_min = HotelConstants.CORRIDOR_WEST_EDGE_X * f_scale
		trap.corridor_x_max = HotelConstants.CORRIDOR_EAST_EDGE_X * f_scale
	else:
		trap.name = "EdgeWallTrap"
		trap.set_script(load("res://scripts/levels/blocks/edge_wall_trap.gd"))
		trap.width = HotelConstants.BUILDING_WIDTH_X * f_scale
		trap.height = generator.corridor_height * f_scale
	trap.floor_num = f_num
	trap.return_position = parent.global_position + Vector3(HotelConstants.ELEVATOR_CENTER_X * f_scale, 0.1, (HotelConstants.ELEVATOR_CENTER_Z + 2.0) * f_scale)
	parent.add_child(trap)

static func add_floor3_corridor_barrier(generator, parent: Node, f_scale: float) -> void:
	var barrier = StaticBody3D.new()
	barrier.name = "CorridorBarrier"
	barrier.set_script(load("res://scripts/levels/blocks/corridor_barrier.gd"))
	var shape = BoxShape3D.new()
	shape.size = Vector3((HotelConstants.CORRIDOR_EAST_EDGE_X - HotelConstants.CORRIDOR_WEST_EDGE_X) * f_scale, generator.corridor_height * f_scale, 0.5 * f_scale)
	var coll = CollisionShape3D.new()
	coll.shape = shape
	coll.position.y = generator.corridor_height * f_scale / 2.0
	barrier.add_child(coll)
	# Right after single room 411 / double 402, halfway between them and the elevator.
	barrier.position = Vector3(HotelConstants.NORTH_STAIRS_CENTER_X * f_scale, 0.0, -15.0 * f_scale)
	parent.add_child(barrier)
