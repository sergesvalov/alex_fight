extends Area3D

var target_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	collision_mask = 1 # Player layer
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body.has_method("teleport"):
		print("Teleporting player to: ", target_position)
		body.global_position = target_position
