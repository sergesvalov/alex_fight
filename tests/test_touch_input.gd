extends Node

# Checks the one-finger touch controls (scripts/ui/one_finger_input.gd): a short still touch is
# a tap, a held one walks, dragging turns, and a second finger can tap while the first holds.
#
# Run via: godot --headless tests/test_touch_input.tscn

var errors: int = 0
var taps: int = 0
var walk_events: Array = []
var turned: Vector2 = Vector2.ZERO

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

func _ready() -> void:
	print("==================================================")
	print("  AUTOTEST: ONE-FINGER TOUCH CONTROLS")
	print("==================================================")
	var zone := Control.new()
	zone.set_script(load("res://scripts/ui/one_finger_input.gd"))
	add_child(zone)
	zone.tapped.connect(func(): taps += 1)
	zone.walk_changed.connect(func(walking): walk_events.append(walking))
	zone.swipe_dragged.connect(func(relative): turned += relative)

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
	_check(taps == 2 and turned == Vector2(60, 5), "a quick swipe turns and is not a tap")

	print("==================================================")
	if errors > 0:
		print("❌ FAILED with ", errors, " error(s).")
		get_tree().quit(1)
	else:
		print("✅ Touch controls work.")
		get_tree().quit(0)
