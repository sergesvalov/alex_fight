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
	controller = elevator_controller
	_refresh_button_states()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	hide()
	controller = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# Locked floors stay clickable (same as the physical buttons - request_floor() just redirects
# them to the hub floor instead of doing nothing) but dimmed, so the player can tell why nothing
# happens rather than assuming the display is broken.
func _refresh_button_states() -> void:
	for i in range(1, FLOOR_COUNT + 1):
		var btn = grid.get_node_or_null("FloorButton" + str(i))
		if not btn:
			continue
		if GameStateManager.is_floor_unlocked(i):
			btn.modulate = Color(1, 1, 1, 1)
			btn.tooltip_text = ""
		else:
			btn.modulate = Color(1, 1, 1, 0.4)
			btn.tooltip_text = "Этаж ещё не разблокирован"

func _on_floor_pressed(floor_num: int) -> void:
	if controller and controller.has_method("request_floor"):
		controller.request_floor(floor_num)
	close()
