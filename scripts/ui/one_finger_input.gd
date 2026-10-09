# scripts/ui/one_finger_input.gd
# Touch controls with nothing to learn and no joystick. One finger does everything:
#
#   drag           - turn (the camera follows the finger, left and right)
#   hold           - walk forward, the way you are facing, for as long as the finger is down;
#                    dragging while holding steers
#   tap            - shoot
#   flick down     - turn round on the spot
#
# There is no walking backwards - turn round. A second finger tapping while the first one holds
# shoots without stopping.
#
# It replaces the old pair of zones - a virtual joystick on the left half of the screen and a
# swipe-to-look area on the right, with a double tap to shoot. Both of those zones in hud.tscn
# now carry this script, so the whole screen behaves the same wherever it is touched;
# player_controller.gd listens to both.
extends Control

signal swipe_dragged(relative: Vector2)  # finger moved: turn by this much (pixels)
signal walk_changed(walking: bool)       # the hold started / the finger came up
signal tapped                            # a short touch that did not move: shoot
signal turned_around                     # a quick flick straight down: face the other way

const HOLD_DELAY: float = 0.18   # a touch shorter than this is a tap, not the start of a walk
const TAP_MAX_TIME: float = 0.25
const TAP_MAX_MOVE: float = 24.0 # pixels a finger may wander and still count as a tap
# A flick down: short, mostly vertical, and long enough not to be a shaky tap. The view only
# turns left and right on touch, so a vertical stroke means nothing else.
const FLICK_MAX_TIME: float = 0.35
const FLICK_MIN_DOWN: float = 90.0

var _main_touch: int = -1        # the finger that turns and walks
var _held_for: float = 0.0
var _moved: float = 0.0
var _travel: Vector2 = Vector2.ZERO # where the main finger has got to since it came down
var _walking: bool = false
var _other_touches: Dictionary = {} # index -> [seconds down, pixels moved]: extra fingers, taps only

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _main_touch == -1:
				_main_touch = event.index
				_held_for = 0.0
				_moved = 0.0
				_travel = Vector2.ZERO
				set_process(true)
			else:
				_other_touches[event.index] = [0.0, 0.0]
		elif event.index == _main_touch:
			var was_tap: bool = not _walking and _held_for <= TAP_MAX_TIME and _moved <= TAP_MAX_MOVE
			var was_flick: bool = _held_for <= FLICK_MAX_TIME and _travel.y >= FLICK_MIN_DOWN and _travel.y > absf(_travel.x) * 2.0
			_main_touch = -1
			_set_walking(false)
			set_process(not _other_touches.is_empty())
			if was_tap:
				tapped.emit()
			elif was_flick:
				turned_around.emit()
		elif _other_touches.has(event.index):
			var touch: Array = _other_touches[event.index]
			_other_touches.erase(event.index)
			if touch[0] <= TAP_MAX_TIME and touch[1] <= TAP_MAX_MOVE:
				tapped.emit()
	elif event is InputEventScreenDrag:
		if event.index == _main_touch:
			_moved += event.relative.length()
			_travel += event.relative
			swipe_dragged.emit(event.relative)
		elif _other_touches.has(event.index):
			_other_touches[event.index][1] += event.relative.length()

func _process(delta: float) -> void:
	for index in _other_touches:
		_other_touches[index][0] += delta
	if _main_touch == -1:
		return
	_held_for += delta
	if not _walking and _held_for >= HOLD_DELAY:
		_set_walking(true)

func _set_walking(walking: bool) -> void:
	if walking != _walking:
		_walking = walking
		walk_changed.emit(walking)
