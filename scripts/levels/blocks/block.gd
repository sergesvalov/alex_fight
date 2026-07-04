extends Node3D

func _ready() -> void:
	if not Engine.is_editor_hint():
		GlobalConfig.apply_dynamic_scale(self)
