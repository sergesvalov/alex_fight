# scripts/ui/terminal_ui.gd
# Fallout-style terminal: dark screen, green text, a navigable list of entries on the left and
# the selected entry's full text on the right. Same shared content on every floor's CRT terminal
# (crt_terminal.gd just opens this) - it's meant to read as one archive, not per-floor content.
# Pauses the game like inventory_ui.gd (reading a wall of text isn't something you do mid-combat).
extends Panel

# Entries used to be a hardcoded const here - moved to assets/data/narrative_lines.json
# (2026-08-23), the same "content separate from code" convention tapes.json already established,
# loaded once by DialogSystem (which also owns the Alex reactive lines from that same file) so
# there's a single source of truth for this game's narrative text instead of two copies to keep
# in sync by hand.
var entries: Array = []

@onready var entry_list: VBoxContainer = $Margin/VBox/HBox/EntryList
@onready var body_text: RichTextLabel = $Margin/VBox/HBox/BodyPanel/BodyText
@onready var close_btn: Button = $Margin/VBox/CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(close)
	entries = DialogSystem.terminal_entries
	for i in range(entries.size()):
		var btn := Button.new()
		btn.text = entries[i]["title"]
		btn.toggle_mode = true
		btn.button_group = _entry_group()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_show_entry.bind(i))
		entry_list.add_child(btn)

func _entry_group() -> ButtonGroup:
	if not has_meta("_group"):
		set_meta("_group", ButtonGroup.new())
	return get_meta("_group")

func open() -> void:
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if entry_list.get_child_count() > 0:
		var first_btn: Button = entry_list.get_child(0)
		first_btn.button_pressed = true
		first_btn.grab_focus()
		_show_entry(0)

func close() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _show_entry(i: int) -> void:
	body_text.text = "[b]" + entries[i]["title"] + "[/b]\n\n" + entries[i]["text"]
