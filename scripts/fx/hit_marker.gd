extends Node3D

@onready var particles: GPUParticles3D = $Sparks

func _ready() -> void:
    if particles:
        particles.emitting = true
    # Маркер исчезает через 3с (было 10с) — оптимизация памяти и GPU
    var timer := get_tree().create_timer(3.0)
    timer.timeout.connect(queue_free)
