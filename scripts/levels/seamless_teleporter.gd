extends Area3D

@export var teleport_offset: Vector3 = Vector3(0, -4.0, 0)
@export var target_group: String = "player"

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group(target_group):
        return
        
    var is_going_up = teleport_offset.y < 0
    
    if GameStateManager.current_floor == 3 and is_going_up:
        GameStateManager.entered_from_stairs = true
        GameStateManager.stair_spawn_position = body.global_position + teleport_offset
        GameStateManager.stair_spawn_rotation = body.rotation
        GameStateManager.reset_floor(4)
        get_tree().change_scene_to_file("res://scenes/levels/hotel_siberia/hotel_level.tscn")
    elif GameStateManager.current_floor == 4 and not is_going_up:
        GameStateManager.entered_from_stairs = true
        GameStateManager.stair_spawn_position = body.global_position + teleport_offset
        GameStateManager.stair_spawn_rotation = body.rotation
        GameStateManager.reset_floor(3)
        get_tree().change_scene_to_file("res://scenes/levels/hotel_siberia/hotel_level_3.tscn")
    else:
        # Loop on the same floor
        body.global_position += teleport_offset
