extends Node3D

@onready var particles: GPUParticles3D = $Sparks

func _ready() -> void:
    if particles:
        particles.emitting = true
    # The decal stays, but we can queue_free the whole thing after 10 seconds to save memory
    var timer = get_tree().create_timer(10.0)
    timer.timeout.connect(queue_free)
