# scripts/levels/blocks/room_shuffle_trap.gd
# Floor 5's nightmare, "the room that won't let you go": walk in through one room's door and
# you are standing in a different room - the number on the door you leave by is never the one
# you came in by. One instance per room, sitting just inside that room's doorway (see
# hotel_level_generator.gd::HotelTrapBuilder.add_room_shuffle_trap()).
#
# The rule is fixed, so it can be worked out by watching the door plates rather than by trial
# and error: with the floor's rooms taken in room-number order, entering room i puts you in room
# i + 1 + (tapes already collected on this floor), wrapping around. One room's door is locked
# from the corridor side - the only way into it is to enter the room that maps onto it.
# Collecting all three of the floor's tapes switches the whole thing off for good
# (GameStateManager.floor5_rooms_unlocked).
extends Area3D

# How long after crossing the doorway itself the player still counts as "coming in". Leaving
# a room crosses this trigger first and the doorway second, so it never fires on the way out.
const ARM_TIME_MS: int = 1500

var room: Node3D             # the room this trap belongs to
var traps: Array = []        # every room's trap on this floor, in room-number order (shared)
var index: int = 0           # this trap's own place in `traps`
var inside_local: Vector3    # where an arriving player is put, in the room's local space
var facing_yaw: float = 0.0  # player yaw that looks from the doorway into the room

var _armed_until_ms: int = 0

static func destination_index(from_index: int, tapes_collected: int, room_count: int) -> int:
	return (from_index + 1 + tapes_collected) % room_count

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Threshold.body_entered.connect(_on_threshold_entered)

func _on_threshold_entered(body: Node) -> void:
	if body.name == "Player":
		_armed_until_ms = Time.get_ticks_msec() + ARM_TIME_MS

func _on_body_entered(body: Node) -> void:
	if body.name != "Player" or GameStateManager.floor5_rooms_unlocked:
		return
	if Time.get_ticks_msec() > _armed_until_ms:
		return # walking around inside the room, or on the way out
	_armed_until_ms = 0

	var dest = traps[destination_index(index, GameStateManager.tapes_found.size(), traps.size())]
	var target: Vector3 = dest.room.global_transform * dest.inside_local
	# Same kind of line every other teleport in the game prints (see stairs_gate.gd).
	print("[RoomShuffleTrap] entered ", room.name, " -> placed in ", dest.room.name,
		" (tapes on floor=", GameStateManager.tapes_found.size(), ") from ", body.global_position, " to ", target)
	body.global_position = target
	body.rotation.y = dest.facing_yaw
	if "velocity" in body:
		body.velocity = Vector3.ZERO
	DialogSystem.trigger_alex_line("floor5_wrong_room")
