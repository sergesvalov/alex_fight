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
# floors above/below "detect" the player through solid floor slabs (confirmed 2026-08-23: a log
# showed 4 different floors' Cerberus units entering CHASE/ATTACK against the same player
# position at once). LOS raycasts (has_line_of_sight()) already block the actual attack damage
# across floors, but the state machine itself (CHASE/ATTACK, combat music, needless navigation)
# still fired - this guard rejects the detection itself before any of that happens.
const SAME_FLOOR_Y_TOLERANCE: float = 2.5

func _ready() -> void:
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if absf(body.global_position.y - enemy.global_position.y) > SAME_FLOOR_Y_TOLERANCE:
		return
	current_player = body
	player_detected.emit(body)

func _on_body_exited(body: Node3D) -> void:
	if body == current_player:
		player_lost.emit()
		current_player = null

func has_line_of_sight(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return false
	# Jolt Physics автоматически обновляет рейкаст в _physics_process,
	# force_raycast_update() здесь лишнее (throttle делается в enemy_ai_base.gd)
	ray_sight.target_position = ray_sight.to_local(target.global_position)
	if ray_sight.is_colliding():
		return ray_sight.get_collider() == target
	return false
