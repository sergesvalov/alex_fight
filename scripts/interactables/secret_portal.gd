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
		print("Teleporting player to: ", target_position)
		body.global_position = target_position
		if target_floor > 0:
			GameStateManager.unlock_floor(target_floor)
			GameStateManager.current_floor = target_floor
