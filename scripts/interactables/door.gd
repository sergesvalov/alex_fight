extends AnimatableBody3D

# No class_name: a scene file that instances door.tscn more than once (north_stairs.tscn,
# double_room.tscn, single_room.tscn all do - two doors per file) was silently losing some
# of those instances (and, in single_room.tscn, other unrelated instanced props too) in
# exported PC builds only, never in a way that printed an error. class_name registers this
# script as a global class tied to the script resource; removing it is a safe, no-behavior-
# change way to rule out global class registration as part of that failure, since nothing
# else in the project actually referenced the InteractiveDoor type name.
signal state_changed(is_open: bool)

@onready var sfx_open: AudioStreamPlayer3D = $"../SfxOpen"
@onready var sfx_close: AudioStreamPlayer3D = $"../SfxClose"

var is_open: bool = false
var is_moving: bool = false
var open_angle: float = -PI / 2.0

func set_door_number(number: String) -> void:
	var label = get_node_or_null("RoomNumberLabel")
	if label:
		label.text = number

func interact(player: Node) -> void:
	if is_moving:
		return
		
	is_moving = true
	
	if not is_open:
		# Swing AWAY from whichever side the player is standing on, so the door never opens
		# into the player - it did exactly that before this fix (2026-08-22): the branch
		# below used to assign the angle that swings the door toward the interacting side.
		var to_player = player.global_position - global_position
		var forward = global_transform.basis.z
		if to_player.dot(forward) > 0:
			open_angle = PI / 2.0
		else:
			open_angle = -PI / 2.0
			
	is_open = !is_open
	state_changed.emit(is_open)
	
	var target_rot = open_angle if is_open else 0.0
	
	if is_open:
		sfx_open.play()
	else:
		sfx_close.play()
		
	var tween = create_tween()
	tween.tween_property(self, "rotation:y", target_rot, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): is_moving = false)
