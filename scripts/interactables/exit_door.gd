extends StaticBody3D

@onready var animation_player = $AnimationPlayer
@onready var audio_player = $AudioStreamPlayer3D

var is_open = false

func interact(player):
    if is_open:
        return
        
    is_open = true
    animation_player.play("open")
    audio_player.play()
    
    # Wait for the sound/animation briefly or immediately transition
    await get_tree().create_timer(0.5).timeout
    
    GameStateManager.entered_from_outer_door = true
    var target_scene = ""
    if GameStateManager.current_floor == 4:
        target_scene = "res://scenes/levels/hotel_siberia/hotel_level_3.tscn"
        GameStateManager.reset_floor(3)
    else:
        target_scene = "res://scenes/levels/hotel_siberia/hotel_level_4.tscn"
        GameStateManager.reset_floor(4)
        
    get_tree().change_scene_to_file(target_scene)

