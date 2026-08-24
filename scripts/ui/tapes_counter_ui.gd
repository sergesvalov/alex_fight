extends Label

func _ready() -> void:
    if EventBus.has_signal("tapes_collected_updated"):
        EventBus.tapes_collected_updated.connect(_on_tapes_updated)

func _on_tapes_updated(current: int, max_tapes: int) -> void:
    text = UIStrings.get_string("tapes_counter_format") % [current, max_tapes]
