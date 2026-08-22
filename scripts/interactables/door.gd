extends AnimatableBody3D
class_name InteractiveDoor

signal state_changed(is_open: bool)

@onready var sfx_open: AudioStreamPlayer3D = $"../SfxOpen"
@onready var sfx_close: AudioStreamPlayer3D = $"../SfxClose"

var is_open: bool = false
var is_moving: bool = false
var open_angle: float = -PI / 2.0

func _ready() -> void:
	# Diagnostic for the "door floating in the corridor / stuck in the wall" bug reported
	# 2026-08-22: rooms placed with mirror:true get inst.scale.z = -1.0 on their whole subtree
	# (see hotel_level_generator.gd), which is an ancestor NEGATIVE scale reaching this
	# AnimatableBody3D. Godot explicitly does not support physics bodies under a mirrored
	# (negative-determinant) ancestor transform - the suspicion is that this is exactly what's
	# producing the broken doors. This print makes that visible without attaching a debugger.
	var det = global_transform.basis.determinant()
	var door_root = get_parent()
	var room = door_root.get_parent() if door_root else null
	var room_desc = (room.name + " scale=" + str(room.scale)) if room else "?"
	print("[door.gd] ready: node=", get_path(), " in room=", room_desc,
		" DoorRoot=", (door_root.name if door_root else "?"),
		" global_pos=", global_position, " global_basis.z=", global_transform.basis.z,
		" det(basis)=", det,
		(" <-- MIRRORED ANCESTOR (unsupported for physics bodies)" if det < 0.0 else ""))

func set_door_number(number: String) -> void:
	var label = get_node_or_null("RoomNumberLabel")
	if label:
		label.text = number

func interact(player: Node) -> void:
	if is_moving:
		return
		
	is_moving = true
	
	if not is_open:
		var to_player = player.global_position - global_position
		var forward = global_transform.basis.z
		if to_player.dot(forward) > 0:
			open_angle = -PI / 2.0
		else:
			open_angle = PI / 2.0
			
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
