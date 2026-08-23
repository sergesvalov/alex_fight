# scripts/levels/blocks/stairs_gate.gd
# Sits at one floor's own stairwell doorway - South Stairs' single SouthStairsDoor, or North
# Stairs' DoorEast/DoorWest (both at that floor's own ground level; see AGENTS.md "North Stairs
# Block Map" for why a floor's "upper exit" is physically the next floor's own low door). All 10
# floors are stacked in one scene and their stairwells physically connect (see AGENTS.md "Level
# Instancing & 10 Floors"), so simply climbing a stairwell lets a player walk straight from floor
# N into floor N+1's corridor through one of these doors - normally not allowed.
#
# If the player steps through a gate whose floor_num differs from GameStateManager.current_floor,
# that's a floor-hop attempt: it's teleported straight back to current_floor (same X/Z, shifted
# by exactly one floor-to-floor height) unless floor_num falls inside
# GameStateManager.[unlocked_floor_min, unlocked_floor_max] (see GameStateManager's "FLOOR ACCESS"
# section), in which case the hop is allowed and current_floor updates to match. Collecting all 3
# tapes on the CURRENT floor does NOT by itself widen this range - only actually reaching a new
# floor through the secret exit door does (see hotel_level_generator.gd's _create_exit_portal()).
extends Area3D

var floor_num: int = 0
var y_step: float = 4.5

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.name != "Player":
		return
	if floor_num == GameStateManager.current_floor:
		return
	if GameStateManager.is_floor_unlocked(floor_num):
		GameStateManager.current_floor = floor_num
		return
	DialogSystem.trigger_alex_line("endless_corridor")
	body.global_position.y += (GameStateManager.current_floor - floor_num) * y_step
