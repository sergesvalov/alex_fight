extends Node3D

@export var enemy_scene: PackedScene
@export var spawn_position: Vector3 = Vector3(0, 1, -15)

func _ready() -> void:
    GameStateManager.enemy_spawned.connect(_on_enemy_spawned)

func _on_enemy_spawned() -> void:
    if enemy_scene:
        var enemy = enemy_scene.instantiate()
        add_child(enemy)
        enemy.global_position = spawn_position
