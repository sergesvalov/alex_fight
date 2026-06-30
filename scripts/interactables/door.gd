extends StaticBody3D
class_name InteractiveDoor

@onready var hinge: Node3D = $".."
@onready var sfx_open: AudioStreamPlayer3D = $"../../SfxOpen"
@onready var sfx_close: AudioStreamPlayer3D = $"../../SfxClose"

var is_open: bool = false
var is_moving: bool = false

func interact(player: Node) -> void:
    if is_moving:
        return
        
    is_moving = true
    is_open = !is_open
    
    # 90 degrees open
    var target_rot = -PI / 2.0 if is_open else 0.0
    
    if is_open:
        sfx_open.play()
    else:
        sfx_close.play()
        
    var tween = create_tween()
    tween.tween_property(hinge, "rotation:y", target_rot, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_callback(func(): is_moving = false)
