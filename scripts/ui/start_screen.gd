# scripts/ui/start_screen.gd
# The first thing on screen: the hotel's own terminal, in the same dark-glass-and-green as the
# CRT terminals on the floors (terminal_ui.gd). Continue the saved game, if there is one, or
# start over; the settings (GameSettings); and on desktop a way out. Built in code: it is a handful of labels and
# buttons, and this keeps the look in one place.
#
# Starting over when a save exists asks once more: there is a single slot and a new game
# overwrites it.
extends Control

const LEVEL_SCENE: String = "res://scenes/levels/hotel_siberia/hotel_level_4.tscn"
const GREEN := Color(0.35, 1.0, 0.45)
const DIM_GREEN := Color(0.2, 0.55, 0.28)
const AMBER := Color(1.0, 0.7, 0.2)
const GLASS := Color(0.02, 0.035, 0.03)

var _continue_btn: Button
var _new_btn: Button
var _status: Label
var _cursor: Label
var _confirming_new: bool = false
var _menu_buttons: Array = []          # the main choices, hidden while the settings are open
var _settings_buttons: Dictionary = {} # GameSettings key -> its Button
var _back_btn: Button
var _blink: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	# In VR there is no flat screen to click on (the HUD only exists once the player does), so
	# the headset build skips the choice: continue if there is something to continue.
	if ProjectSettings.get_setting("xr/openxr/enabled", false):
		_start(SaveManager.has_save())
		return

	set_anchors_preset(Control.PRESET_FULL_RECT)
	var glass := ColorRect.new()
	glass.color = GLASS
	glass.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(glass)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.custom_minimum_size = Vector2(620, 0)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	column.add_child(_line(UIStrings.get_string("start_header", ">> ГОСТИНИЦА «СИБИРЬ» :: ВНУТРЕННЯЯ СЕТЬ <<"), 20, DIM_GREEN))
	column.add_child(_line(UIStrings.get_string("game_title_top", "ГОСТИНИЦА"), 30, GREEN))
	column.add_child(_line(UIStrings.get_string("game_title_main", "«СИБИРЬ»"), 64, GREEN))
	_status = _line("", 18, DIM_GREEN)
	column.add_child(_status)
	column.add_child(_spacer(18))

	var summary: Dictionary = SaveManager.summary()
	_continue_btn = _button(UIStrings.get_string("start_continue", "ПРОДОЛЖИТЬ"))
	_continue_btn.pressed.connect(func(): _start(true))
	_continue_btn.visible = not summary.is_empty()
	column.add_child(_continue_btn)
	_new_btn = _button(UIStrings.get_string("start_new", "НОВАЯ ИГРА"))
	_new_btn.pressed.connect(_on_new_pressed)
	column.add_child(_new_btn)
	var settings_btn := _button(UIStrings.get_string("start_settings", "НАСТРОЙКИ"))
	settings_btn.pressed.connect(func(): _show_settings(true))
	column.add_child(settings_btn)
	_menu_buttons = [_continue_btn, _new_btn, settings_btn]
	if OS.get_name() != "Android":
		var quit_btn := _button(UIStrings.get_string("start_quit", "ВЫХОД"))
		quit_btn.pressed.connect(func(): get_tree().quit())
		column.add_child(quit_btn)
		_menu_buttons.append(quit_btn)

	# One button per setting: pressing it moves the setting to its next value.
	var setting_keys: Array = ["look_sensitivity", "volume", "subtitle_scale"]
	if DisplayServer.is_touchscreen_available():
		setting_keys.append("touch_scheme")
	for key in setting_keys:
		var setting_btn := _button("")
		setting_btn.pressed.connect(_on_setting_pressed.bind(key))
		setting_btn.visible = false
		column.add_child(setting_btn)
		_settings_buttons[key] = setting_btn
	_back_btn = _button(UIStrings.get_string("settings_back", "НАЗАД"))
	_back_btn.pressed.connect(func(): _show_settings(false))
	_back_btn.visible = false
	column.add_child(_back_btn)
	_refresh_settings()

	column.add_child(_spacer(18))
	_cursor = _line("", 18, GREEN)
	column.add_child(_cursor)

	if summary.is_empty():
		_status.text = UIStrings.get_string("start_status_empty", "Записей нет. Связь с внешним узлом отсутствует.")
		_new_btn.grab_focus()
	else:
		_status.text = UIStrings.get_string("start_status_saved", "Найдена запись: этаж %d, плёнок %d из 27.") % [summary["floor"], summary["tapes"]]
		_continue_btn.grab_focus()

