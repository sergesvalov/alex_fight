extends Area3D

var target_position: Vector3 = Vector3.ZERO
# Which floor target_position is on - stepping through here is a genuine progression event, so
# it permanently widens GameStateManager's stairs-access range to include that floor (see
# GameStateManager's "FLOOR ACCESS" section). 0 = unset, skips the unlock (kept usable as a
# plain teleport-only portal if some future caller doesn't want that side effect).
var target_floor: int = 0

func _ready() -> void:
	collision_mask = 1 # Player layer
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body.has_method("teleport"):
		# Diagnostic (2026-08-23) - see stairs_gate.gd's matching print for why. target_floor
		# added here specifically because this is the one mechanism in the game that can land the
		# player on floor 3 unprompted (secret exit door - see _create_exit_portal(), currently
		# always floor 3) - relevant if a report ever describes ending up there unexpectedly.
		print("[SecretPortal] ", name, " teleporting player from ", body.global_position,
			" to ", target_position, " target_floor=", target_floor,
			" secret_portal_active=", GameStateManager.secret_portal_active)
		body.global_position = target_position
		if target_floor > 0:
			DialogSystem.trigger_alex_line("secret_portal")
			GameStateManager.unlock_floor(target_floor)
			GameStateManager.current_floor = target_floor
