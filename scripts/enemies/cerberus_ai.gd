# scripts/enemies/cerberus_ai.gd
# The "Cerberus" security robot - a ranged laser attacker. All the shared FSM/navigation/
# detection plumbing lives in enemy_ai_base.gd; this only adds what's actually specific to this
# enemy: the weapon visual/audio and the ranged attack itself.
class_name CerberusAI
extends "res://scripts/enemies/enemy_ai_base.gd"

@onready var weapon_beam: MeshInstance3D = $RobotBody/Weapon/WeaponBeam
@onready var audio: AudioStreamPlayer3D = $AudioStreamPlayer3D

var shoot_sound = preload("res://assets/audio/sfx/shoot.wav")

func _ready() -> void:
	# Ranged (a security robot with a laser rifle, not a melee creature) - engages from across a
	# room/corridor instead of needing to close to point-blank range. Overrides
	# enemy_ai_base.gd's generic melee-ish @export defaults with plain assignment rather than
	# re-declaring the same @export vars here, which would risk GDScript variable-shadowing
	# ambiguity between the two declarations for no real benefit (nothing currently needs to
	# tweak Cerberus's own numbers from the Inspector independently of this script).
	idle_wait_time = 2.0
	patrol_speed = 3.0
	chase_speed = 6.5
	attack_range = 10.0
	attack_damage = 15
	attack_cooldown = 1.2

	var c_scale = GlobalConfig.player_height / 1.6
	scale = Vector3(c_scale, c_scale, c_scale)

	# Sub-resources loaded from a .tscn are shared across every instance of that scene by
	# default - with 10 floors each spawning their own robot, mutating weapon_beam.mesh directly
	# would resize every other robot's beam too (same gotcha laser_pistol.gd already works around
	# for the player's own beam_mesh).
	if weapon_beam and weapon_beam.mesh:
		weapon_beam.mesh = weapon_beam.mesh.duplicate()

	super._ready()

# Ranged attack - unlike a plain melee bite, a wall between the robot and the player must
# actually block the shot, not just distance.
func _perform_attack() -> void:
	if not sensors.has_line_of_sight(player):
		return

	_fire_laser()
	if player.has_method("take_damage"):
		player.take_damage(attack_damage)
		print(name, " attacked player for ", attack_damage)

func _fire_laser() -> void:
	if audio:
		audio.stream = shoot_sound
		audio.play()

	if not weapon_beam or not is_instance_valid(player):
		return

	var distance: float = weapon_beam.get_parent().global_position.distance_to(player.global_position)
	weapon_beam.mesh.height = distance
	weapon_beam.position.z = -distance / 2.0
	weapon_beam.scale = Vector3(1, 1, 1)
	weapon_beam.show()

	# Shrinks the beam's cross-section (local X/Z) to a point while keeping its length (local Y,
	# which the node's baked -90deg X rotation maps to world -Z) - same fade laser_pistol.gd
	# uses for the player's own beam.
	var tween := create_tween()
	tween.tween_property(weapon_beam, "scale", Vector3(0, 0, 1), 0.15)
	tween.tween_callback(weapon_beam.hide)
