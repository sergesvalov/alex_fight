extends CanvasLayer

@onready var narrative_text: RichTextLabel = find_child("NarrativeText", true, false)
@onready var narrative_backdrop: Control = find_child("NarrativeBackdrop", true, false)

func _ready() -> void:
    var inv_btn = find_child("InventoryButton", true, false)
    var inv_ui = find_child("InventoryUI", true, false)
    if inv_btn and inv_ui:
        inv_btn.pressed.connect(inv_ui.open)

    # Cassette text now shows as a screen-space subtitle instead of a world-space Label3D
    # floating over the hologram - reading it no longer depends on the room's ceiling height or
    # where the player happened to be standing when they picked the tape up.
    DialogSystem.narrative_started.connect(_on_narrative_started)
    DialogSystem.narrative_ended.connect(_on_narrative_ended)

    # DialogSystem.show_thought() (short ambient "Anomaly whisper" lines - mirrors, the new
    # per-floor portal decoration, etc.) has existed since early in the project but was never
    # actually connected to anything - it emitted EventBus.narrative_thought_requested into the
    # void. Reuses the same subtitle bar as cassette playback, just with a fixed short duration
    # instead of waiting for DialogSystem.narrative_ended.
    if EventBus.has_signal("narrative_thought_requested"):
        EventBus.narrative_thought_requested.connect(_on_thought_requested)

var _thought_token: int = 0

func _on_thought_requested(text: String, duration: float) -> void:
    if not narrative_text or DialogSystem.is_playing:
        return
    _thought_token += 1
    var my_token = _thought_token
    narrative_text.text = "[center]" + text + "[/center]"
    narrative_text.visible = true
    if narrative_backdrop:
        narrative_backdrop.visible = true
    await get_tree().create_timer(duration).timeout
    # Only hide it if nothing newer (another thought, or a real tape) took over meanwhile.
    if my_token == _thought_token and not DialogSystem.is_playing:
        narrative_text.visible = false
        if narrative_backdrop:
            narrative_backdrop.visible = false

func _on_narrative_started(tape: Dictionary) -> void:
    _thought_token += 1 # invalidate any pending thought's auto-hide - the tape owns the bar now
    if not narrative_text:
        return
    var title = tape.get("title", "")
    var text = tape.get("text", "")
    narrative_text.text = "[center][b]" + title + "[/b]\n" + text + "[/center]"
    narrative_text.visible = true
    if narrative_backdrop:
        narrative_backdrop.visible = true

func _on_narrative_ended() -> void:
    if narrative_text:
        narrative_text.visible = false
    if narrative_backdrop:
        narrative_backdrop.visible = false
