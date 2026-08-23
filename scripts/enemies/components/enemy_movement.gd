extends Node
class_name EnemyMovement

@onready var nav_agent: NavigationAgent3D = get_parent().get_node("NavigationAgent3D")
@onready var enemy: CharacterBody3D = get_parent()

var gravity: float = 9.8

# Diagnostic only - logs when navigation flips between "no path" and "has path", so a log
# capturing an enemy that never moves shows clearly whether it's stuck waiting on the navmesh
# (see enemy_ai_base.gd's _ready() comment about the bake-timing race) or something else entirely.
var _was_finished: bool = true

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
	enemy.look_at(enemy.global_position + direction, Vector3.UP)
