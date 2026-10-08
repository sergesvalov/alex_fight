# scripts/ui/terminal_ui.gd
# Fallout-style terminal: dark screen, green text, a navigable list of entries on the left and
# the selected entry's full text on the right. The archive entries are the same shared content
# on every floor's CRT terminal (crt_terminal.gd just opens this); the one entry on top of them
# is live - an inventory of the tapes still lying around on the floor the player is on.
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
	# Slot 0 is the live tape inventory - a placeholder here, filled in by open().
	entries = [{"title": "", "text": ""}] + DialogSystem.terminal_entries
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

# Where to look for the tapes not yet picked up on the current floor - roughly ("a table in one
# of the rooms"), never which room. Read straight off the cassettes that are still in the level,
# so it can't disagree with what is actually there.
func _tape_inventory_entry() -> Dictionary:
	var floor_num: int = GameStateManager.current_floor
	var lines: Array = []
	var generator = get_tree().get_first_node_in_group("level_generator")
	var floor_node: Node = generator.get_floor_node(floor_num) if generator else null
	if floor_node:
		for child in floor_node.get_children():
			if child.name.begins_with("Cassette_") and not child.is_queued_for_deletion():
				var hint_key: String = child.location_hint if child.location_hint != "" else "tape_hint_unknown"
				# No tape numbers here: which recording a cassette turns out to be depends on
				# the order of finding (vhs_tape.gd), not on where it lies.
				lines.append(UIStrings.get_string("terminal_tapes_line") % UIStrings.get_string(hint_key))
	lines.sort()
	var text: String = UIStrings.get_string("terminal_tapes_none")
	if not lines.is_empty():
		text = UIStrings.get_string("terminal_tapes_intro") + "\n\n" + "\n".join(lines)
	return {"title": UIStrings.get_string("terminal_tapes_title") % floor_num, "text": text}

# An archive entry stays classified until enough tapes have been recovered (its "requires_tapes"
# in narrative_lines.json, counted over the whole game) - the terminal confirms what Alex has
# remembered instead of telling him everything on the first floor.
func _is_locked(i: int) -> bool:
	if entries[i].get("lab", false):
		return not GameStateManager.lab_reached # the lab's own documents: only from down there
	return GameStateManager.collected_tapes.size() < int(entries[i].get("requires_tapes", 0))

func open() -> void:
	entries[0] = _tape_inventory_entry()
	for i in range(entries.size()):
		(entry_list.get_child(i) as Button).text = UIStrings.get_string("terminal_locked_title") if _is_locked(i) else entries[i]["title"]
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var first_btn: Button = entry_list.get_child(0)
	first_btn.button_pressed = true
	first_btn.grab_focus()
	_show_entry(0)

func close() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _show_entry(i: int) -> void:
	if _is_locked(i):
		body_text.text = UIStrings.get_string("terminal_locked_text") % [
			int(entries[i].get("requires_tapes", 0)), GameStateManager.collected_tapes.size()]
		return
	body_text.text = "[b]" + entries[i]["title"] + "[/b]\n\n" + entries[i]["text"]
