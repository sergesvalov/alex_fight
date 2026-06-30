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

@onready var raycast: RayCast3D = $RayCast3D
@onready var beam_mesh: MeshInstance3D = $BeamMesh
@onready var spark_particles: GPUParticles3D = $Sparks

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
        var hit_point = raycast.get_collision_point()
        distance = global_position.distance_to(hit_point)
        
        var collider = raycast.get_collider()
        if collider and collider.has_method("take_damage"):
            collider.take_damage(damage)
            
        # Particles
        spark_particles.global_position = hit_point
        var normal = raycast.get_collision_normal()
        # Look at normal
        if normal.is_normalized():
            # Basic look_at safe check
            if abs(normal.dot(Vector3.UP)) < 0.99:
                spark_particles.look_at(hit_point + normal, Vector3.UP)
            else:
                spark_particles.look_at(hit_point + normal, Vector3.RIGHT)
        spark_particles.restart()

    # Visual beam
    # Height of cylinder matches distance
    beam_mesh.mesh.height = distance
    # Position shifted forward by half distance (because origin is center of cylinder)
    beam_mesh.position.z = -distance / 2.0
    
    # Beam animation (thickness)
    beam_mesh.scale = Vector3(1, 1, 1)
    beam_mesh.show()
    
    var tween = create_tween()
    # Shrink X and Y (thickness) to 0 over 0.1s
    tween.tween_property(beam_mesh, "scale", Vector3(0, 0, 1), 0.1)
    tween.tween_callback(beam_mesh.hide)
