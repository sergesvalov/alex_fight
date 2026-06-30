# scripts/ui/virtual_joystick.gd
class_name MobileVirtualJoystick
extends Control

signal input_vector_changed(vector: Vector2)

@export var dead_zone: float = 0.15
@export var max_radius: float = 60.0
@export var joystick_mode: JoystickMode = JoystickMode.DYNAMIC

enum JoystickMode {
    FIXED,     # Фиксированный центр
    DYNAMIC    # Центр появляется там, где нажали
}

var touch_index: int = -1
var base_position: Vector2 = Vector2.ZERO
var stick_position: Vector2 = Vector2.ZERO
var current_vector: Vector2 = Vector2.ZERO

@onready var base_circle: Control = $BaseCircle
@onready var stick_circle: Control = $StickCircle

func _ready() -> void:
    if base_circle: base_circle.hide()
    if stick_circle: stick_circle.hide()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        _handle_touch(event)
    elif event is InputEventScreenDrag:
        _handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
    if event.pressed and touch_index == -1:
        if _is_in_zone(event.position):
            touch_index = event.index
            base_position = event.position if joystick_mode == JoystickMode.DYNAMIC else get_rect().get_center()
            if base_circle:
                base_circle.global_position = base_position - base_circle.size / 2
                base_circle.show()
            if stick_circle:
                stick_circle.show()
    elif not event.pressed and event.index == touch_index:
        _release()

func _handle_drag(event: InputEventScreenDrag) -> void:
    if event.index != touch_index:
        return
    var offset: Vector2 = event.position - base_position
    var clamped: Vector2 = offset.limit_length(max_radius)
    stick_position = base_position + clamped
    if stick_circle:
        stick_circle.global_position = stick_position - stick_circle.size / 2
    
    current_vector = clamped / max_radius
    if current_vector.length() < dead_zone:
        current_vector = Vector2.ZERO
    input_vector_changed.emit(current_vector)

func _release() -> void:
    touch_index = -1
    current_vector = Vector2.ZERO
    if base_circle: base_circle.hide()
    if stick_circle: stick_circle.hide()
    input_vector_changed.emit(Vector2.ZERO)

func _is_in_zone(pos: Vector2) -> bool:
    return get_global_rect().has_point(pos)
