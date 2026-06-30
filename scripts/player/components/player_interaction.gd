class_name PlayerInteraction
extends Node

@onready var player: CharacterBody3D = get_parent()
@onready var ray_interact: RayCast3D = get_parent().get_node("RayCast3D")

var tapes_collected: int = 0
var max_tapes: int = 3

func _ready() -> void:
    update_tapes_ui()

var interact_btn: Control = null

func _process(_delta: float) -> void:
    var can_interact = false
    if ray_interact.is_colliding():
        var collider = ray_interact.get_collider()
        if collider and collider.has_method("interact"):
            can_interact = true
            
    if interact_btn:
        interact_btn.visible = can_interact

func try_interact() -> void:
    if ray_interact.is_colliding():
        var collider = ray_interact.get_collider()
        if collider and collider.has_method("interact"):
            collider.interact(player)

func collect_tape() -> void:
    tapes_collected += 1
    update_tapes_ui()
    
func update_tapes_ui() -> void:
    if EventBus.has_signal("tapes_collected_updated"):
        EventBus.tapes_collected_updated.emit(tapes_collected, max_tapes)
