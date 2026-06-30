extends Label

var tween: Tween = null

func _ready() -> void:
    modulate.a = 0.0
    if EventBus.has_signal("narrative_thought_requested"):
        EventBus.narrative_thought_requested.connect(_on_thought_requested)

func _on_thought_requested(thought_text: String, duration: float) -> void:
    if tween:
        tween.kill()
    
    text = thought_text
    visible = true
    modulate.a = 0.0
    
    tween = create_tween()
    tween.tween_property(self, "modulate:a", 1.0, 0.5)
    tween.tween_interval(duration)
    tween.tween_property(self, "modulate:a", 0.0, 1.0)
    tween.tween_callback(func(): visible = false)
