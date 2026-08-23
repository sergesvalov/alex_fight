# scripts/interactables/elevator_panel_display.gd
# Covers the WHOLE elevator button panel (all 5 rows) with one big interact target, so aiming
# anywhere at the panel opens the 2D on-screen floor display instead of needing to hit one
# specific tiny ElevatorButton. This exists because mobile locks the camera to horizontal-only
# look (player_camera.gd::process_swipe()) - the physical buttons are spread across ~0.6m of
# vertical panel space, which a mobile player can never tilt their aim to reach beyond whichever
# single row happens to line up with their fixed eye height. Sits recessed slightly behind the
# physical buttons (see elevator_shaft.tscn) so a precise aim on desktop/VR still hits the real
# button first; this only catches everything else on the panel face.
extends StaticBody3D

func interact(_player: Node) -> void:
	var hud = get_tree().current_scene.find_child("HUD", true, false)
	if not hud:
		return
	var panel_ui = hud.find_child("ElevatorPanelUI", true, false)
	if not panel_ui or not panel_ui.has_method("open"):
		return
	var controller = get_parent().get_parent()
	panel_ui.open(controller)
