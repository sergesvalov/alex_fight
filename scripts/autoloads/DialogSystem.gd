# autoloads/DialogSystem.gd
extends Node

signal narrative_started(tape_id: int)
signal narrative_ended

var is_playing: bool = false
var holo_scene: PackedScene = preload("res://scenes/fx/holo_projection.tscn")

const TAPE_DATA: Array[Dictionary] = [
    {
        "id": 0,
        "title": "ЗАПИСЬ 001: ПРОТОКОЛ ОМЕГА",
        "text": "Если ты ничего не помнишь, значит перемещение прошло успешно. Найди выход отсюда, скоро ты все вспомнишь.",
        "duration": 10.0
    },
    {
        "id": 1,
        "title": "ЗАПИСЬ 002: ЦЕРБЕР",
        "text": "Внимание! Проект 'Цербер' вырвался на свободу и пропал в коридорах лаборатории. Будьте осторожны.",
        "duration": 9.0
    },
    {
        "id": 2,
        "title": "ЗАПИСЬ 003: ПОСЛЕДНИЙ ПУТЬ",
        "text": "Цербер бродит где-то здесь... Некто запер все этажи. Надо спасаться и найти терминал!",
        "duration": 9.0
    }
]

func play_tape(tape_id: int, spawn_position: Vector3) -> void:
    if is_playing:
        return
    is_playing = true
    GameStateManager.change_state(GameStateManager.GameState.READING)
    narrative_started.emit(tape_id)
    
    if holo_scene:
        var holo_instance = holo_scene.instantiate()
        get_tree().current_scene.add_child(holo_instance)
        holo_instance.global_position = spawn_position
        if holo_instance.has_method("set_tape_data"):
            holo_instance.set_tape_data(TAPE_DATA[tape_id])
    
    await get_tree().create_timer(TAPE_DATA[tape_id]["duration"]).timeout
    end_narrative()

func end_narrative() -> void:
    is_playing = false
    GameStateManager.change_state(GameStateManager.GameState.EXPLORING)
    narrative_ended.emit()

func show_thought(text: String, duration: float = 5.0) -> void:
    if EventBus.has_signal("narrative_thought_requested"):
        EventBus.narrative_thought_requested.emit(text, duration)
                # await tween.finished
                # label.visible = false
