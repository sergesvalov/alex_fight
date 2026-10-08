extends Node3D

@export var enemy_scene: PackedScene
# Where the extra robot appears, as authored for the level scene's own floor (by the elevator).
@export var spawn_position: Vector3 = Vector3(0, 1, -15)

func _ready() -> void:
    GameStateManager.enemy_spawned.connect(_on_enemy_spawned)

# Fires when a floor's third tape is collected. The robot has to show up on the floor the
# player is actually on - all ten floors share the same X/Z and differ only in height (see
# hotel_level_generator.gd), so it's the authored spot shifted by whole floors. (It used to
# always spawn at the authored height, i.e. on floor 4, no matter which floor was completed.)
func _on_enemy_spawned() -> void:
    if not enemy_scene:
        return
    var generator = get_node_or_null("../NavigationRegion3D/HotelGeometry")
    var level_floor: int = generator.floor_number if generator else 4
    var y_step: float = HotelConstants.BASE_FLOOR_TO_FLOOR_HEIGHT * GlobalConfig.get_floor_scale()

    var enemy = enemy_scene.instantiate()
    add_child(enemy)
    enemy.global_position = spawn_position + Vector3(0, (GameStateManager.current_floor - level_floor) * y_step, 0)
    print("[EnemySpawner] third tape on floor ", GameStateManager.current_floor,
        " - extra robot at ", enemy.global_position)
