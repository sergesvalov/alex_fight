# autoloads/DialogSystem.gd
extends Node

# Carries the resolved tape dict (title/text/duration), not just an id - hud.gd's subtitle is
# the actual readable surface now (see play_tape_for_floor()), and it has no other way to look
# the text up itself without duplicating the floor/tape_data lookup already done here.
signal narrative_started(tape: Dictionary)
signal narrative_ended

var is_playing: bool = false
var holo_scene: PackedScene = preload("res://scenes/fx/holo_projection.tscn")

# The hologram of the tape currently playing, freed again in end_narrative().
var _holo_instance: Node3D = null

var tape_data: Dictionary = {}

func _ready() -> void:
    load_tape_data()
    load_narrative_data()

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

# [floor_num, tape_id, spawn_position] of tapes waiting for the current one to finish.
var _tape_queue: Array = []

# The title/text/duration of one tape. A floor with no text written for it yet gets
# tapes.json's "damaged" entry rather than nothing at all; empty only if even that is missing.
func get_tape(floor_num: int, tape_id: int) -> Dictionary:
    var floor_tapes = tape_data.get(str(floor_num), [])
    if floor_tapes is Array and tape_id >= 0 and tape_id < floor_tapes.size():
        return floor_tapes[tape_id]
    return tape_data.get("damaged", {})

func play_tape(tape_id: int, spawn_position: Vector3) -> void:
    play_tape_for_floor(GameStateManager.current_floor, tape_id, spawn_position)

# Same as play_tape(), but for a specific floor rather than assuming the player's current one -
# needed to replay a tape from the inventory after the player has already moved to another
# floor/loop (GameStateManager.current_floor would point at the wrong floor's tape_data by then).
func play_tape_for_floor(floor_num: int, tape_id: int, spawn_position: Vector3) -> void:
    print("[DialogSystem] play_tape_for_floor floor=", floor_num, " tape_id=", tape_id,
        " spawn_position=", spawn_position, " is_playing=", is_playing)
    if is_playing:
        # Picked up (or replayed) while another tape is still narrating - it plays right after,
        # instead of being dropped and leaving the player with a tape they never got to hear.
        _tape_queue.append([floor_num, tape_id, spawn_position])
        return

    var current_tape: Dictionary = get_tape(floor_num, tape_id)
    if current_tape.is_empty():
        push_error("No tape data for floor %d tape %d, and no \"damaged\" fallback in tapes.json" % [floor_num, tape_id])
        return
    print("[DialogSystem] current_tape=", current_tape)

    is_playing = true
    # hud.gd shows the actual readable text as a screen-space subtitle on this signal - see its
    # comment for why (the old design read text off a world-space Label3D floating over the
    # hologram, which forced players to tilt the camera up at whatever angle the pickup spot
    # happened to leave it at, including straight into the ceiling in low rooms).
    narrative_started.emit(current_tape)

    if holo_scene:
        var holo_instance = holo_scene.instantiate()
        _holo_instance = holo_instance
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

    # A tape playing is loud: every robot on this floor within earshot walks to where the
    # sound came from (see enemy_ai_base.gd::hear_noise()) - the spot the tape was played at,
    # not wherever the player has gone since. That is the price of a memory (per LORE.md the
    # hero stays vulnerable while one plays) and what makes WHERE and WHEN to take a tape a
    # decision. Replaying one from the inventory makes the same noise at the player's own
    # position (inventory_ui.gd passes it as spawn_position), so it also works as a lure:
    # play it and walk away.
    get_tree().call_group("enemies", "hear_noise", spawn_position)

    # No movement lock (there used to be a 2s one): per LORE.md narration never stops gameplay.
    # process_always=false - the timer must not run down while the inventory or a terminal has
    # the game paused, or the subtitle would be gone before the player ever saw it.
    await get_tree().create_timer(current_tape["duration"], false).timeout
    print("[DialogSystem] narrative timer finished for tape_id=", tape_id)
    end_narrative()


func end_narrative() -> void:
    print("[DialogSystem] end_narrative, is_playing -> false")
    is_playing = false
    # The hologram belongs to this one playback - without this every pickup and every replay
    # left its cone standing in the level for good.
    if is_instance_valid(_holo_instance):
        _holo_instance.queue_free()
    _holo_instance = null
    narrative_ended.emit()
    if not _tape_queue.is_empty():
        var next: Array = _tape_queue.pop_front()
        play_tape_for_floor(next[0], next[1], next[2])

func show_thought(text: String, duration: float = 5.0) -> void:
    if EventBus.has_signal("narrative_thought_requested"):
        EventBus.narrative_thought_requested.emit(text, duration)

# --- Alex's reactive one-liners (LORE.md "Реплики Алекса") ---
# Text lives in assets/data/narrative_lines.json now (2026-08-23), not hardcoded here - the same
# "content separate from code" convention tapes.json already established, and it's also what
# terminal_ui.gd's archive entries load from (see load_narrative_data() below - one file, one
# parse, shared by both systems instead of two separate copies of similar data drifting apart).
# Each key fires at most once per playthrough, the first time its trigger actually happens -
# _alex_lines_fired is the guard. Callable from anywhere (vhs_tape.gd, stairs_gate.gd,
# cerberus_ai.gd, secret_portal.gd, hotel_level_generator.gd); if a tape/hologram is already
# showing, waits for it to finish first so the two don't fight over the same subtitle bar.
var _alex_lines_fired: Dictionary = {}
var alex_lines: Dictionary = {}
var terminal_entries: Array = []

func load_narrative_data() -> void:
    var file = FileAccess.open("res://assets/data/narrative_lines.json", FileAccess.READ)
    if file:
        var json = JSON.new()
        var error = json.parse(file.get_as_text())
        if error == OK:
            alex_lines = json.data.get("alex_lines", {})
            terminal_entries = json.data.get("terminal_entries", [])
        else:
            push_error("Failed to parse narrative_lines.json")
    else:
        push_error("Could not open narrative_lines.json")

func trigger_alex_line(key: String) -> void:
    if _alex_lines_fired.get(key, false):
        return
    _alex_lines_fired[key] = true
    var line: String = alex_lines.get(key, "")
    if line == "":
        return
    # Diagnostic (2026-08-23) - this is the single place every "why is there a line of text on
    # screen" report traces back to (all reactive lines funnel through here). Printing the key up
    # front means the next log always says exactly which trigger fired and when, instead of
    # having to reason backward from a screenshot.
    print("[DialogSystem] trigger_alex_line key=", key, " line=\"", line, "\"")
    if is_playing:
        await narrative_ended
    show_thought(line, 4.0)
