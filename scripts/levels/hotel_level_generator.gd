@tool
extends Node3D
class_name HotelLevelGenerator

const CsgBaker = preload("res://scripts/levels/csg_baker.gd")
const FloorMap = preload("res://scripts/levels/floor_map.gd")

# Small vertical offset to prevent Z-fighting between the ceiling of one floor
# and the floor slab of the floor above on Android (gl_compatibility / 16-bit depth).
const CEIL_BIAS: float = 0.001

@export var floor_number: int = 4
@export var floor_thickness: float = HotelConstants.BASE_FLOOR_THICKNESS
@export var corridor_height: float = HotelConstants.BASE_CORRIDOR_HEIGHT
@export var wall_thickness: float = 0.2
@export var carpet_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var empty_box_mode: bool = false
# Swap every block's CSG for a shared pre-computed mesh as it's placed (see csg_baker.gd). Off =
# the generated tree keeps its live CSG nodes, which is what tests reading wall sizes need.
@export var bake_csg: bool = true

# The one place a block/prop instance passes through between instantiate() and add_child().
func _bake_csg(inst: Node) -> void:
	if not bake_csg or Engine.is_editor_hint():
		return
	# Any non-default floor/player scale makes block.gd resize CSG boxes in place after the
	# block enters the tree - nothing to share between instances then.
	if not is_equal_approx(GlobalConfig.get_floor_scale(), 1.0) or not is_equal_approx(GlobalConfig.get_player_scale(), 1.0):
		return
	CsgBaker.bake(inst, self)

static func _load_texture_safe(path: String) -> Texture2D:
	if DisplayServer.get_name() == "headless":
		var global_path = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(global_path):
			var img = Image.new()
			if img.load(global_path) == OK:
				return ImageTexture.create_from_image(img)
		return null
		
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

@onready var carpet_texture = _load_texture_safe("res://assets/textures/hotel_carpet.jpg")
@onready var wall_texture = _load_texture_safe("res://assets/textures/hotel_wallpaper.jpg")
@onready var retro_wall_texture = _load_texture_safe("res://assets/textures/retro_wallpaper.jpg")
@onready var ceiling_texture = _load_texture_safe("res://assets/textures/hotel_wallpaper.jpg")

# Per-floor lighting: all 10 floors physically coexist in this one scene, stacked at
# different Y offsets (see _generate_level) - without this, every room/stairs/elevator
# light on all 10 floors would be lit simultaneously even though the player can only
# ever be on one of them at a time.
var _floor_lights_by_index: Dictionary = {}   # int floor index (1..10) -> Array[Light3D]
var _lit_floor_index: int = -1
var _light_y_step: float = 0.0

# Per-floor visibility, same reasoning as the lights above: without it the renderer draws all
# 10 floors' worth of rooms/props/doors that fall inside the camera frustum (there are no
# occluders, so a slab between floors hides nothing as far as culling is concerned). Only the
# player's floor and its two neighbors (seen through the stairwells) stay visible. Index 11 is
# the roof. Collision, navigation and scripts are unaffected - this only toggles `visible`.
var _floor_nodes_by_index: Dictionary = {}    # int floor index (1..11) -> Node3D
# Off until the navmesh is baked, so the bake always parses the whole building.
var _floor_culling_enabled: bool = false

# Room shadows further than this from the camera aren't rendered at all - every room on the
# floor keeps a shadow-casting light, but only the handful near the player ever matter.
const LIGHT_SHADOW_FADE_DISTANCE: float = 18.0

# Debug builds only - prints FPS/draw calls so a rendering change can be judged by numbers.
const PERF_LOG_INTERVAL: float = 5.0
var _perf_log_timer: float = PERF_LOG_INTERVAL

func _ready() -> void:
	if GameStateManager.has_signal("all_tapes_collected"):
		GameStateManager.connect("all_tapes_collected", _on_all_tapes_collected)
	add_to_group("level_generator")
	var build_start_ms: int = Time.get_ticks_msec()
	_generate_level()
	print("[perf] level built in ", Time.get_ticks_msec() - build_start_ms, " ms (started at ",
		build_start_ms, " ms since engine start)")
	if "secret_portal_active" in GameStateManager and GameStateManager.secret_portal_active:
		_create_exit_portal()
		
	if not Engine.is_editor_hint():
		# Allow physics to settle
		await get_tree().physics_frame
		await get_tree().physics_frame
		
		var nav_region = get_parent()
		if nav_region is NavigationRegion3D:
			print("[generator] baking navigation mesh...")
			# bake_navigation_mesh() defaults to on_thread=true - it returns immediately and bakes
			# in the background, it does NOT block until the mesh is ready. A fixed-time guess for
			# "surely long enough" (what cerberus_ai.gd's own idle_wait_time delay assumed) breaks
			# on slower hardware if baking this whole 10-floor hotel takes longer than that guess.
			# Awaiting the region's own bake_finished signal is the actual correct completion
			# signal regardless of how long baking takes.
			var bake_start_ms: int = Time.get_ticks_msec()
			nav_region.bake_navigation_mesh()
			await nav_region.bake_finished
			print("[perf] navmesh baked in ", Time.get_ticks_msec() - bake_start_ms, " ms")
			print("[generator] navigation mesh baked - releasing enemies to patrol")
			get_tree().call_group("enemies", "_on_navmesh_ready")
		else:
			print("[generator] WARNING: parent is not NavigationRegion3D, navmesh never baked - ", nav_region)

		_floor_culling_enabled = true
		_apply_floor_visibility()

