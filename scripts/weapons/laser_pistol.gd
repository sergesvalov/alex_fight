# scripts/weapons/laser_pistol.gd
class_name LaserPistol
extends Node3D

signal heat_changed(current_heat: float)

@export var max_distance: float = 50.0
@export var damage: float = 20.0

# Heat System Parameters
var heat: float = 0.0
var heat_per_shot: float = 15.0
var cooling_rate: float = 25.0
var is_overheated: bool = false

# Preload один раз при загрузке скрипта, а не при каждом выстреле
const HIT_MARKER_SCENE := preload("res://scenes/fx/hit_marker.tscn")
const MAX_HIT_MARKERS: int = 8

@onready var raycast: RayCast3D = $RayCast3D
@onready var beam_mesh: MeshInstance3D = $BeamMesh

func _ready() -> void:
    beam_mesh.hide()
    # Point raycast forward (local Z is negative)
    raycast.target_position = Vector3(0, 0, -max_distance)
    # Ensure beam mesh has unique mesh to avoid scaling other instances
    if beam_mesh.mesh:
        beam_mesh.mesh = beam_mesh.mesh.duplicate()

func _process(delta: float) -> void:
    if heat > 0:
        heat -= cooling_rate * delta
        if heat <= 0:
            heat = 0
            is_overheated = false
        heat_changed.emit(heat)

func shoot() -> void:
    if is_overheated:
        return
        
    # Heat up
    heat += heat_per_shot
    if heat >= 100.0:
        heat = 100.0
        is_overheated = true
    heat_changed.emit(heat)
    
    # Raycast
    raycast.force_raycast_update()
    var distance: float = max_distance
    
    if raycast.is_colliding():
        var hit_point := raycast.get_collision_point()
        distance = global_position.distance_to(hit_point)
        
        var collider := raycast.get_collider()
        if collider and collider.has_method("take_damage"):
            collider.take_damage(damage)
            
        # Spawn Hit Marker с лимитом на количество в сцене
        _spawn_hit_marker(hit_point, raycast.get_collision_normal())

    # Visual beam
    beam_mesh.mesh.height = distance
    beam_mesh.position.z = -distance / 2.0
    beam_mesh.scale = Vector3(1, 1, 1)
    beam_mesh.show()
    
    var tween := create_tween()
    tween.tween_property(beam_mesh, "scale", Vector3(0, 0, 1), 0.1)
    tween.tween_callback(beam_mesh.hide)

func _spawn_hit_marker(hit_point: Vector3, normal: Vector3) -> void:
    var scene_root := get_tree().current_scene
    
    # Удаляем самый старый маркер если превышен лимит
    var existing: Array = scene_root.get_children().filter(
        func(n: Node) -> bool: return n.is_in_group("hit_markers")
    )
    if existing.size() >= MAX_HIT_MARKERS:
        existing[0].queue_free()
    
    var marker := HIT_MARKER_SCENE.instantiate()
    scene_root.add_child(marker)
    marker.add_to_group("hit_markers")
    marker.global_position = hit_point
    
    if normal.is_normalized():
        if abs(normal.dot(Vector3.UP)) < 0.99:
            marker.look_at(hit_point + normal, Vector3.UP)
        else:
            marker.look_at(hit_point + normal, Vector3.RIGHT)
