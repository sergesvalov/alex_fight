extends Node

# Godot's built-in file logging always writes under user:// (on Windows this
# resolves to %APPDATA%/Godot/app_userdata/<project>/...). There is no
# supported project setting or CLI flag to relocate user:// next to the
# executable in an exported build, so instead we copy the finished log file
# there ourselves: once on startup (covers the previous session, including
# one that crashed) and once when the window is closed (covers this session).

func _ready() -> void:
	if OS.has_feature("editor") or OS.get_name() != "Windows":
		return
	_copy_log_next_to_executable()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_copy_log_next_to_executable()

func _copy_log_next_to_executable() -> void:
	if not ProjectSettings.get_setting("debug/file_logging/enable_file_logging", false):
		return
	var log_path: String = ProjectSettings.get_setting("debug/file_logging/log_path", "")
	if log_path.is_empty() or not FileAccess.file_exists(log_path):
		return
	var dest_dir := OS.get_executable_path().get_base_dir().path_join("logs")
	DirAccess.make_dir_recursive_absolute(dest_dir)
	DirAccess.copy_absolute(log_path, dest_dir.path_join(log_path.get_file()))
