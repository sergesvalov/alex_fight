# scripts/enemies/sleeper_cerberus.gd
extends "res://scripts/enemies/cerberus_ai.gd"

const CATCH_DISTANCE: float = 1.3
const EYE_AWAKE_ENERGY: float = 3.0
const EYE_ASLEEP_ENERGY: float = 0.0

var return_position: Vector3 = Vector3.ZERO
var off_flag: StringName = &"floor6_sleepers_off"
var _eye_material: StandardMaterial3D = null
var _was_awake: bool = false

func _switched_off() -> bool:
	return GameStateManager.get(off_flag) == true

func _ready() -> void:
	super._ready()
	can_see = false
	var eye: MeshInstance3D = get_node_or_null("RobotBody/Eye")
	if eye and eye.material_override:
		_eye_material = eye.material_override.duplicate()
		eye.material_override = _eye_material
	_update_eye()
	_was_awake = is_awake()

func is_awake() -> bool:
	return state_machine.current_state_name in ["INVESTIGATE", "RETURN"]

func _update_eye() -> void:
	if _eye_material:
		_eye_material.emission_energy_multiplier = EYE_AWAKE_ENERGY if is_awake() else EYE_ASLEEP_ENERGY

func _on_player_detected(_p: Node3D) -> void:
	pass

func hear_noise(noise_position: Vector3) -> void:
	if _switched_off():
		return
	super.hear_noise(noise_position)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	var currently_awake = is_awake()
	if currently_awake != _was_awake:
		_update_eye()
		if state_machine.current_state_name == "INVESTIGATE" and not _was_awake:
			DialogSystem.trigger_alex_line("floor6_woke")
		_was_awake = currently_awake

	if _switched_off():
		if state_machine.current_state_name == "INVESTIGATE":
			state_machine.change_state("RETURN")
		return
	if state_machine.current_state_name != "INVESTIGATE":
		return
		
	var target = get_tree().get_first_node_in_group("player")
	if not target or GameStateManager.current_state == GameStateManager.GameState.SPECTATOR:
		return
	if absf(target.global_position.y - global_position.y) > EnemySensors.SAME_FLOOR_Y_TOLERANCE:
		return
	if _flat_distance(target.global_position) > CATCH_DISTANCE:
		return
		
	print("[Sleeper] ", name, " caught the player at ", target.global_position, " - returning to ", return_position)
	target.global_position = return_position
	if "velocity" in target:
		target.velocity = Vector3.ZERO
	DialogSystem.trigger_alex_line("floor6_caught")
	state_machine.change_state("RETURN")

func take_damage(amount: int) -> void:
	if not is_awake():
		return
	super.take_damage(amount)
