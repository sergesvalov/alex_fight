extends Node
class_name EnemySensors

@onready var detection_area: Area3D = get_parent().get_node("DetectionArea")
@onready var ray_sight: RayCast3D = get_parent().get_node("RayCast3D")
@onready var enemy: CharacterBody3D = get_parent()

signal player_detected(player: Node3D)
signal player_lost()

var current_player: Node3D = null

# All 10 floors physically coexist in one scene, stacked only by Y (see AGENTS.md's "P.T.
# Non-Euclidean Loop" note) - DetectionArea's own SphereShape3D (radius 12m, see cerberus.tscn)
# is far bigger than the 4.5m floor-to-floor gap, so a sphere overlap alone lets an enemy 2-3
# floors above/below "detect" the player through solid floor slabs. LOS raycasts (has_line_of_sight()) already block the actual attack damage
# across floors, but the state machine itself (CHASE/ATTACK, combat music, needless navigation)
# still fired - this guard rejects the detection itself before any of that happens.
const SAME_FLOOR_Y_TOLERANCE: float = 2.5

func _ready() -> void:
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

	# The sight ray must hit walls as well as the player. Its default mask of 1 is the player's
	# layer only (player.tscn), while create_static_box() puts hotel walls on layer 2 - with
	# mask 1 the ray passes through every wall and has_line_of_sight() is always true. Doors
	# (collision_layer=7) already include bit 1, so they block it either way.
	ray_sight.collision_mask = 1 | 2

# Being inside the detection sphere only makes the player a CANDIDATE. They are detected the
# moment the enemy actually has line of sight to them - checked a few times a second below.
# Sphere overlap alone would let a robot in the corridor "spot" a player sitting in a room
# behind a closed door and attack the wall; nothing quiet would be possible.
const SIGHT_CHECK_INTERVAL: float = 0.2
var _candidate: Node3D = null
var _sees_candidate: bool = false
var _sight_check_timer: float = 0.0

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_candidate = body
	_sees_candidate = false

func _on_body_exited(body: Node3D) -> void:
	if body == _candidate:
		_candidate = null
		_sees_candidate = false
	if body == current_player:
		player_lost.emit()
		current_player = null

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_candidate):
		return
	_sight_check_timer -= delta
	if _sight_check_timer > 0.0:
		return
	_sight_check_timer = SIGHT_CHECK_INTERVAL
	var sees: bool = absf(_candidate.global_position.y - enemy.global_position.y) <= SAME_FLOOR_Y_TOLERANCE \
		and has_line_of_sight(_candidate)
	# Only the moment sight is gained counts: an enemy that later loses the player and gives
	# up is not re-alerted until it has lost sight and then catches it again.
	if sees and not _sees_candidate:
		current_player = _candidate
		player_detected.emit(_candidate)
	_sees_candidate = sees

# The player, if the enemy has line of sight to him right now.
func visible_player() -> Node3D:
	return _candidate if _sees_candidate and is_instance_valid(_candidate) else null

const AIM_HEIGHT: float = 0.9 # middle of the player's 1.8m capsule (player.tscn)

func has_line_of_sight(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return false
	# Jolt Physics автоматически обновляет рейкаст в _physics_process,
	# force_raycast_update() здесь лишнее (throttle делается в enemy_ai_base.gd)
	# Aimed at the body, not at target.global_position: that is the point between the feet, the
	# very bottom tip of the player's capsule. From more than ~8m away a ray to it skims the
	# floor and clips the capsule only in its last few centimetres, which the physics query
	# does not reliably report - the enemy then could not see a player standing in plain view
	# down the corridor.
	ray_sight.target_position = ray_sight.to_local(target.global_position + Vector3.UP * AIM_HEIGHT)
	if ray_sight.is_colliding():
		return ray_sight.get_collider() == target
	return false
