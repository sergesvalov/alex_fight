# scripts/enemies/enemy_ai_base.gd
class_name EnemyAI
extends CharacterBody3D

const EnemyStateMachine = preload("res://scripts/enemies/states/enemy_state_machine.gd")
const EnemyHearing = preload("res://scripts/enemies/components/enemy_hearing.gd")
const EnemyStates = preload("res://scripts/enemies/states/enemy_states.gd")

@export var idle_wait_time: float = 2.0
@export var patrol_speed: float = 3.0
@export var chase_speed: float = 6.5
@export var attack_range: float = 2.0
@export var attack_damage: int = 20
@export var attack_cooldown: float = 1.5
@export var patrol_points: Array[Marker3D] = []

@onready var movement: EnemyMovement = $Movement
@onready var sensors: EnemySensors = $Sensors

var state_machine: EnemyStateMachine
var hearing: EnemyHearing

# These are now accessed by states
var player: CharacterBody3D = null
var spawn_position: Vector3
var current_patrol_index: int = 0

var attack_timer: float = 0.0
var idle_timer: float = 0.0
var _nav_update_timer: float = 0.0
var _los_check_timer: float = 0.0
var _last_los: bool = false

const NAV_UPDATE_INTERVAL: float = 0.3
const LOS_CHECK_INTERVAL: float = 0.2
const ATTACK_ROTATION_SPIKE_DEG_THRESHOLD: float = 60.0
const ATTACK_ROTATION_SPIKE_LOG_INTERVAL: float = 0.5
var _attack_rotation_spike_log_timer: float = 0.0

const ATTACK_BLIND_LIMIT: float = 1.5
var _attack_blind_time: float = 0.0

const INVESTIGATE_ARRIVE_DISTANCE: float = 1.0
const INVESTIGATE_LOOK_TIME: float = 3.0
const INVESTIGATE_MAX_TIME: float = 14.0
const INVESTIGATE_TURN_SPEED: float = 1.6
const SIGHT_RANGE: float = 12.0
@export var investigate_speed: float = 4.5
var can_see: bool = true

var _noise_position: Vector3 = Vector3.ZERO
var _investigate_look_left: float = 0.0
var _investigate_time_left: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	spawn_position = global_position

	sensors.player_detected.connect(_on_player_detected)
	sensors.player_lost.connect(_on_player_lost)

	hearing = EnemyHearing.new(self)
	
	state_machine = EnemyStateMachine.new(self)
	state_machine.add_state("IDLE", EnemyStates.IdleState.new(self))
	state_machine.add_state("PATROL", EnemyStates.PatrolState.new(self))
	state_machine.add_state("CHASE", EnemyStates.ChaseState.new(self))
	state_machine.add_state("ATTACK", EnemyStates.AttackState.new(self))
	state_machine.add_state("RETURN", EnemyStates.ReturnState.new(self))
	state_machine.add_state("INVESTIGATE", EnemyStates.InvestigateState.new(self))
	state_machine.add_state("DEAD", EnemyStates.DeadState.new(self))

	idle_timer = idle_wait_time * 3.0
	state_machine.change_state("IDLE")

func _physics_process(delta: float) -> void:
	movement.apply_gravity(delta)
	attack_timer -= delta
	_nav_update_timer -= delta
	_los_check_timer -= delta

	state_machine.physics_process(delta)
	move_and_slide()

func _on_navmesh_ready() -> void:
	if state_machine.current_state_name == "IDLE" and patrol_points.size() > 0:
		state_machine.change_state("PATROL")

func _flat_distance(target: Vector3) -> float:
	var to_target: Vector3 = target - global_position
	to_target.y = 0.0
	return to_target.length()

func _log_attack_rotation_spike_if_any(prev_facing: Vector3, to_player: Vector3) -> void:
	var new_facing: Vector3 = -global_transform.basis.z
	var angle_deg: float = rad_to_deg(prev_facing.angle_to(new_facing))
	if angle_deg <= ATTACK_ROTATION_SPIKE_DEG_THRESHOLD:
		return
	_attack_rotation_spike_log_timer -= get_physics_process_delta_time()
	if _attack_rotation_spike_log_timer > 0.0:
		return
	_attack_rotation_spike_log_timer = ATTACK_ROTATION_SPIKE_LOG_INTERVAL
	print("[EnemyAI] ", name, " ATTACK ROTATION SPIKE ", angle_deg, "deg/tick pos=", global_position,
		" player_pos=", (player.global_position if is_instance_valid(player) else "?"),
		" to_player=", to_player, " to_player_len=", to_player.length(),
		" attack_timer=", attack_timer, " velocity=", velocity)

func _perform_attack() -> void:
	if player.has_method("take_damage"):
		player.take_damage(attack_damage)
		print(name, " attacked player for ", attack_damage)

func _on_player_detected(p: Node3D) -> void:
	if GameStateManager.current_state == GameStateManager.GameState.SPECTATOR:
		return
	if state_machine.current_state_name != "ATTACK":
		player = p
		state_machine.change_state("CHASE")

func _on_player_lost() -> void:
	pass

func hear_noise(noise_position: Vector3) -> void:
	hearing.hear_noise(noise_position)

func take_damage(amount: int) -> void:
	print(name, " took damage: ", amount)
	state_machine.change_state("DEAD")

func _die() -> void:
	queue_free()

# Backwards compatibility properties to avoid breaking subclasses like sleeper_cerberus.gd
enum State { IDLE, PATROL, CHASE, ATTACK, RETURN, DEAD, INVESTIGATE }
var current_state: int:
	get:
		if state_machine == null:
			return State.IDLE
		return State.get(state_machine.current_state_name, State.IDLE)
func _set_state(s: int) -> void:
	pass # Only here so subclasses overriding don't crash before we update them
