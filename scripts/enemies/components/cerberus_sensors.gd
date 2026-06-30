extends Node
class_name CerberusSensors

@onready var detection_area: Area3D = get_parent().get_node("DetectionArea")
@onready var ray_sight: RayCast3D = get_parent().get_node("RayCast3D")
@onready var cerberus: CharacterBody3D = get_parent()

signal player_detected(player: Node3D)
signal player_lost()

var current_player: Node3D = null

func _ready() -> void:
    detection_area.body_entered.connect(_on_body_entered)
    detection_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        current_player = body
        player_detected.emit(body)

func _on_body_exited(body: Node3D) -> void:
    if body == current_player:
        player_lost.emit()
        current_player = null

func has_line_of_sight(target: Node3D) -> bool:
    if not is_instance_valid(target):
        return false
    ray_sight.target_position = ray_sight.to_local(target.global_position)
    ray_sight.force_raycast_update()
    if ray_sight.is_colliding():
        return ray_sight.get_collider() == target
    return false
