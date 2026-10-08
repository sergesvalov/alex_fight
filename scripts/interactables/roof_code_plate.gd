# scripts/interactables/roof_code_plate.gd
# The plate in the elevator machine room on the roof (hotel_level_generator.gd::
# _build_roof_structures()): the lift's service code. Reading it is what lets the elevator go to
# the first floor - GameStateManager.lobby_unlocked; elevator_controller.gd routes by
# is_floor_unlocked(), which answers for floor 1 from that flag alone. The code itself is
# rolled once per game (GameStateManager.lift_code) and shown on the plate.
extends Area3D

func _ready() -> void:
	var text: Label3D = get_node_or_null("Text")
	if text:
		text.text = UIStrings.get_string("roof_plate_format", "%s") % GameStateManager.lift_code

func interact(_player: Node) -> void:
	var first_time: bool = not GameStateManager.lobby_unlocked
	GameStateManager.lobby_unlocked = true
	print("[RoofCodePlate] lift code read (", GameStateManager.lift_code, "), first time=", first_time,
		" - the elevator now goes to floor 1")
	# Shown every time, not once: the player may want to read the code again.
	DialogSystem.show_thought(UIStrings.get_string("roof_code_found", "%s") % GameStateManager.lift_code, 5.0)
