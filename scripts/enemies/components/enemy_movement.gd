extends Node
class_name EnemyMovement

@onready var nav_agent: NavigationAgent3D = get_parent().get_node("NavigationAgent3D")
@onready var enemy: CharacterBody3D = get_parent()

var gravity: float = 9.8

# Diagnostic only - logs when navigation flips between "no path" and "has path", so a log
# capturing an enemy that never moves shows clearly whether it's stuck waiting on the navmesh
# (see enemy_ai_base.gd's _ready() comment about the bake-timing race) or something else entirely.
var _was_finished: bool = true

# Diagnostic only - catches "stuck in place, spinning wildly" reports (reported 2026-08-23 on
# floor 4): look_at() snaps the facing instantly every physics tick, so if get_next_path_position()
# jitters (e.g. the agent is wedged against geometry and the navmesh's nearest-valid-point keeps
# flip-flopping, or the path keeps recalculating to a barely-different point), the enemy can spin
# at up to 60 direction flips/sec while net displacement stays ~0 - not caught by the existing
# "no path"/"has path" log above, since a path DOES exist the whole time, it's just unstable.
const ROTATION_SPIKE_DEG_THRESHOLD: float = 60.0
const ROTATION_SPIKE_LOG_INTERVAL: float = 0.5
var _rotation_spike_log_timer: float = 0.0

func apply_gravity(delta: float) -> void:
	if not enemy.is_on_floor():
		enemy.velocity.y -= gravity * delta

func move_along_nav(speed: float) -> void:
	if nav_agent.is_navigation_finished():
		if not _was_finished:
			print("[EnemyMovement] ", enemy.name, " navigation finished/no path - pos=",
				enemy.global_position, " target=", nav_agent.target_position)
		_was_finished = true
		return

	if _was_finished:
		print("[EnemyMovement] ", enemy.name, " path found - pos=", enemy.global_position,
			" target=", nav_agent.target_position)
	_was_finished = false

	var next_pos: Vector3 = nav_agent.get_next_path_position()
	var to_next: Vector3 = next_pos - enemy.global_position
	to_next.y = 0.0

	if to_next.length_squared() < 0.0001:
		# No meaningful horizontal path yet (e.g. nav mesh not baked/synced,
		# or the next point is directly above/below us) - looking_at would
		# target our own position and fail. Just stop horizontal movement.
		enemy.velocity.x = 0.0
		enemy.velocity.z = 0.0
		return

	var direction: Vector3 = to_next.normalized()
	enemy.velocity.x = direction.x * speed
	enemy.velocity.z = direction.z * speed

	var prev_facing: Vector3 = -enemy.global_transform.basis.z
	enemy.look_at(enemy.global_position + direction, Vector3.UP)
	_log_rotation_spike_if_any(prev_facing, next_pos)

func _log_rotation_spike_if_any(prev_facing: Vector3, next_pos: Vector3) -> void:
	var new_facing: Vector3 = -enemy.global_transform.basis.z
	var angle_deg: float = rad_to_deg(prev_facing.angle_to(new_facing))
	if angle_deg <= ROTATION_SPIKE_DEG_THRESHOLD:
		return
	_rotation_spike_log_timer -= get_process_delta_time()
	if _rotation_spike_log_timer > 0.0:
		return
	_rotation_spike_log_timer = ROTATION_SPIKE_LOG_INTERVAL
	print("[EnemyMovement] ", enemy.name, " ROTATION SPIKE ", angle_deg, "deg/tick pos=",
		enemy.global_position, " next_path_pos=", next_pos, " target=", nav_agent.target_position,
		" dist_to_target=", nav_agent.distance_to_target(),
		" is_target_reachable=", nav_agent.is_target_reachable(),
		" nav_finished=", nav_agent.is_navigation_finished(), " velocity=", enemy.velocity)
