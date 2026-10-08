# autoloads/SaveManager.gd
# One save slot, written automatically - there is no "save" button anywhere.
#
# What is saved is the player's PROGRESS, all of which already lives in GameStateManager
# (SAVED_FIELDS), plus which of Alex's one-off lines have been said. What is not saved is the
# level: it is rebuilt on every launch from GameStateManager.world_seed, so tapes, the sealed
# room, the hero's own room and the lift code come out the same every time, and the cassettes
# already taken (taken_cassettes) are simply removed again after the build. Robots, trap phases
# and a tape that was playing are deliberately not restored - continuing puts the hero by the
# elevator of the floor he was on, exactly where every trap returns him anyway.
#
# When it saves (only while a game is running - `active`, set by the start screen):
#   - right after a tape is picked up
#   - every AUTOSAVE_INTERVAL seconds, which covers floor changes, traps and consoles
#   - when the app goes to the background or its window is closed - on a phone that is the last
#     chance before the OS may kill it; a dead battery falls back on the previous autosave
# Written to a temporary file and renamed over the real one, so losing power mid-write cannot
# leave a half-written save.
extends Node

const VERSION: int = 1
const AUTOSAVE_INTERVAL: float = 15.0
const SAVED_FIELDS: Array = [
	"world_seed", "collected_tapes", "taken_cassettes", "cerberus_spawned",
	"unlocked_floor_min", "unlocked_floor_max", "lobby_unlocked", "lower_lift_called",
	"lab_reached", "lab_consoles_off",
	"secret_portal_active", "secret_portal_floor", "secret_portal_is_double", "secret_portal_room_num",
	"secret_portal_target", "secret_portal_target_floor",
	"floor3_corridor_unlocked", "floor5_rooms_unlocked", "floor6_sleepers_off", "floor7_lights_steady",
	"floor8_named", "floor2_done", "floor9_cameras_off", "floor10_edge_stopped",
	"current_floor", # last: its setter rebuilds the floor's tape count from collected_tapes
]

var save_path: String = "user://savegame.json"   # tests point this somewhere else
var active: bool = false      # a game is running - autosave is on
var resuming: bool = false    # this run was loaded from a save (the generator reads it once)

var _defaults: Dictionary = {}
var _timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # the inventory and the terminal pause the tree
	for field in SAVED_FIELDS:
		var value = GameStateManager.get(field)
		_defaults[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	GameStateManager.tape_collected.connect(func(_id): save_game.call_deferred())
	GameStateManager.state_changed.connect(_on_state_changed)
	# The headset build has no start screen (a flat menu cannot be seen or clicked in VR, and
	# its main scene is the level itself - see configs/project.vr.godot): the choice the
	# screen offers is made here instead, before the level loads. Continue if there is
	# something to continue, otherwise a new game.
	if ProjectSettings.get_setting("xr/openxr/enabled", false) and DisplayServer.get_name() != "headless":
		if not load_game():
			new_game()

func _process(delta: float) -> void:
	if not active:
		return
	_timer += delta
	if _timer >= AUTOSAVE_INTERVAL:
		save_game()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST]:
		save_game()

func _on_state_changed(new_state: GameStateManager.GameState) -> void:
	# The game is over: the next launch starts fresh instead of continuing a finished story.
	if new_state == GameStateManager.GameState.WIN:
		active = false
		delete_save()

func has_save() -> bool:
	return not _read().is_empty()

# Short facts for the start screen's "continue" line; empty if there is nothing to continue.
func summary() -> Dictionary:
	var data: Dictionary = _read()
	if data.is_empty():
		return {}
	return {"floor": int(data["state"].get("current_floor", 4)), "tapes": (data["state"].get("collected_tapes", []) as Array).size()}

func new_game() -> void:
	delete_save()
	for field in SAVED_FIELDS:
		_apply(field, _defaults[field])
	GameStateManager.world_seed = randi()
	GameStateManager.unlocked_floor_min = -1 # init_floor_access() seeds these at level start
	GameStateManager.unlocked_floor_max = -1
	GameStateManager.current_state = GameStateManager.GameState.EXPLORING
	DialogSystem._alex_lines_fired.clear()
	resuming = false
	active = true
	_timer = 0.0

func load_game() -> bool:
	var data: Dictionary = _read()
	if data.is_empty():
		return false
	for field in SAVED_FIELDS:
		if data["state"].has(field):
			_apply(field, _decode(data["state"][field], _defaults[field]))
	DialogSystem._alex_lines_fired.clear()
	for key in data.get("lines", []):
		DialogSystem._alex_lines_fired[key] = true
	GameStateManager.current_state = GameStateManager.GameState.EXPLORING
	resuming = true
	active = true
	_timer = 0.0
	return true

func save_game() -> void:
	_timer = 0.0
	if not active:
		return
	var state: Dictionary = {}
	for field in SAVED_FIELDS:
		state[field] = _encode(GameStateManager.get(field))
	var data: Dictionary = {"version": VERSION, "state": state, "lines": DialogSystem._alex_lines_fired.keys()}
	var tmp_path: String = save_path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		push_warning("[SaveManager] cannot write " + tmp_path)
		return
	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(save_path))

func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

# The parsed save, or {} if there is none, it is unreadable, or it is from another version.
func _read() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new() # not JSON.parse_string(): that logs an engine error for a broken file
	if json.parse(file.get_as_text()) != OK:
		return {}
	var parsed = json.data
	if not parsed is Dictionary or int(parsed.get("version", -1)) != VERSION or not parsed.get("state") is Dictionary:
		return {}
	return parsed

func _apply(field: String, value) -> void:
	var current = GameStateManager.get(field)
	if current is Array:
		current.assign(value) # keeps typed arrays (Array[int], Array[Dictionary]) typed
	else:
		GameStateManager.set(field, value)

func _encode(value):
	if value is Vector3:
		return [value.x, value.y, value.z]
	return value

# JSON has one number type and no vectors - bring a loaded value back to the type of the
# field's own default.
func _decode(value, like):
	if like is Vector3:
		return Vector3(value[0], value[1], value[2])
	if like is bool:
		return bool(value)
	if like is int:
		return int(value)
	if like is Array:
		return (value as Array).map(_decode_entry)
	return value

func _decode_entry(entry):
	if entry is Dictionary: # collected_tapes: {"floor", "id"}
		return {"floor": int(entry["floor"]), "id": int(entry["id"])}
	if entry is Array:      # taken_cassettes: [floor, tape_id]
		return [int(entry[0]), int(entry[1])]
	return int(entry) if entry is float else entry
