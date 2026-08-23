# scripts/interactables/crt_terminal.gd
# One of these stands in the corridor of every floor except 1 (empty_box_mode, no rooms at all)
# and the roof (not a floor) - see hotel_level_generator.gd's _add_floor_terminal(). Interacting
# opens a Fallout-style 2D terminal screen (terminal_ui.gd) with a navigable list of Sector-7
# archive entries - content that was written for LORE.md ("Текстовые логи в CRT-терминалах") but
# never actually reachable in-game. crt_screen.gdshader (the shader a proper CRT screen-distortion
# effect would have used) was deleted as unused dead code earlier in this same session, before
# this script existed to need it.
extends Area3D

func interact(_player: Node) -> void:
	var hud = get_tree().current_scene.find_child("HUD", true, false)
	if not hud:
		return
	var terminal_ui = hud.find_child("TerminalUI", true, false)
	if not terminal_ui or not terminal_ui.has_method("open"):
		return
	terminal_ui.open()
