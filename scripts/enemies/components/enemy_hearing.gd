class_name EnemyHearing
extends RefCounted

const HEARING_RADIUS: float = 25.0

var ai
var enabled: bool = true

func _init(p_ai):
	ai = p_ai

func hear_noise(noise_position: Vector3) -> void:
	if not enabled:
		return
	var sm = ai.state_machine
	if sm.current_state_name in ["DEAD", "CHASE", "ATTACK"]:
		return
	if ai.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	if absf(noise_position.y - ai.global_position.y) > EnemySensors.SAME_FLOOR_Y_TOLERANCE:
		return
	if ai._flat_distance(noise_position) > HEARING_RADIUS:
		return
	if GameStateManager.current_state == GameStateManager.GameState.SPECTATOR:
		return
		
	print("[EnemyHearing] ", ai.name, " heard a noise at ", noise_position, " - going to look")
	ai._noise_position = noise_position
	sm.change_state("INVESTIGATE")