func _generate_level() -> void:
	# The whole build below draws from the global random generator - seeding it makes the hotel
	# a function of the seed (see GameStateManager.world_seed).
	seed(GameStateManager.world_seed)
	for child in get_children():
		child.free()
	_floor_lights_by_index.clear()
	_floor_nodes_by_index.clear()
	_lit_floor_index = -1

	var f_scale = GlobalConfig.get_floor_scale()
	var height = corridor_height * f_scale
	var floor_thick = floor_thickness * f_scale
	var y_step = height + floor_thick

	# Stairs gates (stairs_gate.gd, South and North) compare against this to tell a floor-hop
	# attempt apart from the player just visiting their own floor's stairwell.
	if not SaveManager.resuming: # a continued game keeps the floor it was saved on
		GameStateManager.current_floor = floor_number
	# Seeds the stairs-access range at the spawn floor only - a no-op if already initialized
	# (e.g. this level scene reloading mid-playthrough), since the range is meant to persist.
	GameStateManager.init_floor_access(floor_number)

	# Another floor's own carpet color, read from that floor's level scene.
	var get_carpet_color_from_scene = func(level_num: int) -> Color:
		var scene_path = "res://scenes/levels/hotel_siberia/hotel_level_" + str(level_num) + ".tscn"
		if ResourceLoader.exists(scene_path):
			var packed = load(scene_path)
			if packed:
				var temp = packed.instantiate()
				var geom = temp.get_node_or_null("NavigationRegion3D/HotelGeometry")
				var color = geom.carpet_color if geom and "carpet_color" in geom else Color(1, 1, 1)
				temp.queue_free()
				return color
		return Color(1, 1, 1) # Default

	for i in range(1, 11):
		var y_offset = (i - floor_number) * y_step
		var suffix = str(i)
		if i == floor_number:
			suffix = "Main"

		var c_color = carpet_color
		if i != floor_number:
			c_color = get_carpet_color_from_scene.call(i)
		if i == 4:
			c_color = Color(1.0, 1.0, 1.0, 1.0)

		var is_empty = false
		if i == 1:
			is_empty = true

		var floor_node = _build_floor_geometry(i, y_offset, suffix, c_color, is_empty, f_scale)
		var lights: Array = []
		_find_lights(floor_node, lights)
		for light in lights:
			light.distance_fade_enabled = true
			light.distance_fade_shadow = LIGHT_SHADOW_FADE_DISTANCE
		_floor_lights_by_index[i] = lights
		_floor_nodes_by_index[i] = floor_node
		if i == 9 or i == 10:
			_add_floor_wide_trap(floor_node, i, f_scale)
		# Floor 2 replays "that night": the blackouts of floor 7 and the sleepers of floor 6 at once.
		if i == 7 or i == 2:
			_add_blackout_trap(floor_node, i, lights, f_scale)

	# Generate roof above the 10th floor
	var roof_y_offset = (11 - floor_number) * y_step
	_generate_roof(roof_y_offset, f_scale)
	_floor_nodes_by_index[11] = get_node_or_null("GeneratedRoof")

	# A continued game (SaveManager): the build above always places every cassette, so that the
	# same seed walks the random generator the same way - the ones already taken go now.
	for taken in GameStateManager.taken_cassettes:
		var taken_floor = _floor_nodes_by_index.get(taken[0])
		var cassette = taken_floor.get_node_or_null("Cassette_" + str(taken[1])) if is_instance_valid(taken_floor) else null
		if cassette:
			cassette.free()
	randomize() # everything from here on (which room the secret door picks, ...) is free again

	_light_y_step = y_step
	# Every light defaults to visible=true when created - explicitly turn all of them off
	# before lighting just the starting floor, otherwise _set_lit_floor (which only turns
	# off the *previous* floor) would leave every other floor lit until the player has
	# physically visited and left it once.
	for floor_lights in _floor_lights_by_index.values():
		for light in floor_lights:
			light.visible = false
	_lit_floor_index = -1
	_set_lit_floor(floor_number)

	call_deferred("_move_player", f_scale)

# The generated node of one floor (1..10), or null. For code outside this script that needs to
# look at what is on a floor - terminal_ui.gd lists the tapes still lying around on it.
func get_floor_node(floor_num: int) -> Node3D:
	var floor_node = _floor_nodes_by_index.get(floor_num)
	return floor_node if is_instance_valid(floor_node) else null

