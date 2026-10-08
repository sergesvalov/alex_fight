# scripts/levels/blocks/name_door_trap.gd
# Floor 8's nightmare, "name yourself": the door plates on this floor carry surnames instead of
# room numbers, and the floor only lets a man into his own room. Step through any other door and
# you are back by the elevator. The hero does not know his name when he arrives - the floor's
# first recording gives it back ("the name came back before the profession: Nechaev"), and one
# tape always lies in the maintenance room, which has no plate and no trap, so that first
# recording can always be reached. The other two tapes are in the room with his name on it.
#
# One instance per room, just inside its doorway, with the same doorway-then-slab arming as
# room_shuffle_trap.gd so it only fires on the way IN. Created only on floor 8 by
# hotel_level_generator.gd::_add_name_doors(). Floor 8's own three tapes switch it off for good
# (GameStateManager.floor8_named) and unlock floor 9.
extends Area3D

const ARM_TIME_MS: int = 1500

var is_own_room: bool = false
var return_position: Vector3 = Vector3.ZERO

var _armed_until_ms: int = 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Threshold.body_entered.connect(_on_threshold_entered)

func _on_threshold_entered(body: Node) -> void:
	if body.name == "Player":
		_armed_until_ms = Time.get_ticks_msec() + ARM_TIME_MS

func _on_body_entered(body: Node) -> void:
	if body.name != "Player" or GameStateManager.floor8_named:
		return
	if Time.get_ticks_msec() > _armed_until_ms:
		return # walking around inside the room, or on the way out
	_armed_until_ms = 0
	if is_own_room:
		DialogSystem.trigger_alex_line("floor8_own_room")
		return
	# Same kind of line every other teleport in the game prints (see stairs_gate.gd).
	print("[NameDoorTrap] ", name, " is not the player's room - returning from ", body.global_position, " to ", return_position)
	body.global_position = return_position
	if "velocity" in body:
		body.velocity = Vector3.ZERO
	DialogSystem.trigger_alex_line("floor8_wrong_door")
