extends AnimatableBody3D
class_name WardrobeDoor

signal state_changed(is_open: bool)

@export var open_angle: float = 1.5708
var is_open: bool = false
var is_moving: bool = false

func interact(_player: Node) -> void:
	if is_moving:
		return
		
	is_moving = true
	is_open = !is_open
	state_changed.emit(is_open)
	
	var target_rot = open_angle if is_open else 0.0
	
	var tween = create_tween()
	tween.tween_property(self, "rotation:y", target_rot, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): is_moving = false)
