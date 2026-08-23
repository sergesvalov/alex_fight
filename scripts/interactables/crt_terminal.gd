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
	# Diagnostic prints (2026-08-23) - user reported seeing a single line of terminal text
	# instead of the Fallout-style menu (terminal_ui.gd). Current source only ever calls
	# terminal_ui.open() here, never show_thought()/a subtitle line - the leading theory is a
	# stale exported build predating the TerminalUI rewrite (same root cause already confirmed
	# once this session for the elevator geometry). These prints make that provable from a log:
	# if "open() called" never appears but text still shows, the running build's crt_terminal.gd
	# itself is stale, not this one.
	print("[CRTTerminal] ", name, " interact() called")
	var hud = get_tree().current_scene.find_child("HUD", true, false)
	if not hud:
		print("[CRTTerminal]   HUD not found under current_scene")
		return
	print("[CRTTerminal]   HUD found: ", hud.get_path())
	var terminal_ui = hud.find_child("TerminalUI", true, false)
	if not terminal_ui:
		print("[CRTTerminal]   TerminalUI node not found under HUD - hud.tscn is missing it")
		return
	if not terminal_ui.has_method("open"):
		print("[CRTTerminal]   TerminalUI found at ", terminal_ui.get_path(),
			" but has no open() method - wrong script attached?")
		return
	print("[CRTTerminal]   TerminalUI found at ", terminal_ui.get_path(), " - calling open()")
	terminal_ui.open()
	print("[CRTTerminal]   open() called")
