class_name SwipeLookInput
extends Control

signal swipe_dragged(relative: Vector2)

var touch_index: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			touch_index = event.index
		elif not event.pressed and event.index == touch_index:
			touch_index = -1
	elif event is InputEventScreenDrag:
		if event.index == touch_index:
			swipe_dragged.emit(event.relative)