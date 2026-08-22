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
    var to_next: Vector3 = next_pos - cerberus.global_position
    to_next.y = 0.0

    if to_next.length_squared() < 0.0001:
        # No meaningful horizontal path yet (e.g. nav mesh not baked/synced,
        # or the next point is directly above/below us) - looking_at would
        # target our own position and fail. Just stop horizontal movement.
        cerberus.velocity.x = 0.0
        cerberus.velocity.z = 0.0
        return

    var direction: Vector3 = to_next.normalized()
    cerberus.velocity.x = direction.x * speed
    cerberus.velocity.z = direction.z * speed
    cerberus.look_at(cerberus.global_position + direction, Vector3.UP)
