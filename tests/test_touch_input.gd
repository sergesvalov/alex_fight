extends Node

# Checks the touch controls. One finger (scripts/ui/one_finger_input.gd): a short still touch is
# a tap, a held one walks, dragging turns, and a second finger can tap while the first holds.
# Two thumbs: the same zone with walk_on_hold off, and the stick (scripts/ui/move_stick_input.gd).
#
# Run via: godot --headless tests/test_touch_input.tscn

var errors: int = 0
var taps: int = 0
var walk_events: Array = []
var turned: Vector2 = Vector2.ZERO
var turn_arounds: int = 0

func _check(ok: bool, label: String) -> void:
	if ok:
		print("✅ PASS: ", label)
	else:
		print("❌ FAIL: ", label)
		errors += 1

func _touch(zone: Control, index: int, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	zone._gui_input(event)

func _drag(zone: Control, index: int, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.relative = relative
	zone._gui_input(event)

func _touch_at(zone: Control, index: int, pressed: bool, at: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = at
	zone._gui_input(event)

func _drag_to(zone: Control, index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	zone._gui_input(event)

func _ready() -> void:
	print("==================================================")
	print("  AUTOTEST: TOUCH CONTROLS")
	print("==================================================")
	var zone := Control.new()
	zone.set_script(load("res://scripts/ui/one_finger_input.gd"))
	add_child(zone)
	zone.tapped.connect(func(): taps += 1)
	zone.walk_changed.connect(func(walking): walk_events.append(walking))
	zone.swipe_dragged.connect(func(relative): turned += relative)
	zone.turned_around.connect(func(): turn_arounds += 1)

	_touch(zone, 0, true)
	zone._process(0.08)
	_touch(zone, 0, false)
	_check(taps == 1 and walk_events.is_empty(), "a short touch that does not move is a tap (shoot), not a step")

	_touch(zone, 0, true)
	zone._process(0.1)
	_check(walk_events.is_empty(), "nothing happens in the first instant of a touch")
	zone._process(0.1)
	_check(walk_events == [true], "holding the finger down starts walking")
	_drag(zone, 0, Vector2(40, 0))
	_check(turned == Vector2(40, 0) and walk_events == [true], "dragging while holding turns without stopping the walk")
	_touch(zone, 1, true)
	zone._process(0.05)
	_touch(zone, 1, false)
	_check(taps == 2 and walk_events == [true], "a second finger tapping shoots while the first keeps walking")
	_touch(zone, 0, false)
	_check(walk_events == [true, false] and taps == 2, "lifting the finger stops, and the end of a walk is not a tap")

	turned = Vector2.ZERO
	_touch(zone, 0, true)
	_drag(zone, 0, Vector2(60, 5))
	zone._process(0.05)
	_touch(zone, 0, false)
	_check(taps == 2 and turned == Vector2(60, 5) and turn_arounds == 0, "a quick swipe turns and is not a tap")

	_touch(zone, 0, true)
	_drag(zone, 0, Vector2(4, 70))
	_drag(zone, 0, Vector2(-2, 60))
	zone._process(0.1)
	_touch(zone, 0, false)
	_check(turn_arounds == 1 and taps == 2, "a quick flick straight down turns round and does not shoot")

	_touch(zone, 0, true)
	_drag(zone, 0, Vector2(0, 130))
	zone._process(0.3)
	zone._process(0.3)
	_touch(zone, 0, false)
	_check(turn_arounds == 1, "a slow drag down is not a flick")

	# --- Two thumbs: the same zone with walk_on_hold off only looks and shoots ---
	zone.walk_on_hold = false
	walk_events.clear()
	turned = Vector2.ZERO
	_touch(zone, 0, true)
	zone._process(0.3)
	_drag(zone, 0, Vector2(30, 0))
	zone._process(0.3)
	_touch(zone, 0, false)
	_check(walk_events.is_empty() and turned == Vector2(30, 0) and taps == 2, "with walk_on_hold off a held finger turns and never walks")
	_touch(zone, 0, true)
	zone._process(0.08)
	_touch(zone, 0, false)
	_check(taps == 3, "and a tap still shoots")

	# --- Two thumbs: the stick (move_stick_input.gd) ---
	var stick := Control.new()
	stick.set_script(load("res://scripts/ui/move_stick_input.gd"))
	add_child(stick)
	var moves: Array = []
	stick.moved.connect(func(vector): moves.append(vector))
	_touch_at(stick, 0, true, Vector2(200, 300))
	_check(moves.is_empty(), "the stick: a thumb coming down does not move the hero")
	_drag_to(stick, 0, Vector2(200, 300 - stick.RADIUS * 0.1))
	_check(moves.is_empty(), "nor does a thumb that barely shifts")
	_drag_to(stick, 0, Vector2(200, 300 - stick.RADIUS))
	_check(moves.size() == 1 and moves[-1].is_equal_approx(Vector2(0, -1)), "pushing up is walking forward")
	_drag_to(stick, 0, Vector2(200, 300 + stick.RADIUS))
	_check(moves[-1].is_equal_approx(Vector2(0, 1)), "pulling down is walking backwards")
	_drag_to(stick, 0, Vector2(200 + stick.RADIUS * 3.0, 300))
	_check(moves[-1].is_equal_approx(Vector2(1, 0)), "a thumb past the rim gives a full push, sideways here")
	_drag_to(stick, 0, Vector2(200 + stick.RADIUS * 2.0, 300))
	_check(moves[-1] == Vector2.ZERO, "and the stick has followed it: a short move back is back to the middle")
	_drag_to(stick, 0, Vector2(200 + stick.RADIUS * 2.0, 300 - stick.RADIUS))
	var moves_before: int = moves.size()
	_touch_at(stick, 1, true, Vector2(50, 50))
	_drag_to(stick, 1, Vector2(50, 400))
	_touch_at(stick, 1, false, Vector2(50, 400))
	_check(moves.size() == moves_before and moves[-1].is_equal_approx(Vector2(0, -1)), "a second finger does not take the stick over")
	_touch_at(stick, 0, false, Vector2.ZERO)
	_check(moves[-1] == Vector2.ZERO, "lifting the thumb stops")
	_drag_to(stick, 0, Vector2(0, 0))
	_check(moves[-1] == Vector2.ZERO, "and nothing moves after that")

	# --- Settings (GameSettings): each one steps through its values and survives a reload ---
	GameSettings.settings_path = "user://test_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.settings_path))
	GameSettings.touch_scheme = 0.0
	_check(not GameSettings.one_finger(), "touch controls are two thumbs unless chosen otherwise")
	GameSettings.cycle("touch_scheme")
	_check(GameSettings.one_finger(), "and one finger is a setting")
	GameSettings.cycle("touch_scheme")
	GameSettings.look_sensitivity = 1.0
	GameSettings.subtitle_scale = 1.0
	GameSettings.volume = 1.0
	_check(is_equal_approx(GameSettings.cycle("look_sensitivity"), 1.25), "the look sensitivity steps up")
	_check(is_equal_approx(GameSettings.cycle("volume"), 0.0) and AudioServer.is_bus_mute(0), "the volume wraps round to silence and mutes the output")
	GameSettings.cycle("volume")
	_check(not AudioServer.is_bus_mute(0) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.25), "the next step is audible again, at a quarter")
	GameSettings.cycle("subtitle_scale")
	GameSettings.look_sensitivity = 1.0
	GameSettings.subtitle_scale = 1.0
	GameSettings.load_settings()
	_check(is_equal_approx(GameSettings.look_sensitivity, 1.25) and is_equal_approx(GameSettings.subtitle_scale, 1.3), "settings are read back from disk")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.settings_path))

	print("==================================================")
	if errors > 0:
		print("❌ FAILED with ", errors, " error(s).")
		get_tree().quit(1)
	else:
		print("✅ Touch controls work.")
		get_tree().quit(0)
