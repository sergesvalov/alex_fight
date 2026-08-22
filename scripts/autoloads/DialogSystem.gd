# autoloads/DialogSystem.gd
extends Node

signal narrative_started(tape_id: int)
signal narrative_ended

var is_playing: bool = false
var holo_scene: PackedScene = preload("res://scenes/fx/holo_projection.tscn")

var tape_data: Dictionary = {}

func _ready() -> void:
    load_tape_data()

func load_tape_data() -> void:
    var file = FileAccess.open("res://assets/data/tapes.json", FileAccess.READ)
    if file:
        var json_string = file.get_as_text()
        var json = JSON.new()
        var error = json.parse(json_string)
        if error == OK:
            tape_data = json.data
        else:
            push_error("Failed to parse tapes.json")
    else:
        push_error("Could not open tapes.json")

func play_tape(tape_id: int, spawn_position: Vector3) -> void:
    play_tape_for_floor(GameStateManager.current_floor, tape_id, spawn_position)

# Same as play_tape(), but for a specific floor rather than assuming the player's current one -
# needed to replay a tape from the inventory after the player has already moved to another
# floor/loop (GameStateManager.current_floor would point at the wrong floor's tape_data by then).
func play_tape_for_floor(floor_num: int, tape_id: int, spawn_position: Vector3) -> void:
    if is_playing:
        return

    var floor_str = str(floor_num)
    if not tape_data.has(floor_str):
        push_error("No tape data for floor " + floor_str)
        return

    var floor_tapes = tape_data[floor_str]
    if tape_id < 0 or tape_id >= floor_tapes.size():
        push_error("Invalid tape_id for floor " + floor_str)
        return

    var current_tape = floor_tapes[tape_id]
    
    is_playing = true
    GameStateManager.change_state(GameStateManager.GameState.READING)
    narrative_started.emit(tape_id)
    
    if holo_scene:
        var holo_instance = holo_scene.instantiate()
        # Raised well above head height: the cone (CylinderMesh, 2m tall) starts right at
        # spawn_position's own Y, so a player interacting from close range - normal for a
        # ~3m interact ray - ends up with the camera INSIDE the additive-blended, depth-less
        # shader (hologram.gdshader: blend_add + cull_disabled + depth_draw_never), which floods
        # the whole screen with cyan and buries the Label3D under it. +2m puts the whole cone
        # comfortably above a standing player's eye line regardless of how close they are.
        holo_instance.global_position = spawn_position + Vector3(0, 2.0, 0)
        get_tree().current_scene.add_child(holo_instance)
        if holo_instance.has_method("set_tape_data"):
            holo_instance.set_tape_data(current_tape)
    
    await get_tree().create_timer(current_tape["duration"]).timeout
    end_narrative()

func end_narrative() -> void:
    is_playing = false
    GameStateManager.change_state(GameStateManager.GameState.EXPLORING)
    narrative_ended.emit()

func show_thought(text: String, duration: float = 5.0) -> void:
    if EventBus.has_signal("narrative_thought_requested"):
        EventBus.narrative_thought_requested.emit(text, duration)
