# scripts/ui/relative_touch_input.gd
class_name RelativeTouchInput
extends Control

signal input_vector_changed(vector: Vector2)

@export var dead_zone: float = 10.0
@export var max_radius: float = 150.0

var touch_index: int = -1
var start_position: Vector2 = Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and touch_index == -1:
            touch_index = event.index
            start_position = event.position
        elif not event.pressed and event.index == touch_index:
            touch_index = -1
            input_vector_changed.emit(Vector2.ZERO)
            
    elif event is InputEventScreenDrag:
        if event.index == touch_index:
            var offset: Vector2 = event.position - start_position
            if offset.length() < dead_zone:
                input_vector_changed.emit(Vector2.ZERO)
            else:
                var clamped: Vector2 = offset.limit_length(max_radius)
                input_vector_changed.emit(clamped / max_radius)
