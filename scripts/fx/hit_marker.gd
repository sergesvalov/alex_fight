extends Node3D

# The mark of a laser shot: sparks, and a scorch (shaders/laser_burn.gdshader) whose centre
# glows and cools, and which fades out at the end instead of blinking off.
const LIFETIME: float = 3.0   # маркер исчезает через 3с (было 10с) — оптимизация памяти и GPU
const COOL_TIME: float = 0.9
const FADE_TIME: float = 0.6

@onready var particles: GPUParticles3D = $Sparks
@onready var burn: MeshInstance3D = $BurnDecal

func _ready() -> void:
    if particles:
        particles.emitting = true
    # The mesh and its material are shared by every marker - each needs its own to cool on its own.
    var mat: ShaderMaterial = burn.mesh.material.duplicate()
    mat.set_shader_parameter("seed", randf() * TAU)
    burn.material_override = mat
    var tween := create_tween()
    tween.tween_method(func(v: float): mat.set_shader_parameter("heat", v), 1.0, 0.0, COOL_TIME).set_ease(Tween.EASE_OUT)
    tween.tween_interval(LIFETIME - COOL_TIME - FADE_TIME)
    tween.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, FADE_TIME)
    tween.tween_callback(queue_free)
