extends AnimatableBody3D
class_name ElevatorButton

signal button_pressed(floor_num: int)

@export var floor_num: int = 4
@export var push_distance: float = 0.02
@export var move_time: float = 0.2

var is_pressed: bool = false
var original_pos: Vector3

func _ready() -> void:
	original_pos = position

func interact(_player: Node) -> void:
	if is_pressed:
		return
		
	is_pressed = true
	
	# Push the button inward (local Z axis usually, depending on orientation)
	# Assuming the button faces outward along +X or +Z.
	# We will just move it along its local forward axis.
	var push_vector = -transform.basis.z * push_distance
	
	# Simple tween animation
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + push_vector, move_time / 2.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", original_pos, move_time / 2.0).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): is_pressed = false)
	
	button_pressed.emit(floor_num)
