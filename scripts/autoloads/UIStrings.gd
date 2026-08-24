# scripts/autoloads/UIStrings.gd
# Single source of truth for the small UI-facing text that was scattered as string literals
# across scripts/ui/*.gd (tooltips, fallback labels, counters) - same "content separate from
# code" convention already used for tapes.json and narrative_lines.json (both loaded by
# DialogSystem.gd), just for copy that isn't a dialogue/narrative "event" line, kept in its own
# file+autoload rather than folded into either of those since it's a different kind of text
# (static UI chrome, not something triggered by a game event).
extends Node

var strings: Dictionary = {}

func _ready() -> void:
	var file = FileAccess.open("res://assets/data/ui_strings.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			strings = json.data
		else:
			push_error("Failed to parse ui_strings.json")
	else:
		push_error("Could not open ui_strings.json")

func get_string(key: String, fallback: String = "") -> String:
	return strings.get(key, fallback)
