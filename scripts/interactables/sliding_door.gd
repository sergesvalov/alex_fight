extends AnimatableBody3D
class_name SlidingDoor

@onready var sfx_open: AudioStreamPlayer3D = $"../SfxOpen"
@onready var sfx_close: AudioStreamPlayer3D = $"../SfxClose"

@export var open_offset: Vector3 = Vector3(2.3, 0, 0)
@export var move_time: float = 1.5

var is_open: bool = false
var is_moving: bool = false
var closed_pos: Vector3

func _ready() -> void:
	closed_pos = position

func interact(_player: Node) -> void:
	if is_moving:
		return
		
	is_moving = true
	is_open = !is_open
	
	var target_pos = closed_pos + open_offset if is_open else closed_pos
	
	if sfx_open and is_open:
		sfx_open.play()
	elif sfx_close and not is_open:
		sfx_close.play()
		
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): is_moving = false)
