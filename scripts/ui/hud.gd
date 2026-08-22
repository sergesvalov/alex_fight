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

func _on_narrative_started(tape: Dictionary) -> void:
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
