extends Label

const COLOR_NORMAL := Color(1, 1, 1)
const COLOR_COMPLETE := Color(1.0, 0.78, 0.35) # all of the floor's tapes found

var _shown_count: int = -1

func _ready() -> void:
    EventBus.tapes_collected_updated.connect(_on_tapes_updated)
    # Show the real count straight away - the next update only comes with the next pickup or
    # floor change, and until then this label would sit on its scene-authored placeholder.
    _on_tapes_updated(GameStateManager.tapes_found.size(), GameStateManager.TAPES_PER_FLOOR)

func _on_tapes_updated(current: int, max_tapes: int) -> void:
    text = UIStrings.get_string("tapes_counter_format") % [current, max_tapes]
    modulate = COLOR_COMPLETE if current >= max_tapes else COLOR_NORMAL
    # A pickup should be felt, not just change a digit in the corner: the counter jumps.
    # Only when the count actually went up - not on the initial fill or when changing floors.
    if _shown_count >= 0 and current > _shown_count:
        pivot_offset = Vector2(size.x, size.y / 2.0) # grows leftward - it sits against the screen's right edge
        scale = Vector2(1.5, 1.5)
        create_tween().tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _shown_count = current
