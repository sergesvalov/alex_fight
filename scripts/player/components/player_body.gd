# scripts/player/components/player_body.gd
# The hero's own body as seen in first person: looking down shows a chest, legs and feet, and
# they swing while walking. Head and the right upper arm stay on render layer 2 (hidden from
# the player's own camera, see player.tscn's Camera3D cull_mask) - the camera sits inside the
# head, and the right arm is already on screen as the forearm holding the pistol.
extends Node3D

# One full left-right stride per two footsteps (player_movement.gd plays a step every 0.4s).
const STRIDE_TIME: float = 0.8
const LEG_SWING: float = 0.5   # radians at walk speed
const ARM_SWING: float = 0.3
const REFERENCE_SPEED: float = 3.5

@onready var player: CharacterBody3D = get_parent()
@onready var leg_l: Node3D = $LegL
@onready var leg_r: Node3D = $LegR
@onready var arm_l: Node3D = $ArmL

var _phase: float = 0.0
var _amount: float = 0.0   # 0 = standing, 1 = walking at REFERENCE_SPEED

func _process(delta: float) -> void:
	var flat_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var target: float = clampf(flat_speed / REFERENCE_SPEED, 0.0, 1.5) if player.is_on_floor() else 0.0
	_amount = move_toward(_amount, target, delta * 6.0)
	if _amount > 0.01:
		_phase = fmod(_phase + delta * TAU / STRIDE_TIME * maxf(_amount, 0.6), TAU)
	else:
		_phase = 0.0

	var swing: float = sin(_phase) * _amount
	leg_l.rotation.x = swing * LEG_SWING
	leg_r.rotation.x = -swing * LEG_SWING
	arm_l.rotation.x = -swing * ARM_SWING
