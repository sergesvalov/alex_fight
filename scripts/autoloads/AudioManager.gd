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

# --- Tape pickup sound ---
# Synthesized once, here, rather than shipped as a file: a cassette being pulled off a shelf and
# seated - a sharp plastic click, a low hollow knock of the shell, and a softer latch click.
# (It replaces door_close.wav played at 2.4x pitch, which was only ever a stand-in.)
var _tape_pickup_sound: AudioStreamWAV = null

func tape_pickup_sound() -> AudioStreamWAV:
    if _tape_pickup_sound:
        return _tape_pickup_sound
    const RATE: int = 22050
    const LENGTH: float = 0.42
    var rng := RandomNumberGenerator.new()
    rng.seed = 1987
    var data := PackedByteArray()
    data.resize(int(RATE * LENGTH) * 2)
    var low_noise: float = 0.0   # one-pole low-passed noise, for the dull body of the knock
    for i in range(int(RATE * LENGTH)):
        var t: float = float(i) / RATE
        var noise: float = rng.randf_range(-1.0, 1.0)
        low_noise += (noise - low_noise) * 0.12
        var s: float = 0.0
        # 1. plastic click: a burst of bright noise with a short ring
        s += noise * exp(-t * 110.0) * 0.55 + sin(TAU * 2300.0 * t) * exp(-t * 70.0) * 0.25
        # 2. the shell knocking home, 90 ms later: low and hollow
        if t >= 0.09:
            var k: float = t - 0.09
            s += sin(TAU * 150.0 * k) * exp(-k * 26.0) * 0.75 + low_noise * exp(-k * 40.0) * 1.2
        # 3. latch click, quieter and a little lower
        if t >= 0.22:
            var c: float = t - 0.22
            s += noise * exp(-c * 140.0) * 0.3 + sin(TAU * 1700.0 * c) * exp(-c * 90.0) * 0.18
        data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
    _tape_pickup_sound = AudioStreamWAV.new()
    _tape_pickup_sound.format = AudioStreamWAV.FORMAT_16_BITS
    _tape_pickup_sound.mix_rate = RATE
    _tape_pickup_sound.stereo = false
    _tape_pickup_sound.data = data
    return _tape_pickup_sound

func play_sfx(sfx: AudioStream, position: Vector3 = Vector3.ZERO, pitch: float = 1.0, volume_db: float = 0.0) -> void:
    var player = AudioStreamPlayer3D.new()
    add_child(player)
    player.stream = sfx
    player.pitch_scale = pitch
    player.volume_db = volume_db
    player.global_position = position
    player.play()
    player.finished.connect(player.queue_free)
