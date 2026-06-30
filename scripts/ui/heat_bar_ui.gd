extends ProgressBar

func _ready() -> void:
    if EventBus.has_signal("heat_updated"):
        EventBus.heat_updated.connect(_on_heat_updated)

func _on_heat_updated(current: float) -> void:
    value = current