func _find_lights(node: Node, out: Array) -> void:
	if node is Light3D:
		out.append(node)
	for child in node.get_children():
		_find_lights(child, out)

func _set_lit_floor(floor_index: int) -> void:
	if floor_index == _lit_floor_index:
		return
	if _floor_lights_by_index.has(_lit_floor_index):
		for light in _floor_lights_by_index[_lit_floor_index]:
			light.visible = false
	if _floor_lights_by_index.has(floor_index):
		for light in _floor_lights_by_index[floor_index]:
			light.visible = true
	_lit_floor_index = floor_index
	_apply_floor_visibility()

func _apply_floor_visibility() -> void:
	for i in _floor_nodes_by_index:
		var floor_node = _floor_nodes_by_index[i]
		if is_instance_valid(floor_node):
			var shown: bool = not _floor_culling_enabled or absi(i - _lit_floor_index) <= 1
			floor_node.visible = shown
			# A robot on a floor nobody can see has nobody to hunt - no point running its
			# physics, navigation and sensors.
			for child in floor_node.get_children():
				if child.is_in_group("enemies"):
					child.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED

var _first_frame_logged: bool = false

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _light_y_step <= 0.0:
		return
	if not _first_frame_logged:
		_first_frame_logged = true
		print("[perf] first frame at ", Time.get_ticks_msec(), " ms since engine start")
	var player = get_node_or_null("../../Player")
	if not player:
		if get_tree() and get_tree().current_scene:
			player = get_tree().current_scene.get_node_or_null("Player")
	if not player:
		return
	var floor_index = int(round(player.global_position.y / _light_y_step)) + floor_number
	floor_index = clampi(floor_index, 1, 10)
	_set_lit_floor(floor_index)

	if OS.is_debug_build():
		_perf_log_timer -= delta
		if _perf_log_timer <= 0.0:
			_perf_log_timer = PERF_LOG_INTERVAL
			print("[perf] fps=", Engine.get_frames_per_second(),
				" draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				" objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				" floor=", _lit_floor_index, " floor_culling=", _floor_culling_enabled)

func _build_floor_geometry(f_num: int, y_offset: float, suffix: String, c_color: Color, is_empty: bool, f_scale: float) -> Node3D:
	return HotelGeometryBuilder.build_floor_geometry(self, f_num, y_offset, suffix, c_color, is_empty, f_scale)
func _move_player(f_scale: float) -> void:
	var player = get_node_or_null("../../Player")
	if not player:
		if get_tree() and get_tree().current_scene:
			player = get_tree().current_scene.get_node_or_null("Player")

	if player:
		var p_spawn = Vector3(0, 2.0, 0) * f_scale
		# Spawn inside the same room as Cassette #1, not the corridor - no room/corridor
		# coordinates change, this just picks where inside the level the player starts.
		# Uses the exact same "closest wardrobe to world origin" pick _spawn_cassettes()
		# uses for Cassette #1, so it's always the room that cassette actually ends up in.
		var main_floor = find_child("GeneratedFloor_Main", true, false)
		if main_floor:
			var wardrobes: Array = []
			_find_props(main_floor, "Wardrobe", wardrobes)
			var chosen_wardrobe = _closest_to_spawn(wardrobes)
			if chosen_wardrobe:
				# Wardrobe's +Z (its own basis) faces into the room, away from the wall
				# it's backed against - stepping forward along it lands on open floor.
				p_spawn = chosen_wardrobe.global_position + chosen_wardrobe.global_basis.z * 1.5
				p_spawn.y = 2.0 * f_scale
		player.global_position = p_spawn
		if "velocity" in player:
			player.velocity = Vector3.ZERO
		# A new game starts in the wake-up room instead: across the room from that wardrobe,
		# facing the wall, with empty hands (see wake_up_room.gd).
		if is_instance_valid(_wake_up_room):
			_wake_up_room.place_player(player)
		print("Player moved to: ", p_spawn)

		# floor_number defaults to 4 and this is always that floor's own instance
		# ("GeneratedFloor_Main" sits at world Y=0 - see the i == floor_number check in
		# _generate_level()), so p_spawn IS floor 4's spawn point. Cached for
		# stairs_fall_catcher.gd to rescue a player who fell through a stairwell shaft.
		GameStateManager.floor4_spawn_position = p_spawn

		# Reactive line for the very first moment of the game - the player waking up with no
		# memory (LORE.md's "Концепция и Сеттинг"). Fired here, not in some node's own _ready(),
		# because this is the exact point the player is actually placed in the world for the
		# first time - trigger_alex_line()'s own at-most-once guard keeps a level reload from
		# repeating it.
		DialogSystem.trigger_alex_line("floor4_start")

		# A continued game (SaveManager): not the wake-up room but the elevator of the floor
		# the save was made on - the spot every trap returns the hero to, so it is always
		# safe, whatever the floor's trap is doing. The roof and the lab levels have no
		# elevator stop of their own: from there it is floor 10's and the lobby's.
		if SaveManager.resuming:
			SaveManager.resuming = false
			var resume_floor: int = clampi(GameStateManager.current_floor, 1, 10)
			if resume_floor != GameStateManager.current_floor:
				GameStateManager.current_floor = resume_floor
			var resume_y: float = (resume_floor - floor_number) * (corridor_height + floor_thickness) * f_scale
			player.global_position = Vector3(HotelConstants.ELEVATOR_CENTER_X * f_scale, resume_y + 0.1, (HotelConstants.ELEVATOR_CENTER_Z + 2.0) * f_scale)
			player.rotation.y = PI # facing out of the lift lobby, down the corridor
			print("[generator] continued game: player placed by the elevator of floor ", resume_floor, " at ", player.global_position)

