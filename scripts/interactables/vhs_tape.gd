# scripts/interactables/vhs_tape.gd
extends Area3D

@export var tape_id: int = 0

# Procedurally generated in Godot (Image/ImageTexture) instead of an external asset - the
# previous vhs_retro.jpg was a glossy neon "SYNTHWAVE DREAMS" stock photo that had nothing to
# do with this game's Soviet-institutional found-footage look. This draws a worn plastic shell
# with a plain paper evidence-tag label instead; the glow color/intensity below still matches
# what the .tscn used to bake into its material (Color(0.8, 0.2, 0.8), energy 0.5).
func _ready() -> void:
    var mesh_inst := get_node_or_null("MeshInstance3D")
    print("[vhs_tape] _ready tape_id=", tape_id, " path=", get_path(), " mesh_inst=", mesh_inst)
    if not mesh_inst:
        push_error("[vhs_tape] tape_id=" + str(tape_id) + " has no MeshInstance3D child - material never applied")
        return
    var tex := _generate_tape_texture()
    print("[vhs_tape] tape_id=", tape_id, " generated texture=", tex, " size=", (tex.get_size() if tex else "N/A"))
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = tex
    mat.uv1_scale = Vector3(2, 1, 2)
    mat.emission_enabled = true
    mat.emission = Color(0.8, 0.2, 0.8, 1)
    mat.emission_energy_multiplier = 0.5
    mesh_inst.material_override = mat
    print("[vhs_tape] tape_id=", tape_id, " material_override set=", mesh_inst.material_override,
        " mesh=", mesh_inst.mesh, " global_position=", global_position)

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

func interact(player):
    print("[vhs_tape] interact tape_id=", tape_id, " global_position=", global_position,
        " is_playing_before=", DialogSystem.is_playing, " current_floor=", GameStateManager.current_floor)
    if player.has_method("collect_tape"):
        player.collect_tape()
    GameStateManager.collect_tape(tape_id)
    GameStateManager.add_to_inventory(GameStateManager.current_floor, tape_id)
    DialogSystem.play_tape(tape_id, global_position)
    queue_free()
