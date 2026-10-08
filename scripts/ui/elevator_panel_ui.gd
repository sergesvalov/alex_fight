# scripts/ui/elevator_panel_ui.gd
# 2D on-screen floor picker, opened by elevator_panel_display.gd. Exists specifically because
# mobile's camera is locked to horizontal-only look (player_camera.gd), so aiming at any single
# one of the physical elevator buttons (spread across 5 rows of vertical panel space) is
# impossible there - this gives every platform a way to pick a floor without needing to tilt the
# camera at all. Doesn't pause the game (the elevator sequence itself uses real-time awaits for
# door animation/travel delay - pausing here would freeze those too), just switches the mouse
# mode so clicks/taps reach the buttons.
extends Panel

const FLOOR_COUNT = 10

@onready var grid = $GridContainer
@onready var close_btn = $CloseButton

var controller: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(close)
	for i in range(1, FLOOR_COUNT + 1):
		var btn = Button.new()
		btn.name = "FloorButton" + str(i)
		btn.custom_minimum_size = Vector2(70, 70)
		btn.text = str(i)
		btn.pressed.connect(_on_floor_pressed.bind(i))
		grid.add_child(btn)

func open(elevator_controller: Node) -> void:
	for child in grid.get_children(): # the main lift's ten floors, not the second lift's stops
		child.visible = child.name.begins_with("FloorButton")
	controller = elevator_controller
	_refresh_button_states()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	hide()
	controller = null
	_lower_panel = null
	_lower_player = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# Locked floors stay clickable (same as the physical buttons - request_floor() just redirects
# them to the hub floor instead of doing nothing) but dimmed, so the player can tell why nothing
# happens rather than assuming the display is broken.
func _refresh_button_states() -> void:
	for i in range(1, FLOOR_COUNT + 1):
		var btn = grid.get_node_or_null("FloorButton" + str(i))
		if not btn:
			continue
		# The floor the car is on now reads in amber, with a marker either side.
		var here: bool = i == GameStateManager.current_floor
		btn.text = ("· %d ·" % i) if here else str(i)
		btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2) if here else Color(0.35, 1.0, 0.45))
		if GameStateManager.is_floor_unlocked(i):
			btn.modulate = Color(1, 1, 1, 1)
			btn.tooltip_text = ""
		else:
			btn.modulate = Color(1, 1, 1, 0.4)
			btn.tooltip_text = UIStrings.get_string("elevator_floor_locked")

func _on_floor_pressed(floor_num: int) -> void:
	if controller and controller.has_method("request_floor"):
		controller.request_floor(floor_num)
	close()

# --- The second lift (lobby <-> laboratory) ---
# Same screen as the main lift, different buttons: its three stops instead of the ten floors.
# `panel` is the lift panel the player used (lobby_parts.gd, role "lift"), which knows where
# each stop is and does the moving.
const LOWER_STOPS: Array = [1, -1, -2]
var _lower_panel: Node = null
var _lower_player: Node = null

func open_lower(panel: Node, player: Node) -> void:
	controller = null
	_lower_panel = null
	_lower_player = null
	_lower_panel = panel
	_lower_player = player
	for i in range(1, FLOOR_COUNT + 1):
		grid.get_node("FloorButton" + str(i)).visible = false
	for level in LOWER_STOPS:
		var btn: Button = grid.get_node_or_null("LowerButton" + str(level))
		if not btn:
			btn = Button.new()
			btn.name = "LowerButton" + str(level)
			btn.custom_minimum_size = Vector2(70, 70)
			btn.pressed.connect(_on_lower_pressed.bind(level))
			grid.add_child(btn)
		var here: bool = level == panel.here
		var label: String = str(level).replace("-", "−")
		btn.text = ("· %s ·" % label) if here else label
		btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2) if here else Color(0.35, 1.0, 0.45))
		btn.visible = true
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_lower_pressed(level: int) -> void:
	var panel: Node = _lower_panel
	var player: Node = _lower_player
	close()
	if is_instance_valid(panel) and is_instance_valid(player):
		panel.go_to(level, player)
