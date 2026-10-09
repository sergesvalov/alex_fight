# scripts/ui/move_stick_input.gd
# The left thumb of the two-thumb touch scheme: a floating stick. It appears wherever the thumb
# comes down in its zone and gives the direction to walk in - forward, back and sideways. The
# right half of the screen (one_finger_input.gd with walk_on_hold off) turns and shoots.
#
# It gives a direction, not a speed: player_movement.gd walks at one pace. While nothing touches
# it, a faint ring in the corner shows that it is there - the wake-up room has no text to say so.
extends Control

signal moved(vector: Vector2)  # (0, -1) is forward, as player_movement.gd takes it; ZERO on release

const RADIUS: float = 90.0
const KNOB_RADIUS: float = 34.0
const DEAD_ZONE: float = 0.2                 # of RADIUS: a thumb resting on the glass does not walk
const REST_OFFSET := Vector2(170.0, -170.0)  # the idle ring, from the zone's bottom-left corner
const COLOR := Color(0.7, 1.0, 1.0)

var _touch: int = -1
var _origin: Vector2 = Vector2.ZERO  # where the stick's centre is while held
var _knob: Vector2 = Vector2.ZERO    # the thumb, relative to the centre
var _vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1:
			_touch = event.index
			_origin = event.position
			_knob = Vector2.ZERO
			queue_redraw()
		elif not event.pressed and event.index == _touch:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch:
		var offset: Vector2 = event.position - _origin
		# A thumb that slides past the rim drags the stick along, so reversing takes a short
		# move back and not the whole way across.
		_origin += offset - offset.limit_length(RADIUS)
		_knob = offset.limit_length(RADIUS)
		var vector: Vector2 = _knob / RADIUS
		_set_vector(vector if vector.length() >= DEAD_ZONE else Vector2.ZERO)
		queue_redraw()

# Hidden under a held thumb (a panel opened, the scheme changed): the release never arrives.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and _touch != -1:
		_release()

func _release() -> void:
	_touch = -1
	_knob = Vector2.ZERO
	_set_vector(Vector2.ZERO)
	queue_redraw()

func _set_vector(vector: Vector2) -> void:
	if vector != _vector:
		_vector = vector
		moved.emit(vector)

func _draw() -> void:
	var held: bool = _touch != -1
	var center: Vector2 = _origin if held else Vector2(REST_OFFSET.x, size.y + REST_OFFSET.y)
	draw_arc(center, RADIUS, 0.0, TAU, 48, Color(COLOR, 0.4 if held else 0.15), 3.0, true)
	draw_circle(center + _knob, KNOB_RADIUS, Color(COLOR, 0.35 if held else 0.1))
