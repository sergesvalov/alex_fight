# scripts/interactables/vhs_tape.gd
extends Area3D

@export var tape_id: int = 0
# ui_strings.json key describing roughly where this tape was put ("tape_hint_table", ...), set
# by hotel_level_generator.gd - the floor's CRT terminal lists it (terminal_ui.gd).
var location_hint: String = ""

# One texture per tape_id, shared by every floor's copy of that tape - the image is seeded by
# tape_id alone, so generating it again for each of the 27 tapes produced identical pixels.
static var _texture_cache: Dictionary = {}

# A dark cassette on a dark shelf is close to invisible, so the paper label breathes a faint
# warm glow. Kept low on purpose: the old flat neon emission swamped the texture under bloom.
const GLOW_COLOR := Color(1.0, 0.75, 0.4)
const GLOW_MIN: float = 0.05
const GLOW_MAX: float = 0.45
const GLOW_PERIOD: float = 2.4

var _material: StandardMaterial3D
var _glow_time: float = 0.0

# Procedurally generated in Godot (Image/ImageTexture) instead of an external asset - the
# previous vhs_retro.jpg was a glossy neon "SYNTHWAVE DREAMS" stock photo that had nothing to
# do with this game's Soviet-institutional found-footage look. This draws a worn plastic shell
# with a plain paper evidence-tag label instead.
func _ready() -> void:
    var mesh_inst := get_node_or_null("MeshInstance3D")
    if not mesh_inst:
        push_error("[vhs_tape] tape_id=" + str(tape_id) + " has no MeshInstance3D child - material never applied")
        return
    if not _texture_cache.has(tape_id):
        _texture_cache[tape_id] = _generate_tape_texture()
    var tex: ImageTexture = _texture_cache[tape_id]
    _material = StandardMaterial3D.new()
    _material.albedo_texture = tex
    _material.uv1_scale = Vector3(2, 1, 2)
    _material.emission_enabled = true
    _material.emission = GLOW_COLOR
    _material.emission_texture = tex # the pale label glows, the black shell barely does
    _material.emission_energy_multiplier = GLOW_MIN
    mesh_inst.material_override = _material
    _glow_time = randf() * GLOW_PERIOD # so three tapes in one view don't pulse in lockstep

func _process(delta: float) -> void:
    if not _material or not is_visible_in_tree():
        return
    _glow_time += delta
    var wave: float = 0.5 - 0.5 * cos(_glow_time * TAU / GLOW_PERIOD)
    _material.emission_energy_multiplier = lerpf(GLOW_MIN, GLOW_MAX, wave)

func _generate_tape_texture() -> ImageTexture:
    var size = 64
    var img = Image.create_empty(size, size, false, Image.FORMAT_RGB8)

    var rng = RandomNumberGenerator.new()
    rng.seed = tape_id + 1 # deterministic per tape_id, not per pickup instance

    # Worn dark plastic shell, per-pixel noise for a scuffed look.
    var shell = Color(0.07, 0.06, 0.065)
    for y in range(size):
        for x in range(size):
            var n = rng.randf_range(-0.025, 0.025)
            img.set_pixel(x, y, Color(shell.r + n, shell.g + n, shell.b + n))

    # Plain paper evidence-tag label (no printed branding - the game's own holo-projection
    # supplies the real title text when the tape is played).
    var label = Color(0.58, 0.53, 0.44)
    var lx0 = int(size * 0.12)
    var lx1 = int(size * 0.88)
    var ly0 = int(size * 0.32)
    var ly1 = int(size * 0.62)
    for y in range(ly0, ly1):
        for x in range(lx0, lx1):
            var n = rng.randf_range(-0.04, 0.04)
            img.set_pixel(x, y, Color(label.r + n, label.g + n, label.b + n))

    # Thin handwritten-looking rule line across the middle of the label.
    var stripe_y = int((ly0 + ly1) / 2.0)
    for x in range(lx0 + 2, lx1 - 2):
        img.set_pixel(x, stripe_y, Color(0.15, 0.13, 0.11))

    return ImageTexture.create_from_image(img)

func interact(_player):
    # WHICH recording this is depends on the order of finding, not on which shelf it lay on:
    # the first tape taken on a floor plays that floor's first recording, the third its last.
    # A floor's story therefore always unfolds in order, and its closing recording is always
    # the one that comes with the floor's own event. tape_id itself only tells the three
    # physical cassettes of a floor apart (placement, texture).
    var floor_num: int = GameStateManager.current_floor
    var recording: int = GameStateManager.tapes_found.size()
    print("[vhs_tape] interact tape_id=", tape_id, " recording=", recording, " global_position=", global_position,
        " is_playing_before=", DialogSystem.is_playing, " current_floor=", floor_num)
    AudioManager.play_sfx(AudioManager.tape_pickup_sound(), global_position)
    # Narration first, so is_playing is already true (play_tape() runs synchronously up to its
    # first await) by the time collect_tape() fires the floor's event and any trigger_alex_line()
    # that comes with it - those wait for the narration to finish instead of stepping on it.
    DialogSystem.play_tape(recording, global_position)
    GameStateManager.taken_cassettes.append([floor_num, tape_id])
    GameStateManager.collect_tape(recording)
    GameStateManager.add_to_inventory(floor_num, recording)
    if recording == 0:
        DialogSystem.trigger_alex_line("tape1")
    queue_free()