func _generate_maintenance_room(parent: Node, f_scale: float, height: float, thickness: float, wall_mat: Material) -> void:
	HotelBlockBuilder.generate_maintenance_room(self, parent, f_scale, height, thickness, wall_mat)

func _generate_elevator(parent: Node, f_scale: float) -> void:
	HotelBlockBuilder.generate_elevator(self, parent, f_scale)

		# Floor buttons are NOT created here. elevator_shaft.tscn already ships a real,
		# wired-up "ButtonFloor4" template under ElevatorPanel, and elevator_controller.gd's
		# _setup_buttons() duplicates it for floors 1-10 and connects button_pressed itself.
		# This function used to *also* spawn a second, disconnected AnimatableBody3D button
		# almost exactly on top of the real one (off by 1cm) - it never fired
		# _on_button_pressed (nothing connected to it) and was the reason a "phantom" button
		# hitbox could be interacted with near the panel without doing anything.

func _generate_north_stairs(parent: Node, f_scale: float, f_num: int) -> void:
	HotelBlockBuilder.generate_north_stairs(self, parent, f_scale, f_num)

func _generate_south_stairs_wall(parent: Node, f_scale: float, height: float, thickness: float, wall_mat: Material) -> void:
	var z_pos = HotelConstants.SOUTH_STAIRS_ZONE_Z_START * f_scale + (thickness / 2.0)
	var door_w = 1.2 * f_scale
	var door_h = 2.2 * f_scale

	var x_left = HotelConstants.CORRIDOR_WEST_EDGE_X * f_scale
	var x_right = HotelConstants.CORRIDOR_EAST_EDGE_X * f_scale
	var x_center = HotelConstants.SOUTH_STAIRS_DOOR_CENTER_X * f_scale
	
	var left_w = (x_center - door_w / 2.0) - x_left
	var left_cx = x_left + (left_w / 2.0)
	
	var right_w = x_right - (x_center + door_w / 2.0)
	var right_cx = x_right - (right_w / 2.0)
	
	_create_static_box(parent, "SouthStairsWall_Left", Vector3(left_cx, height / 2.0, z_pos), Vector3(left_w, height, thickness), wall_mat)
	_create_static_box(parent, "SouthStairsWall_Right", Vector3(right_cx, height / 2.0, z_pos), Vector3(right_w, height, thickness), wall_mat)
	
	if height > door_h:
		var lintel_h = height - door_h
		var lintel_y = door_h + (lintel_h / 2.0)
		_create_static_box(parent, "SouthStairsWall_Lintel", Vector3(x_center, lintel_y, z_pos), Vector3(door_w, lintel_h, thickness), wall_mat)

	# Corridor is north of this wall (smaller Z), so the door's basis.z (its "outward"
	# reference direction per door.gd) needs to point -Z: rotation.y = PI.
	# door.tscn's native panel is 1.0 wide x 2.2 tall x 0.1 thick - scale.x stretches it
	# to this doorway's width (door_w), scale.y/z match the same f_scale as everything
	# else this function builds (door_h is already 2.2*f_scale).
	var door_scene = load("res://entities/props/door.tscn")
	if door_scene:
		var door_inst = door_scene.instantiate()
		door_inst.name = "SouthStairsDoor"
		# See _generate_maintenance_room() for why this must happen before add_child().
		door_inst.position = Vector3(x_center, 0, z_pos)
		door_inst.rotation.y = PI
		door_inst.scale = Vector3(door_w, f_scale, f_scale)
		parent.add_child(door_inst)

func _generate_south_stairs_ramp(parent: Node, f_scale: float, height: float, floor_thick: float, floor_mat: Material) -> void:
	HotelBlockBuilder.generate_south_stairs_ramp(self, parent, f_scale, height, floor_thick, floor_mat)

