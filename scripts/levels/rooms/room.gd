@tool
extends Node3D
class_name HotelRoom

@export var room_number: String = "":
    set(value):
        room_number = value
        _update_label()

func _ready() -> void:
    _update_label()

func _update_label() -> void:
    if has_node("RoomLabel"):
        var label = get_node("RoomLabel")
        if label is Label3D:
            label.text = room_number
