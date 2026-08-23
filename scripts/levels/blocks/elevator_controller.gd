extends Node3D
class_name ElevatorController

@onready var panel = $ElevatorPanel

var sfx_hum: AudioStreamPlayer3D
var f_scale: float = 1.0
var player_inside: bool = false
var door_animatable: Node3D

func _ready() -> void:
	if GlobalConfig:
		f_scale = GlobalConfig.get_floor_scale()
	
	door_animatable = get_node_or_null("ElevatorDoor/AnimatableBody3D")
	
	_setup_buttons()
	_setup_audio()
	_setup_interior_detection()
	add_to_group("elevator_controller")

func _process(_delta: float) -> void:
	var is_door_closed = (door_animatable and not door_animatable.is_open)
	
	if player_inside and is_door_closed:
		if not sfx_hum.playing:
			sfx_hum.play()
	else:
		if sfx_hum.playing:
			sfx_hum.stop()

# --- Setup Helpers ---

func _setup_buttons() -> void:
	var template = panel.get_node_or_null("ButtonFloor4")
	for i in range(1, 11):
		var btn
		if i == 4 and template:
			btn = template
		elif template:
			btn = template.duplicate()
			btn.name = "ButtonFloor" + str(i)
			panel.add_child(btn)
		else:
			continue
			
		btn.floor_num = i
		if not btn.button_pressed.is_connected(_on_button_pressed):
			btn.button_pressed.connect(_on_button_pressed)
		
		# Layout in 2 columns
		var col = (i - 1) % 2
		var row = int((i - 1) / 2)
		var z_pos = -0.08 if col == 0 else 0.08
		var y_pos = -0.3 + row * 0.15
		btn.position = Vector3(0.01, y_pos, z_pos)
		# elevator_button.gd caches original_pos in its own _ready(), which already fired
		# (with the template's stale pre-layout position) by the time this line runs - for
		# the template button (floor 4) that's simply because it's scene-authored and _ready()
		# runs before this function; for duplicates it's because add_child() above fires
		# _ready() before btn.position is set here. Left uncorrected, every button's press
		# animation would return it to that stale position instead of its real panel slot.
		btn.original_pos = btn.position

		# Floor number label
		if not btn.has_node("Label3D"):
			var lbl = Label3D.new()
			lbl.name = "Label3D"
			lbl.text = str(i)
			lbl.pixel_size = 0.005
			lbl.font_size = 12
			lbl.modulate = Color(0, 0, 0, 1)
			lbl.outline_modulate = Color(1, 1, 1, 0)
			lbl.position = Vector3(0.021, 0, 0)
			lbl.rotation = Vector3(0, PI / 2.0, 0)
			btn.add_child(lbl)

func _setup_audio() -> void:
	sfx_hum = AudioStreamPlayer3D.new()
	var stream = load("res://assets/audio/elevator_music.wav")
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sfx_hum.stream = stream
	add_child(sfx_hum)

func _setup_interior_detection() -> void:
	var interior_area = Area3D.new()
	interior_area.collision_layer = 0
	interior_area.collision_mask = 1 # Player layer
	
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(3.5, 4.0, 4.0)
	coll.shape = shape
	
	interior_area.add_child(coll)
	interior_area.position = Vector3(0, 2.0, 2.5)
	add_child(interior_area)
	
	interior_area.body_entered.connect(func(b): if b.name == "Player": player_inside = true)
	interior_area.body_exited.connect(func(b): if b.name == "Player": player_inside = false)

# --- Elevator Logic ---

# Floor 4 is this whole script's existing hub/anchor floor already (see the hardcoded "+4"/"-4"
# in _get_floor_from_elevator()/_teleport_player() below) - every other place in this file already
# treats it as "the" base floor, so it's the natural fallback destination here too.
const HUB_FLOOR: int = 4

func _on_button_pressed(floor_num: int) -> void:
	request_floor(floor_num)

