# autoloads/DialogSystem.gd
extends Node

signal narrative_started(tape_id: int)
signal narrative_ended

var is_playing: bool = false
var holo_scene: PackedScene = preload("res://scenes/fx/holo_projection.tscn")

# Данные кассет
const TAPE_DATA: Array[Dictionary] = [
    {
        "id": 0,
        "title": "Личность",
        "text": "Александр Нечаев. Уволен за превышение полномочий. 2031 год.",
        "duration": 7.0
    },
    {
        "id": 1,
        "title": "Инцидент",
        "text": "Они пришли из тайги. Гостиница — карантинная зона. Все мертвы.",
        "duration": 7.0
    },
    {
        "id": 2,
        "title": "Выход",
        "text": "Боковая дверь. Код: 1987. Но ОНО охраняет выход.",
        "duration": 8.0
    }
]

func play_tape(tape_id: int, spawn_position: Vector3) -> void:
    if is_playing:
        return
    is_playing = true
    GameStateManager.change_state(GameStateManager.GameState.READING)
    narrative_started.emit(tape_id)
    
    # Спаунить голограмму
    if holo_scene:
        var holo_instance = holo_scene.instantiate()
        get_tree().current_scene.add_child(holo_instance)
        holo_instance.global_position = spawn_position
        if holo_instance.has_method("set_tape_data"):
            holo_instance.set_tape_data(TAPE_DATA[tape_id])
    
    # Автоматически завершить через duration
    await get_tree().create_timer(TAPE_DATA[tape_id]["duration"]).timeout
    end_narrative()

func end_narrative() -> void:
    is_playing = false
    GameStateManager.change_state(GameStateManager.GameState.EXPLORING)
    narrative_ended.emit()
