# autoloads/SaveManager.gd
extends Node

const SAVE_PATH = "user://savegame.save"

func save_game():
    var save_dict = {
        "tapes_found": GameStateManager.tapes_found,
        "exit_code_known": GameStateManager.exit_code_known,
        "cerberus_spawned": GameStateManager.cerberus_spawned,
    }
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(save_dict))

func load_game():
    if not FileAccess.file_exists(SAVE_PATH):
        return # Нет файла сохранений
        
    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    var data_string = file.get_as_text()
    var json = JSON.new()
    var parse_result = json.parse(data_string)
    if parse_result == OK:
        var data = json.get_data()
        GameStateManager.tapes_found = data.get("tapes_found", [])
        GameStateManager.exit_code_known = data.get("exit_code_known", false)
        GameStateManager.cerberus_spawned = data.get("cerberus_spawned", false)