# Public entry point shared by the physical 3D buttons (via button_pressed above) and the 2D
# on-screen floor display (elevator_panel_ui.gd, opened by elevator_panel_display.gd) - the
# latter exists because mobile locks the camera to horizontal-only look (see
# player_camera.gd::process_swipe()), which makes most of the physical buttons literally
# impossible to aim at: they're laid out across 5 rows spanning ~0.6m of vertical panel space,
# but a mobile player can never tilt their raycast to reach any row but whichever one happens to
# line up with their fixed eye height.
func request_floor(floor_num: int) -> void:
	# Same stairs-access range as stairs_gate.gd (GameStateManager's "FLOOR ACCESS" section) -
	# the elevator used to be exempt from it entirely ("always open"), but that let it bypass the
	# whole progressive unlock: pressing floor 7 straight from floor 4 would just teleport there
	# with no door/portal ever found. Unlike stairs (which just bounce the player back), a locked
	# floor's button here still runs the elevator - it just always delivers to HUB_FLOOR instead
	# of the pressed floor, same as a building directory that only lists authorized floors and
	# defaults elsewhere back to the lobby.
	var target_floor = floor_num
	if not GameStateManager.is_floor_unlocked(floor_num):
		target_floor = HUB_FLOOR
	print("Elevator button pressed for floor: ", floor_num, " -> routing to ", target_floor)
	_run_elevator_sequence(target_floor)

func _run_elevator_sequence(target_floor: int) -> void:
	# 1. Close doors if open
	if door_animatable and door_animatable.is_open:
		door_animatable.interact(null)
		await get_tree().create_timer(door_animatable.move_time + 0.5).timeout
		
	print("Elevator moving to floor ", target_floor)
	
	# 2. Delay for movement
	await get_tree().create_timer(1.0).timeout
	
	# 3. Teleport player
	_teleport_player(target_floor)

func _teleport_player(target_floor: int) -> void:
	var player = get_tree().current_scene.get_node_or_null("Player")
	if not player:
		return
		
	var current_floor = _get_floor_from_elevator(self)
	
	if current_floor != target_floor:
		var y_step = HotelLevelGenerator.BASE_FLOOR_TO_FLOOR_HEIGHT * f_scale
		var target_y = (target_floor - 4) * y_step
		var current_y = _get_base_y(self)

		player.global_position.y += (target_y - current_y)
		# Keep GameStateManager's floor tracking in sync - stairs_gate.gd compares against
		# current_floor to tell a legitimate arrival apart from a floor-hop attempt, and it would
		# otherwise go stale the moment the elevator (which doesn't go through any stairs gate)
		# moves the player to a different floor.
		GameStateManager.current_floor = target_floor

		var target_elevator = _find_elevator_on_floor(target_floor)
		if target_elevator:
			target_elevator._arrive_and_open()
			return # Stop executing for the current elevator
			
	# If no teleport happened or target is same floor
	await get_tree().create_timer(1.0).timeout
	_arrive_and_open()

func _arrive_and_open() -> void:
	print("Elevator arrived!")
	if door_animatable and not door_animatable.is_open:
		door_animatable.interact(null)

# --- Utilities ---

func _get_base_y(elevator: ElevatorController) -> float:
	if elevator.get_parent() and elevator.get_parent().name.begins_with("GeneratedFloor_"):
		return elevator.get_parent().global_position.y
	return elevator.global_position.y

func _get_floor_from_elevator(elevator: ElevatorController) -> int:
	var y_step = HotelLevelGenerator.BASE_FLOOR_TO_FLOOR_HEIGHT * f_scale
	return round(_get_base_y(elevator) / y_step) + 4

func _find_elevator_on_floor(floor_num: int) -> ElevatorController:
	var elevators = get_tree().get_nodes_in_group("elevator_controller")
	for el in elevators:
		if el != self and el._get_floor_from_elevator(el) == floor_num:
			return el
	return null
