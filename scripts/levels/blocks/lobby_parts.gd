# scripts/levels/blocks/lobby_parts.gd
# The three live pieces of the ground-floor lobby (hotel_level_generator.gd::_build_lobby()).
# One script, three roles picked by `role`, because each is a handful of lines:
#
#   "turrets"  - Area3D filling the corridor to the main entrance. Whoever walks in under the
#                ceiling turrets is put back by the lobby's elevator, every time - no rule to
#                learn and no way through, because the way out of the hotel is not this
#                door. Same "you are returned, not killed" as every floor's trap.
#   "lift"     - Area3D on the panel of the second lift, the one that goes underground. It
#                takes the service code from the roof (GameStateManager.lobby_unlocked). The
#                levels below do not exist yet, so for now the code is accepted and the car
#                simply has not arrived.
#   "creature" - Node3D inside the aquarium: a dark shape drifting slowly back and forth in
#                glowing water, never quite visible.
extends Node3D

var role: String = ""
var return_position: Vector3 = Vector3.ZERO   # "turrets": where the player is put back (global)
var swim_half_length: float = 2.2             # "creature": how far it drifts either side

const SHOT_SOUND: AudioStream = preload("res://assets/audio/sfx/shoot.wav")
var _swim_time: float = 0.0
var _swim_origin: Vector3 = Vector3.ZERO

func _ready() -> void:
	if role == "turrets":
		connect("body_entered", _on_turret_zone_entered)
	if role == "creature":
		_swim_origin = position
		_swim_time = randf() * 20.0
	set_process(role == "creature")

func _on_turret_zone_entered(body: Node) -> void:
	if body.name != "Player" or GameStateManager.current_state == GameStateManager.GameState.SPECTATOR:
		return
	print("[Lobby] turrets caught the player at ", body.global_position,
		" - returning to ", return_position)
	for i in range(3):
		AudioManager.play_sfx(SHOT_SOUND, body.global_position, 0.7 + 0.1 * i)
	body.global_position = return_position
	if "velocity" in body:
		body.velocity = Vector3.ZERO
	DialogSystem.show_thought(UIStrings.get_string("lobby_turret_return"), 6.0)

# "lift": called by the player's interact ray.
func interact(_player: Node) -> void:
	if role != "lift":
		return
	if not GameStateManager.lobby_unlocked:
		DialogSystem.show_thought(UIStrings.get_string("lobby_lift_no_code"), 5.0)
		return
	GameStateManager.lower_lift_called = true
	print("[Lobby] lower lift: code ", GameStateManager.lift_code, " accepted - nothing below to arrive yet")
	DialogSystem.show_thought(UIStrings.get_string("lobby_lift_code_ok") % GameStateManager.lift_code, 6.0)

func _process(delta: float) -> void:
	# Slow, uneven drift along the tank with a little rise and fall, turning to face its way.
	_swim_time += delta
	var along: float = sin(_swim_time * 0.23) * 0.7 + sin(_swim_time * 0.071) * 0.3
	position = _swim_origin + Vector3(0, sin(_swim_time * 0.31) * 0.35, along * swim_half_length)
	rotation.y = 0.0 if cos(_swim_time * 0.23) >= 0.0 else PI