# Locks South Stairs floor-hopping at floor f_num's own doorway - see stairs_gate.gd for
# the actual check/teleport. Sized to span the full doorway so the player can't sidestep it.
func _add_south_stairs_gate(parent: Node, f_num: int, f_scale: float) -> void:
	var z_pos = HotelConstants.SOUTH_STAIRS_ZONE_Z_START * f_scale
	var x_center = HotelConstants.SOUTH_STAIRS_DOOR_CENTER_X * f_scale
	var door_w = 1.2 * f_scale
	var door_h = 2.2 * f_scale

	var gate = Area3D.new()
	gate.name = "SouthStairsGate"
	gate.collision_layer = 0
	gate.collision_mask = 1 # Player layer
	gate.set_script(load("res://scripts/levels/blocks/stairs_gate.gd"))
	gate.floor_num = f_num
	gate.y_step = HotelConstants.BASE_FLOOR_TO_FLOOR_HEIGHT * f_scale
	gate.position = Vector3(x_center, door_h / 2.0, z_pos)

	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(door_w, door_h, 1.0 * f_scale)
	coll.shape = shape
	gate.add_child(coll)

	parent.add_child(gate)

# Floor 3's own "endless corridor" nightmare: until its 3 tapes are collected, this splits the
# main corridor in half at its own center (z_main_pos in _build_floor_geometry - reused here as
# a plain constant since that local var isn't in scope, but it's the same for every floor - just
# the corridor's own layout, not floor-4-specific) and bounces the player back whenever they cross
# it, keeping the elevator and North Stairs (the north end) permanently just out of reach - the
# corridor never actually gets you there, no matter how far you walk. Percentages per the original
# request: South Stairs' own Z (HotelConstants.SOUTH_STAIRS_ZONE_Z_START) is 0%, this barrier's own position is
# 100%, and crossing it always sends the player back to the 50% mark - halfway back toward the
# South Stairs end, comfortably clear of the barrier so it doesn't immediately re-trigger.
# Deliberately floor 3, not floor 4 (moved 2026-08-23, corrected per user report) - floor 4 is the
# starting floor and is meant to be fully open with no corridor gating; this nightmare belongs to
# the floor reached through the secret exit door (_create_exit_portal(), always floor 3 today),
# pairing with that door's own "leads to an unknown room, wherever the dice landed" nightmare -
# the South Stairs door on floor 3 stays reachable from the south side regardless of where that
# door ended up.
func _add_floor3_corridor_barrier(parent: Node, f_scale: float) -> void:
	HotelTrapBuilder.add_floor3_corridor_barrier(self, parent, f_scale)

# One CRT computer terminal per floor (every floor except 1 - empty_box_mode returns out of
# _build_floor_geometry before this ever runs - and the roof, generated by a wholly separate
# function). Reads out one of the log entries from LORE.md's "Текстовые логи в CRT-терминалах"
# on interact (crt_terminal.gd) - a real, if simple, payoff for content that existed in the lore
# doc but was never actually reachable in-game.
#
# Anchored to DoubleRoom orig_num 406 (z=10.0, never mirrored - see HotelConstants.DOUBLE_ROOM_LAYOUT), which
# exists identically on every floor, mounted flush against the OUTSIDE (corridor-facing) surface
# of that room's own RoomEastWall (local X=4.8, size.x=0.2 -> outer face at local X=4.9) so it
# stands in the corridor without touching the wall's own geometry at all - no CSG, no risk of the
# "whole combined shape vanishes" fragility that's bitten this project before. Placed at local
# Z=2.0 (room spans Z 0..10), well clear of that room's own RoomDoorHole at Z=8.5.
func _add_floor_terminal(parent: Node, f_scale: float, at: Vector3 = Vector3.INF, rot_y: float = 0.0) -> void:
	HotelPropSpawner.add_floor_terminal(parent, f_scale, at, rot_y)

func _generate_double_room(parent: Node, f_scale: float, f_num: int, orig_num: int) -> void:
	HotelRoomBuilder.generate_double_room(self, parent, f_scale, f_num, orig_num)

func _generate_single_room(parent: Node, f_scale: float, f_num: int, orig_num: int) -> void:
	HotelRoomBuilder.generate_single_room(self, parent, f_scale, f_num, orig_num)


# Floor 8's nightmare - see name_door_trap.gd for the rule. Every room door gets a surname
# instead of its number and a trigger behind it; one random room is the hero's own, and
# _spawn_cassettes_other_floor() puts two of the floor's tapes in it (the third is always in
# the maintenance room, which has neither a plate nor a trigger). The surnames themselves are
# in ui_strings.json (floor8_own_name / floor8_other_names).
func _add_name_doors(parent: Node3D, f_num: int, f_scale: float) -> void:
	HotelTrapBuilder.add_name_doors(self, parent, f_num, f_scale)

# Floor 5's nightmare - see room_shuffle_trap.gd for the rule. Gives every room on the floor a
# trap just inside its doorway, and seals one random room's door from the corridor side so that
# room can only be reached through the trap; _spawn_cassettes_other_floor() puts a tape in it.
# Coordinates are each room's own local ones (double_room.tscn / single_room.tscn), mapped
# through the room's transform so mirrored rooms come out right; the triggers themselves hang
# off the floor node, not the room, to keep physics shapes out from under a mirrored scale.
var _sealed_room_door: Node = null

