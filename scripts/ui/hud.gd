extends CanvasLayer

@onready var health_bar = $GameHUD/HealthBar
@onready var heat_bar = $GameHUD/HeatBar
@onready var tapes_counter = $GameHUD/TapesCounter

func _ready() -> void:
    if EventBus.has_signal("player_health_changed"):
        EventBus.player_health_changed.connect(_on_health_changed)
    if EventBus.has_signal("tapes_collected_updated"):
        EventBus.tapes_collected_updated.connect(_on_tapes_updated)
    if EventBus.has_signal("heat_updated"):
        EventBus.heat_updated.connect(_on_heat_updated)

func _on_health_changed(current: int, max_hp: int) -> void:
    if health_bar:
        health_bar.max_value = max_hp
        health_bar.value = current

func _on_tapes_updated(current: int, max_tapes: int) -> void:
    if tapes_counter:
        tapes_counter.text = "Tapes: " + str(current) + "/" + str(max_tapes)

func _on_heat_updated(current: float) -> void:
    if heat_bar:
        heat_bar.value = current
