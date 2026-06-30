extends Area3D

@export var teleport_offset: Vector3 = Vector3(0, -4.0, 0)
@export var target_group: String = "player"

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group(target_group):
        # We need to seamlessly teleport the body.
        # For CharacterBody3D, changing global_position directly is safe if done correctly.
        body.global_position += teleport_offset