func _process(delta: float) -> void:
	if _cursor:
		_blink += delta
		_cursor.text = "> _" if fmod(_blink, 1.0) < 0.5 else ">"

func _show_settings(open: bool) -> void:
	var has_save: bool = SaveManager.has_save()
	for button in _menu_buttons:
		button.visible = not open and (button != _continue_btn or has_save)
	for key in _settings_buttons:
		_settings_buttons[key].visible = open
	_back_btn.visible = open
	if open:
		_settings_buttons["look_sensitivity"].grab_focus()
	else:
		(_continue_btn if has_save else _new_btn).grab_focus()

func _on_setting_pressed(key: String) -> void:
	GameSettings.cycle(key)
	_refresh_settings()

func _refresh_settings() -> void:
	_settings_buttons["look_sensitivity"].text = UIStrings.get_string("settings_look", "ЧУВСТВИТЕЛЬНОСТЬ: %d%%") % roundi(GameSettings.look_sensitivity * 100.0)
	_settings_buttons["volume"].text = UIStrings.get_string("settings_volume", "ГРОМКОСТЬ: %d%%") % roundi(GameSettings.volume * 100.0)
	var sizes: PackedStringArray = UIStrings.get_string("settings_subtitle_sizes", "ОБЫЧНЫЕ,КРУПНЫЕ,ОЧЕНЬ КРУПНЫЕ").split(",")
	var size_index: int = clampi(GameSettings.SUBTITLE_STEPS.find(GameSettings.subtitle_scale), 0, sizes.size() - 1)
	_settings_buttons["subtitle_scale"].text = UIStrings.get_string("settings_subtitles", "СУБТИТРЫ: %s") % sizes[size_index]
	if _settings_buttons.has("touch_scheme"):
		var schemes: PackedStringArray = UIStrings.get_string("settings_touch_schemes", "ДВА ПАЛЬЦА,ОДИН ПАЛЕЦ").split(",")
		_settings_buttons["touch_scheme"].text = UIStrings.get_string("settings_touch", "УПРАВЛЕНИЕ: %s") % schemes[1 if GameSettings.one_finger() else 0]

func _on_new_pressed() -> void:
	# One slot: a new game replaces the saved one, so with a save present ask a second time.
	if SaveManager.has_save() and not _confirming_new:
		_confirming_new = true
		_new_btn.text = UIStrings.get_string("start_new_confirm", "СТЕРЕТЬ ЗАПИСЬ И НАЧАТЬ ЗАНОВО?")
		_new_btn.add_theme_color_override("font_color", AMBER)
		return
	_start(false)

func _start(continue_saved: bool) -> void:
	if not (continue_saved and SaveManager.load_game()):
		SaveManager.new_game()
	get_tree().change_scene_to_file(LEVEL_SCENE)

func _line(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

# A terminal menu line: green text on dark glass with a thin green frame, brighter when focused.
func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 64) # tall enough for a thumb
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", GREEN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", AMBER)
	for state in ["normal", "hover", "focus", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.05, 0.12, 0.07) if state == "normal" else Color(0.08, 0.22, 0.12)
		box.border_color = DIM_GREEN if state == "normal" else GREEN
		box.set_border_width_all(2)
		button.add_theme_stylebox_override(state, box)
	return button
