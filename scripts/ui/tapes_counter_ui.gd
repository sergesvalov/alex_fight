extends Label

func _ready() -> void:
    EventBus.tapes_collected_updated.connect(_on_tapes_updated)
    # Show the real count straight away - the next update only comes with the next pickup or
    # floor change, and until then this label would sit on its scene-authored placeholder.
    _on_tapes_updated(GameStateManager.tapes_found.size(), GameStateManager.TAPES_PER_FLOOR)

func _on_tapes_updated(current: int, max_tapes: int) -> void:
    text = UIStrings.get_string("tapes_counter_format") % [current, max_tapes]
