extends Panel

# 9 furnished floors x 3 tapes = 27, rounded up to whole rows of the 6-column grid. (Was 25,
# which would have left the last two tapes with nowhere to go.)
const SLOT_COUNT = 30

@onready var grid = $ScrollContainer/GridContainer
@onready var close_btn = $CloseButton

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS # buttons must work while get_tree().paused
    _rebuild_slots()
    close_btn.pressed.connect(close)

# Cassette slots, sorted by lore order (floor, then id) - NOT by the order the player happened
# to pick them up in, so finding tape #3 before #1 still lists #1 first.
func _rebuild_slots() -> void:
    for child in grid.get_children():
        child.queue_free()

    var tapes = GameStateManager.collected_tapes.duplicate()
    tapes.sort_custom(func(a, b):
        if a["floor"] != b["floor"]:
            return a["floor"] < b["floor"]
        return a["id"] < b["id"]
    )

    for i in range(SLOT_COUNT):
        if i < tapes.size():
            grid.add_child(_make_tape_slot(tapes[i]))
        else:
            grid.add_child(_make_empty_slot())

func _make_empty_slot() -> Control:
    var slot = ColorRect.new()
    slot.custom_minimum_size = Vector2(90, 90)
    slot.color = Color(0.15, 0.15, 0.15, 0.9)

    var border = ReferenceRect.new()
    border.editor_only = false
    border.border_color = Color(0.4, 0.4, 0.4, 1)
    border.border_width = 2.0
    border.layout_mode = 1
    border.anchors_preset = 15
    border.anchor_right = 1.0
    border.anchor_bottom = 1.0
    slot.add_child(border)

    return slot

func _make_tape_slot(tape: Dictionary) -> Control:
    var btn = Button.new()
    btn.custom_minimum_size = Vector2(90, 90)
    btn.autowrap_mode = TextServer.AUTOWRAP_OFF
    # Full title never fits a 90x90 cell, so the button itself only shows a short slot label -
    # the full title (plus the replay hint) shows on hover via the tooltip instead.
    # Floor and number, e.g. "5-2" - every floor has its own tapes 1..3.
    btn.text = UIStrings.get_string("inventory_slot_format", "%d-%d") % [tape["floor"], tape["id"] + 1]
    btn.tooltip_text = _tape_title(tape["floor"], tape["id"]) + "\n\n" + UIStrings.get_string("inventory_replay_hint")
    btn.pressed.connect(func(): _replay_tape(tape["floor"], tape["id"]))
    return btn

func _tape_title(floor_num: int, tape_id: int) -> String:
    return DialogSystem.get_tape(floor_num, tape_id).get("title", UIStrings.get_string("inventory_tape_fallback") % (tape_id + 1))

func _replay_tape(floor_num: int, tape_id: int) -> void:
    var player = get_tree().current_scene.get_node_or_null("Player")
    if not player:
        return
    var spawn_pos = player.global_position
    close() # unpause first - play_tape_for_floor()'s timer doesn't run while paused
    DialogSystem.play_tape_for_floor(floor_num, tape_id, spawn_pos)

func open():
    _rebuild_slots() # pick up any tapes collected since the last time this was open
    show()
    # Pause the game while inventory is open
    get_tree().paused = true
    # Mouse was captured (invisible, locked to center, driving camera look) during normal
    # gameplay - without releasing it here, clicks never reach the slot buttons at all,
    # since there's no free cursor to point with.
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close():
    hide()
    # Resume the game
    get_tree().paused = false
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
