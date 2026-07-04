class_name HotelDoorGenerator
extends RefCounted

const DOOR_SCENE = preload("res://entities/props/door.tscn")
const STAIR_DOOR_SCENE = preload("res://entities/props/stair_door.tscn")
const ELEVATOR_DOOR_SCENE = preload("res://entities/props/elevator_door.tscn")

# ---------------------------------------------------------
# Room Doors (Main and WC)
# ---------------------------------------------------------
static func create_room_main_door(parent: Node3D, pos: Vector3, is_left: bool) -> Node3D:
	var door = DOOR_SCENE.instantiate()
	door.name = "MainDoor"
	parent.add_child(door)
	door.position = pos
	
	if is_left:
		# Double room (left side) door is on the right wall (WallE) swinging outwards (-Z)
		door.basis = Basis(Vector3(0, 1, 0), PI/2)
	else:
		# Single room (right side) door is on the left wall (WallW) swinging outwards (+Z)
		door.basis = Basis(Vector3(0, 1, 0), -PI/2)
	
	return door

static func create_room_wc_door(parent: Node3D, pos: Vector3, is_left: bool) -> Node3D:
	var door = DOOR_SCENE.instantiate()
	door.name = "WCDoor"
	parent.add_child(door)
	door.position = pos
	
	if is_left:
		# Double room WC door
		door.basis = Basis(Vector3(0, 1, 0), PI/2)
	else:
		# Single room WC door
		door.basis = Basis() # Identity
	
	return door

# ---------------------------------------------------------
# Corridor Doors (Stairwell and Elevator)
# ---------------------------------------------------------
static func create_stairwell_door(parent: Node3D, pos: Vector3, is_north: bool = true) -> Node3D:
	var door = STAIR_DOOR_SCENE.instantiate()
	door.name = "StairwellDoor" if is_north else "StairwellDoor_South"
	parent.add_child(door)
	door.position = pos
	# stair_door.tscn is built such that it swings correctly if placed at Z center.
	# The rotation is handled inside the stairwell setup if needed, but normally it just sits at pos.
	return door

static func create_elevator_door(parent: Node3D, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var door = ELEVATOR_DOOR_SCENE.instantiate()
	door.name = "ElevatorDoor"
	parent.add_child(door)
	door.position = pos
	door.rotation.y = rot_y
	return door
