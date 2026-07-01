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
    
    # We do nothing else for now, as requested by the user.
