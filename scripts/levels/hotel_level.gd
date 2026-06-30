# scripts/levels/hotel_level.gd
extends Node3D

# The level script is now clean and handles level-specific mechanics.
# Enemy spawning is handled by the EnemySpawner node.
# Mouse capture is handled by MouseManager autoload.

var wind_sound = preload("res://assets/audio/sfx/wind.wav")
var wind_timer: Timer
var wind_player: AudioStreamPlayer

func _ready() -> void:
    wind_player = AudioStreamPlayer.new()
    wind_player.stream = wind_sound
    add_child(wind_player)
    
    wind_timer = Timer.new()
    wind_timer.one_shot = false
    wind_timer.timeout.connect(_on_wind_timer_timeout)
    add_child(wind_timer)
    
    wind_timer.start(randf_range(5.0, 15.0))

func _on_wind_timer_timeout() -> void:
    wind_timer.wait_time = randf_range(10.0, 25.0)
    wind_player.play()
