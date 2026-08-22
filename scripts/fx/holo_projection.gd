# scripts/fx/holo_projection.gd
extends Node3D

@onready var label: Label3D = $Label3D
var data = {}

func set_tape_data(tape_data: Dictionary) -> void:
    data = tape_data
    print("[holo_projection] set_tape_data label=", label, " data=", data)
    if label:
        var title = data.get("title", "")
        var text = data.get("text", "")
        label.text = "[ " + title + " ]\n" + text
        print("[holo_projection] label.text set to: ", label.text)
    else:
        push_error("[holo_projection] Label3D node not found - no text will show")