func _add_room_shuffle_trap(parent: Node3D, f_num: int) -> void:
	HotelTrapBuilder.add_room_shuffle_trap(self, parent, f_num)

func _create_static_box(parent: Node, node_name: String, pos: Vector3, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> void:
	HotelSpecialFloorBuilder.create_static_box(parent, node_name, pos, size, mat, rot)

func _find_props(node: Node, prop_name: String, arr: Array) -> void:
	HotelPropSpawner.find_props(node, prop_name, arr)

# Per LORE.md, Cassette #1 ("Личность") is found in the starting room's furniture and
# Cassette #2 ("Инцидент") is nearby in the corridor - both close to where the player actually
# appears. The player spawns at the same world (X=0, Z=0) on every floor (see _move_player()),
# so "closest to spawn" is a stand-in for "in/near the starting room" that works on any floor,
# not just the one the player happens to be reading this on.
func _closest_to_spawn(props: Array) -> Node:
	return HotelPropSpawner.closest_to_spawn(props)

# Used for cassette placement on every floor except 4 (see _spawn_cassettes_other_floor()) -
# those floors have no "closest to spawn" relationship to preserve, so a genuinely random pick
# keeps their layout from being predictable across floors.
func _random_from(props: Array) -> Node:
	return HotelPropSpawner.random_from(props)

func _spawn_cassettes(parent: Node, f_scale: float, f_num: int) -> void:
	HotelPropSpawner.spawn_cassettes(parent, f_scale, f_num)

# The game's tutorial - see wake_up_room.gd. The room is the one the player starts in, i.e. the
# one whose wardrobe holds Cassette #1 (same pick as _spawn_cassettes_start_floor() and
# _move_player()), so it has to come after the cassettes. A new game only: a continued one puts
# the hero by an elevator (_move_player()), and a room locked from the inside with the pistol in
# it would then be a room he could never get into.
var _wake_up_room: Node3D = null

func _add_wake_up_room(parent: Node3D) -> void:
	_wake_up_room = null
	if SaveManager.resuming:
		GameStateManager.wake_up_done = true
	if GameStateManager.wake_up_done:
		return
	var wardrobes: Array = []
	_find_props(parent, "Wardrobe", wardrobes)
	var start_wardrobe = _closest_to_spawn(wardrobes)
	# wake_up_room.gd is laid out for a single room, which is what the starting room is.
	if start_wardrobe == null or not start_wardrobe.get_parent().name.begins_with("SingleRoom_"):
		push_warning("[generator] no wake-up room: the starting room is not a single room")
		return
	_wake_up_room = Node3D.new()
	_wake_up_room.name = "WakeUpRoom"
	_wake_up_room.set_script(load("res://scripts/levels/blocks/wake_up_room.gd"))
	_wake_up_room.room = start_wardrobe.get_parent()
	parent.add_child(_wake_up_room)

func _spawn_cassettes_start_floor(parent: Node, f_scale: float, scene: PackedScene) -> void:
	HotelPropSpawner.spawn_cassettes_start_floor(parent, f_scale, scene)

# Every floor except 4 (see _spawn_cassettes()): one cassette on a table in a random room, one in
# the maintenance room, one in a wardrobe in a random room - none of floor 4's "closest to spawn"
# logic applies since the player doesn't start on these floors.
func _spawn_cassettes_other_floor(parent: Node, f_scale: float, scene: PackedScene) -> void:
	HotelPropSpawner.spawn_cassettes_other_floor(parent, f_scale, scene)

func _spawn_cerberus(parent: Node, f_scale: float) -> void:
	HotelPropSpawner.spawn_cerberus(parent, f_scale)

# Floor 6's nightmare - see sleeper_cerberus.gd for the rule. Four of them stand along the main
# corridor, alternating sides so none blocks the way. Corridor only, on purpose: a sleeper shut
# inside a room could never be lured away from it (closed doors are solid to the navmesh), so
# taking a tape there would be a guaranteed catch instead of a decision.
const SLEEPER_POSTS: Array = [Vector2(-0.6, -16.0), Vector2(2.8, -5.0), Vector2(-0.6, 7.0), Vector2(2.8, 19.0)] # X, Z

func _spawn_sleepers(parent: Node3D, f_scale: float, off_flag: StringName) -> void:
	HotelPropSpawner.spawn_sleepers(parent, f_scale, off_flag)

# Floor 7's nightmare - see blackout_trap.gd for the rule. It gets this floor's own lights (the
# same list _set_lit_floor() switches) and the glowing ceiling panels that go with them, and the
# same "back by the elevator" spot floor 6's sleepers use.
func _add_blackout_trap(parent: Node3D, f_num: int, lights: Array, f_scale: float) -> void:
	HotelTrapBuilder.add_blackout_trap(parent, f_num, lights, f_scale)

# Floor 9's sweeping ceiling units (sweep_camera_trap.gd) and floor 10's advancing edge
# (edge_wall_trap.gd): one node each, sitting at the floor's own origin so the script can work
# in floor-local coordinates. Both put a caught player back by that floor's elevator.
func _add_floor_wide_trap(parent: Node3D, f_num: int, f_scale: float) -> void:
	HotelTrapBuilder.add_floor_wide_trap(self, parent, f_num, f_scale)

# The ground-floor lobby (floor 1 only). Plan, north on the left as the owner drew it:
#
#     north stairs + lift | ......... main hall ......... | south stairs
#                         |        [reception] [aquarium] |        <- east wall
#                         |______      ______ ____________|
#                                |    |                             <- west wall
#                                |    |  corridor, straight across from the reception
#                                |door|  main entrance at its end, under the turrets
#
# The hall runs along the same axis as every floor's corridor, between the lift at the north end
# and the second staircase at the south end; in front of the lift it is as wide as the lift
# lobby of the floors above. The rest of the floor's box is walled off. Coordinates are the
# floor's own, unscaled meters, like the layout constants at the top of this file.

func _build_lobby(parent: Node3D, f_scale: float, height: float, wall_mat: Material) -> void:
	HotelSpecialFloorBuilder.build_lobby(parent, f_scale, height, wall_mat)
# The laboratory: two levels under the lobby, reached only by the second lift. Both are one hall
# across the whole footprint of the building.
#   Level -1 - the open-plan office: rows of desks, the empty crates the Cerberus units came in,
#              and a terminal with the lab's own documents (which say what the units are for).
#   Level -2 - the plant: glowing tanks like the lobby's aquarium, instrument racks, and the
#              installation in the middle with its three consoles. Switching them off in order
#              ends the game's situation; the way out is then the lobby's main entrance.
# No tapes down here - by now the hero's memory is whole; what is left is documents.
# Built as children of floor 1's node, in its coordinates: level -1's floor is LAB_LEVEL_DROP
# below the lobby's, level -2's twice that.
const LAB_LEVEL_DROP: float = 4.5
const LAB_LIFT_X: float = 4.85     # the second lift's doors are in the lobby's east hall wall, at Z=0
const LAB_ARRIVE_X: float = 4.1    # where it lets the player out, on every level (behind the lobby desk)

# A glowing tank with something in it - the same thing the lobby's aquarium is.
func _add_lab_tank(parent: Node3D, tank_name: String, center: Vector3, size: Vector3, f_scale: float, parts_script: Script) -> void:
	HotelSpecialFloorBuilder.add_lab_tank(parent, tank_name, center, size, f_scale, parts_script)
func _build_lab(parent: Node3D, f_scale: float) -> void:
	HotelSpecialFloorBuilder.build_lab(parent, f_scale)

func _generate_roof(y_offset: float, f_scale: float) -> void:
	HotelRoofBuilder.generate_roof(self, y_offset, f_scale)
# What stands on the roof: a bulkhead over each stairwell (so the stairs come out through a
# door instead of an open hole in the slab) and the elevator machine room over the lift shaft,
# with the code plate inside. Coordinates are the roof node's own - Y=0 is the roof surface.
const ROOF_ROOM_HEIGHT: float = 2.6
const ROOF_FLOOR_INDEX: int = 11 # what stairs_gate.gd / GameStateManager call the roof

func _build_roof_structures(parent: Node3D, f_scale: float, mat: Material) -> void:
	HotelRoofBuilder.build_roof_structures(self, parent, f_scale, mat)
# Fires every time ANY floor's 3 tapes are all collected (see GameStateManager.collect_tape()) -
# two INDEPENDENT rewards, each with its own one-time guard, since they no longer happen on the
# same floor (corrected 2026-08-23 per user report - floor 4, the starting floor, must stay fully
# open with no corridor gating at all):
#   1. The first time EVER any floor's tapes complete (in practice always floor 4, the only floor
#      unlocked at game start) - punches a doorway through a random room's OUTER wall on that
#      floor and connects it to a random room on floor 3 (_create_exit_portal()), an unmarked
#      door to an unknown room, permanently widening the stairs-access range to include floor 3
#      once actually walked through (secret_portal.gd calls GameStateManager.unlock_floor()).
#      Gated by secret_portal_active so it only ever happens once.
#   2. The first time floor 3's OWN tapes complete - floor 3's corridor-splitting barrier
#      (_add_floor3_corridor_barrier(), corridor_barrier.gd) switches off outright, and floor 5
#      unlocks immediately - no need to walk anywhere first, collecting the tapes is the whole
#      trigger. Gated separately by floor3_corridor_unlocked, since by the time floor 3 is even
#      reachable, secret_portal_active from event 1 is already true and would otherwise skip this.
func _on_all_tapes_collected() -> void:
	if not GameStateManager.secret_portal_active:
		GameStateManager.secret_portal_active = true

		var is_double = randi() % 2 == 0
		var layout = HotelConstants.DOUBLE_ROOM_LAYOUT if is_double else HotelConstants.SINGLE_ROOM_LAYOUT
		var keys = layout.keys()

		GameStateManager.secret_portal_floor = GameStateManager.current_floor
		GameStateManager.secret_portal_is_double = is_double
		GameStateManager.secret_portal_room_num = keys[randi() % keys.size()]
		GameStateManager.secret_portal_target = _pick_random_floor3_target()
		GameStateManager.secret_portal_target_floor = 3

		_create_exit_portal()
		# What just happened, in Alex's own words - the tape's text no longer has to say it.
		DialogSystem.trigger_alex_line("floor4_done")

	if GameStateManager.current_floor == 3 and not GameStateManager.floor3_corridor_unlocked:
		GameStateManager.floor3_corridor_unlocked = true
		GameStateManager.unlock_floor(5)
		DialogSystem.trigger_alex_line("floor3_done")

	# 3. Floor 5's own tapes - its room-shuffling trap (room_shuffle_trap.gd) switches off, the
	#    sealed room's door opens normally again, and floor 6 unlocks.
	if GameStateManager.current_floor == 5 and not GameStateManager.floor5_rooms_unlocked:
		GameStateManager.floor5_rooms_unlocked = true
		if is_instance_valid(_sealed_room_door):
			_sealed_room_door.locked_from_corridor = false
		GameStateManager.unlock_floor(6)
		DialogSystem.trigger_alex_line("floor5_done")

	# 4. Floor 6's own tapes - its sleepers (sleeper_cerberus.gd) switch off for good, and
	#    floor 7 unlocks.
	if GameStateManager.current_floor == 6 and not GameStateManager.floor6_sleepers_off:
		GameStateManager.floor6_sleepers_off = true
		GameStateManager.unlock_floor(7)
		DialogSystem.trigger_alex_line("floor6_done")

	# 5. Floor 7's own tapes - its blackouts (blackout_trap.gd) stop for good, floor 8 unlocks.
	if GameStateManager.current_floor == 7 and not GameStateManager.floor7_lights_steady:
		GameStateManager.floor7_lights_steady = true
		GameStateManager.unlock_floor(8)
		DialogSystem.trigger_alex_line("floor7_done")

	# 6. Floor 8's own tapes - its name doors (name_door_trap.gd) let anyone through, and the
	#    elevator can go DOWN to floor 2. Floors are unlocked as one contiguous range, so this
	#    is the one place the range grows downward - floor 2 sits right under the open floor 3.
	if GameStateManager.current_floor == 8 and not GameStateManager.floor8_named:
		GameStateManager.floor8_named = true
		GameStateManager.unlock_floor(2)
		DialogSystem.trigger_alex_line("floor8_done")

	# 7. Floor 2's own tapes - "that night" stops repeating: its sleepers and blackouts (the
	#    floor 6 and floor 7 traps together) switch off, and floor 9 unlocks.
	if GameStateManager.current_floor == 2 and not GameStateManager.floor2_done:
		GameStateManager.floor2_done = true
		GameStateManager.unlock_floor(9)
		DialogSystem.trigger_alex_line("floor2_done")

	# 8. Floor 9's tapes stop its sweeping units (sweep_camera_trap.gd) and unlock floor 10;
	#    floor 10's stop its advancing edge (edge_wall_trap.gd).
	#    Floor 10 is the top of the route (4-3-5-6-7-8-2-9-10) and its tapes also open the roof,
	#    where the lift machine room holds the code that sends the elevator to floor 1
	#    (roof_code_plate.gd).
	if GameStateManager.current_floor == 9 and not GameStateManager.floor9_cameras_off:
		GameStateManager.floor9_cameras_off = true
		GameStateManager.unlock_floor(10)
		DialogSystem.trigger_alex_line("floor9_done")
	if GameStateManager.current_floor == 10 and not GameStateManager.floor10_edge_stopped:
		GameStateManager.floor10_edge_stopped = true
		# The roof is "floor 11" to the stair gates (_build_roof_structures()) - this is what
		# lets the player through the doors at the top of both stairwells.
		GameStateManager.unlock_floor(ROOF_FLOOR_INDEX)
		DialogSystem.trigger_alex_line("floor10_done")

# Rebuilds the same doorway from GameStateManager's persisted secret_portal_* fields - called
# both right after _on_all_tapes_collected() rolls them, and from _ready() if this level scene
# reloads after the door already exists (so it doesn't move to a new random spot on reload).
func _create_exit_portal() -> void:
	HotelPortalSpawner.create_exit_portal(self)
# Picks a random room on floor 3 specifically (per the request this implements) and a safe
# standing spot just inside it - same relative offsets already proven by the room-to-room secret
# portal this replaces.
func _pick_random_floor3_target() -> Vector3:
	return HotelPortalSpawner.pick_random_floor3_target(self)
