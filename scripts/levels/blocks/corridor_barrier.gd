# scripts/levels/blocks/corridor_barrier.gd
# Splits floor 3's main corridor in half: until floor 3's own 3 tapes are collected, the elevator
# and North Stairs (north end of the corridor) are off-limits - crossing this trigger bounces the
# player back to return_z, a point halfway between here and the South Stairs end, same idea as
# stairs_gate.gd's floor-hop bounce (just along Z instead of Y). The South Stairs door stays
# reachable from the south side regardless.
# Moved here from floor 4 (2026-08-23, corrected per user report): floor 4 is the starting floor
# and is meant to be fully open, no corridor gating at all - this "endless corridor" nightmare
# belongs to floor 3, the floor reached through the secret door, not the start.
# Becomes a permanent no-op the instant GameStateManager.floor3_corridor_unlocked flips true (set
# in hotel_level_generator.gd's _on_all_tapes_collected() once floor 3's own tapes are done) - the
# node itself is never removed, this script just stops acting on it.
extends Area3D

var return_z: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.name != "Player":
		return
	if GameStateManager.floor3_corridor_unlocked:
		return
	# Diagnostic (2026-08-23) - see stairs_gate.gd's matching print for why.
	print("[CorridorBarrier] ", name, " bouncing player from z=", body.global_position.z,
		" to return_z=", return_z)
	DialogSystem.trigger_alex_line("endless_corridor")
	body.global_position.z = return_z
