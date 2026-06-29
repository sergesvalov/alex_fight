# autoloads/AudioManager.gd
extends Node

var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer

# NOTE: Paths will be loaded once files exist, using stubs for now
# const MUSIC = {
#     "menu": preload("res://assets/audio/music/menu_theme.ogg"),
#     "hotel_ambient": preload("res://assets/audio/music/hotel_ambient.ogg"),
#     "combat": preload("res://assets/audio/music/combat_tense.ogg"),
# }
const MUSIC = {}

func _ready():
    music_player = AudioStreamPlayer.new()
    add_child(music_player)
    ambience_player = AudioStreamPlayer.new()
    add_child(ambience_player)

func play_music(track_name: String, fade_duration: float = 1.0) -> void:
    if not MUSIC.has(track_name):
        return
        
    # Плавная смена треков через Tween
    var tween = create_tween()
    tween.tween_property(music_player, "volume_db", -80, fade_duration)
    await tween.finished
    music_player.stream = MUSIC[track_name]
    music_player.play()
    tween = create_tween()
    tween.tween_property(music_player, "volume_db", 0, fade_duration)

func play_sfx(sfx: AudioStream, position: Vector3 = Vector3.ZERO) -> void:
    var player = AudioStreamPlayer3D.new()
    add_child(player)
    player.stream = sfx
    player.global_position = position
    player.play()
    player.finished.connect(player.queue_free)
