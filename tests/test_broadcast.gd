extends Node

# Checks the broadcast screens (broadcast_screen.gd) - the face on the corridor wall:
#   - every residential floor has one, it can be interacted with, and it has its own address
#   - the hero's reaction is "I know this face" before floor 8 and the man's name after it
#   - once the installation is stopped the screens are dark and say nothing
#
# Run via: godot --headless tests/test_broadcast.tscn

var errors: int = 0
var _thoughts: Array = []

func _check(ok: bool, label: String) -> void:
	if ok:
		print("✅ PASS: ", label)
	else:
		print("❌ FAIL: ", label)
		errors += 1

func _ready() -> void:
	print("==================================================")
	print("  AUTOTEST: BROADCAST SCREENS")
	print("==================================================")
	SaveManager.save_path = "user://test_savegame.json"
	SaveManager.new_game()
	EventBus.narrative_thought_requested.connect(func(text, _duration): _thoughts.append(text))

	var generator := Node3D.new()
	generator.set_script(load("res://scripts/levels/hotel_level_generator.gd"))
	add_child(generator)
	await get_tree().process_frame

	var lines: Dictionary = {}
	var all_present: bool = true
	for f in range(2, 11):
		var screen = generator.get_floor_node(f).get_node_or_null("PropagandaScreen/Broadcast")
		if screen == null or screen.collision_layer != 4 or DialogSystem.broadcasts.get(str(f), "") == "":
			all_present = false
			print("   floor ", f, ": screen=", screen, " line=\"", DialogSystem.broadcasts.get(str(f), ""), "\"")
			continue
		lines[DialogSystem.broadcasts[str(f)]] = true
	_check(all_present, "floors 2-10 each have an interactable screen with an address")
	_check(lines.size() == 9, "every floor's address is different")

	var screen4 = generator.get_floor_node(4).get_node("PropagandaScreen/Broadcast")
	screen4.interact(null)
	_check(_thoughts.size() == 1 and _thoughts[0].contains(DialogSystem.broadcasts["4"]), "interacting plays the floor's address")
	await get_tree().create_timer(screen4.LINE_SECONDS + 0.5).timeout
	_check(_thoughts.size() == 2 and _thoughts[1] == DialogSystem.alex_lines["screen_first"], "then the hero says he knows the face")

	_thoughts.clear()
	GameStateManager.collected_tapes.append({"floor": 8, "id": 0})
	screen4.interact(null)
	await get_tree().create_timer(screen4.LINE_SECONDS + 0.5).timeout
	_check(_thoughts.size() == 2 and _thoughts[1] == DialogSystem.alex_lines["screen_recognized"], "with his name back (a floor-8 tape) he names the man")

	_thoughts.clear()
	GameStateManager.lab_consoles_off = 3
	await get_tree().process_frame
	await get_tree().process_frame
	var mesh: MeshInstance3D = screen4.get_parent()
	_check(mesh.mesh.material.emission_energy_multiplier == 0.0 and not mesh.is_processing(), "with the installation stopped the screen is dark and stays dark")
	screen4.interact(null)
	_check(_thoughts.size() == 1 and _thoughts[0] == UIStrings.get_string("broadcast_dark"), "a dark screen plays nothing")

	SaveManager.active = false
	SaveManager.delete_save()
	print("==================================================")
	if errors > 0:
		print("❌ FAILED with ", errors, " error(s).")
		get_tree().quit(1)
	else:
		print("✅ Broadcast screens work.")
		get_tree().quit(0)
