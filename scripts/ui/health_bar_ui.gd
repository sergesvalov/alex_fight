extends ProgressBar

func _ready() -> void:
    if EventBus.has_signal("player_health_changed"):
        EventBus.player_health_changed.connect(_on_health_changed)

func _on_health_changed(current: int, max_hp: int) -> void:
    max_value = max_hp
    value = current
