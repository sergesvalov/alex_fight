# scripts/enemies/sleeper_cerberus.gd
# Floor 6's nightmare, "the sleepers": Cerberus units standing motionless in the corridor with
# the eye dark. They are blind - they only HEAR. A loud sound (a tape playing, a shot) lights
# the eye and sends them walking to where it came from; they stand there turning for a moment
# and go back to their post. One that gets within arm's reach of the player while awake does
# not hurt him - it puts him back by the floor's elevator, the same "you are returned, not
# killed" every other floor's trap uses.
#
# The rule is fixed and observable (tape 603 spells it out: "it goes for the sound, not for me"):
# a tape cannot be taken quietly, so the question is where to play it and where to be afterwards.
# An already-found tape replayed from the inventory lures them away. Asleep they are shut tight
# and a shot does nothing but make noise; awake, one hit destroys them like any other Cerberus.
# Floor 6's own three tapes switch them all off for good (_switched_off()).
#
# Spawned only by hotel_level_generator.gd::_spawn_sleepers(), on cerberus.tscn with this
# script swapped in.
extends "res://scripts/enemies/cerberus_ai.gd"

const CATCH_DISTANCE: float = 1.3
const EYE_AWAKE_ENERGY: float = 3.0   # cerberus.tscn's own Mat_eye value
const EYE_ASLEEP_ENERGY: float = 0.0

# Where a caught player is put - in front of this floor's elevator. Set by the generator.
var return_position: Vector3 = Vector3.ZERO

# Name of the GameStateManager flag that switches this sleeper off for good - floor 6's by
# default; floor 2 reuses the sleepers with its own flag.
var off_flag: StringName = &"floor6_sleepers_off"

var _eye_material: StandardMaterial3D = null

func _switched_off() -> bool:
	return GameStateManager.get(off_flag) == true

func _ready() -> void:
	super._ready()
	can_see = false
	# The eye material is one sub-resource shared by every Cerberus - this one needs its own
	# to be able to go dark without switching off everybody else's.
	var eye: MeshInstance3D = get_node_or_null("RobotBody/Eye")
	if eye and eye.material_override:
		_eye_material = eye.material_override.duplicate()
		eye.material_override = _eye_material
	_update_eye()

func is_awake() -> bool:
	return current_state == State.INVESTIGATE or current_state == State.RETURN

func _update_eye() -> void:
	if _eye_material:
		_eye_material.emission_energy_multiplier = EYE_AWAKE_ENERGY if is_awake() else EYE_ASLEEP_ENERGY

# Blind: being seen never starts a chase (and never fires Alex's "first sighting" line either).
func _on_player_detected(_p: Node3D) -> void:
	pass

func hear_noise(noise_position: Vector3) -> void:
	if _switched_off():
		return
	super.hear_noise(noise_position)

func _set_state(new_state: State) -> void:
	super._set_state(new_state)
	_update_eye()
	if new_state == State.INVESTIGATE:
		DialogSystem.trigger_alex_line("floor6_woke")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _switched_off():
		if current_state == State.INVESTIGATE:
			_set_state(State.RETURN)
		return
	if current_state != State.INVESTIGATE:
		return
	var target = get_tree().get_first_node_in_group("player")
	if not target or GameStateManager.current_state == GameStateManager.GameState.SPECTATOR:
		return
	if absf(target.global_position.y - global_position.y) > EnemySensors.SAME_FLOOR_Y_TOLERANCE:
		return
	if _flat_distance(target.global_position) > CATCH_DISTANCE:
		return
	# Same kind of line every other teleport in the game prints (see stairs_gate.gd).
	print("[Sleeper] ", name, " caught the player at ", target.global_position, " - returning to ", return_position)
	target.global_position = return_position
	if "velocity" in target:
		target.velocity = Vector3.ZERO
	DialogSystem.trigger_alex_line("floor6_caught")
	_set_state(State.RETURN)

# Asleep it is armoured shut: a shot only makes noise (laser_pistol.gd reports that noise after
# applying the hit, so the shot that wakes it is not also the one that kills it).
func take_damage(amount: int) -> void:
	if not is_awake():
		return
	super.take_damage(amount)
