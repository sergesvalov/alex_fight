# scripts/autoloads/GameSettings.gd
# The player's own settings: how fast the view turns, how loud the game is, how large the
# subtitles are. Kept apart from the save (SaveManager): a new game must not reset them.
# Each setting moves through a short list of steps, so the menu needs one button per setting
# and no sliders - it has to work with a thumb, a mouse and a gamepad alike.
extends Node

signal changed

const LOOK_STEPS: Array = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
const VOLUME_STEPS: Array = [0.0, 0.25, 0.5, 0.75, 1.0]
const SUBTITLE_STEPS: Array = [1.0, 1.3, 1.6]
const TOUCH_STEPS: Array = [0.0, 1.0]   # two thumbs (stick + look), one finger
const STEPS: Dictionary = {"look_sensitivity": LOOK_STEPS, "volume": VOLUME_STEPS, "subtitle_scale": SUBTITLE_STEPS, "touch_scheme": TOUCH_STEPS}

var settings_path: String = "user://settings.cfg"   # tests point this somewhere else
var look_sensitivity: float = 1.0
var volume: float = 1.0
var subtitle_scale: float = 1.0
var touch_scheme: float = 0.0

func _ready() -> void:
	load_settings()

func one_finger() -> bool:
	return touch_scheme >= 0.5

func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(settings_path) == OK:
		for key in STEPS:
			set(key, _nearest(STEPS[key], float(file.get_value("settings", key, get(key)))))
	_apply()

func save_settings() -> void:
	var file := ConfigFile.new()
	for key in STEPS:
		file.set_value("settings", key, get(key))
	file.save(settings_path)

# Moves a setting to its next step, wrapping round, and returns the new value.
func cycle(key: String) -> float:
	var steps: Array = STEPS[key]
	var value: float = steps[(steps.find(_nearest(steps, get(key))) + 1) % steps.size()]
	set(key, value)
	_apply()
	save_settings()
	changed.emit()
	return value

func _nearest(steps: Array, value: float) -> float:
	var best: float = steps[0]
	for step in steps:
		if absf(step - value) < absf(best - value):
			best = step
	return best

func _apply() -> void:
	var master: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master, volume <= 0.0)
	if volume > 0.0:
		AudioServer.set_bus_volume_db(master, linear_to_db(volume))
