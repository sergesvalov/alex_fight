# autoloads/DialogSystem.gd
extends Node

# Carries the resolved tape dict (title/text/duration), not just an id - hud.gd's subtitle is
# the actual readable surface now (see play_tape_for_floor()), and it has no other way to look
# the text up itself without duplicating the floor/tape_data lookup already done here.
signal narrative_started(tape: Dictionary)
signal narrative_ended

var is_playing: bool = false
var holo_scene: PackedScene = preload("res://scenes/fx/holo_projection.tscn")

# Movement locks for this long at most while a tape plays (long tapes keep narrating/showing the
# subtitle for their full duration regardless - only the READING movement-lock is capped, so the
# player never feels frozen in place for a 10s+ narration).
const MAX_READING_LOCK: float = 2.0

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
    print("[DialogSystem] play_tape_for_floor floor=", floor_num, " tape_id=", tape_id,
        " spawn_position=", spawn_position, " is_playing=", is_playing)
    if is_playing:
        push_warning("[DialogSystem] play_tape_for_floor ignored - already playing (stuck is_playing?)")
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
    print("[DialogSystem] current_tape=", current_tape)

    is_playing = true
    GameStateManager.change_state(GameStateManager.GameState.READING)
    # hud.gd shows the actual readable text as a screen-space subtitle on this signal - see its
    # comment for why (the old design read text off a world-space Label3D floating over the
    # hologram, which forced players to tilt the camera up at whatever angle the pickup spot
    # happened to leave it at, including straight into the ceiling in low rooms).
    narrative_started.emit(current_tape)

    if holo_scene:
        var holo_instance = holo_scene.instantiate()
        # Small ambient flicker hovering just above the tape's own spot - purely atmospheric
        # now that the subtitle (hud.gd) carries the actual text, so it no longer needs to clear
        # head height or avoid the camera ending up inside its cone (the cone is short and this
        # low, that's no longer reachable while standing).
        get_tree().current_scene.add_child(holo_instance)
        holo_instance.global_position = spawn_position + Vector3(0, 0.4, 0)
        if holo_instance.has_method("set_tape_data"):
            holo_instance.set_tape_data(current_tape)
    else:
        push_error("[DialogSystem] holo_scene is null - no hologram will show")

    var duration: float = current_tape["duration"]
    var lock_time: float = min(MAX_READING_LOCK, duration)
    await get_tree().create_timer(lock_time).timeout
    # Only the movement lock ends here - the subtitle/hologram (and is_playing, so the player
    # can't immediately start a second tape) keep going for the rest of the tape's duration.
    # Guarded by still-READING in case something else (combat, death) already changed state
    # during the lock.
    if GameStateManager.current_state == GameStateManager.GameState.READING:
        GameStateManager.change_state(GameStateManager.GameState.EXPLORING)

    var remaining: float = duration - lock_time
    if remaining > 0.0:
        await get_tree().create_timer(remaining).timeout
    print("[DialogSystem] narrative timer finished for tape_id=", tape_id)
    end_narrative()

func end_narrative() -> void:
    print("[DialogSystem] end_narrative, is_playing -> false")
    is_playing = false
    if GameStateManager.current_state == GameStateManager.GameState.READING:
        GameStateManager.change_state(GameStateManager.GameState.EXPLORING)
    narrative_ended.emit()

func show_thought(text: String, duration: float = 5.0) -> void:
    if EventBus.has_signal("narrative_thought_requested"):
        EventBus.narrative_thought_requested.emit(text, duration)

# --- Alex's reactive one-liners (LORE.md "Реплики Алекса") ---
# Each fires at most once per playthrough, the first time its trigger actually happens -
# _alex_lines_fired is the guard. Callable from anywhere (vhs_tape.gd, stairs_gate.gd,
# cerberus_ai.gd, secret_portal.gd); if a tape/hologram is already showing, waits for it to
# finish first so the two don't fight over the same subtitle bar.
var _alex_lines_fired: Dictionary = {}

const ALEX_LINES := {
    "tape1": "Нечаев... Это же... я. Какого чёрта я здесь делал?",
    "endless_corridor": "Я уже проходил здесь. Клянусь, я только что здесь был.",
    "cerberus_sighting": "Сектор-7... Они активировали протокол карантина. Эта штука нас не выпустит.",
    "secret_portal": "Реальность трещит по швам. Нужно идти глубже.",
}

func trigger_alex_line(key: String) -> void:
    if _alex_lines_fired.get(key, false):
        return
    _alex_lines_fired[key] = true
    var line: String = ALEX_LINES.get(key, "")
    if line == "":
        return
    # Diagnostic (2026-08-23) - this is the single place every "why is there a line of text on
    # screen" report traces back to (tape1/endless_corridor/cerberus_sighting/secret_portal all
    # funnel through here). Printing the key up front means the next log always says exactly
    # which trigger fired and when, instead of having to reason backward from a screenshot.
    print("[DialogSystem] trigger_alex_line key=", key, " line=\"", line, "\"")
    if is_playing:
        await narrative_ended
    show_thought(line, 4.0)
