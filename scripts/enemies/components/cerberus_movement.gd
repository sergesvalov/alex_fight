extends Node
class_name CerberusMovement

@onready var nav_agent: NavigationAgent3D = get_parent().get_node("NavigationAgent3D")
@onready var cerberus: CharacterBody3D = get_parent()

var gravity: float = 9.8

func apply_gravity(delta: float) -> void:
    if not cerberus.is_on_floor():
        cerberus.velocity.y -= gravity * delta

func move_along_nav(speed: float) -> void:
    if nav_agent.is_navigation_finished(): return
    
    var next_pos: Vector3 = nav_agent.get_next_path_position()
    var direction: Vector3 = (next_pos - cerberus.global_position).normalized()
    
    cerberus.velocity.x = direction.x * speed
    cerberus.velocity.z = direction.z * speed
    
    if direction != Vector3.ZERO:
        var look_pos = cerberus.global_position + direction
        look_pos.y = cerberus.global_position.y
        cerberus.look_at(look_pos, Vector3.UP)
