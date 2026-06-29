# scripts/fx/holo_projection.gd
extends Node3D

@onready var label: Label3D = $Label3D
var data = {}

func set_tape_data(tape_data: Dictionary) -> void:
    data = tape_data
    if label:
        var title = data.get("title", "")
        var text = data.get("text", "")
        label.text = "[ " + title + " ]\n" + text
