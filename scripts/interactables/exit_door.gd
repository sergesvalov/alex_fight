extends AnimatableBody3D

@onready var hinge: Node3D = $".."
@onready var sfx_open: AudioStreamPlayer3D = $"../../SfxOpen"

var is_open = false

func interact(player):
    if is_open:
        return
        
    is_open = true
    sfx_open.play()
    
    var to_player = player.global_position - global_position
    var forward = global_transform.basis.z
    var open_angle = -PI / 2.0
    if to_player.dot(forward) <= 0:
        open_angle = PI / 2.0
        
    var tween = create_tween()
    tween.tween_property(hinge, "rotation:y", open_angle, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    
    await tween.finished
    GameStateManager.entered_from_outer_door = true
    var target_scene = ""
    if GameStateManager.current_floor == 4:
        target_scene = "res://scenes/levels/hotel_siberia/hotel_level_3.tscn"
        GameStateManager.reset_floor(3)
    else:
        target_scene = "res://scenes/levels/hotel_siberia/hotel_level_4.tscn"
        GameStateManager.reset_floor(4)
        
    get_tree().change_scene_to_file(target_scene)

