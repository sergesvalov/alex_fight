@tool
extends Node3D
class_name HotelLevelGenerator

const CsgBaker = preload("res://scripts/levels/csg_baker.gd")
const FloorMap = preload("res://scripts/levels/floor_map.gd")

# Small vertical offset to prevent Z-fighting between the ceiling of one floor
# and the floor slab of the floor above on Android (gl_compatibility / 16-bit depth).
const CEIL_BIAS: float = 0.001

# ============================================================================
# LAYOUT CONSTANTS
# Unscaled meters - every local var built from these still multiplies by f_scale,
# same as before. Centralized here because several of these numbers used to be
# hand-copied into 2-3 places with nothing linking them - that's exactly how the
# elevator's duplicate phantom button (two independently-typed positions) happened.
# (A supposed "west wall dead zone" was also chased here at one point - it never
# existed; see the DOUBLE_ROOM_BASE_X note below for what that mistake actually was.)
# If you're about to hardcode a coordinate that already has a name below, reference it.
# World axes: +X = east, -X = west, +Z = south, -Z = north (see AGENTS.md).
# ============================================================================

const BASE_CORRIDOR_HEIGHT: float = 4.0
const BASE_FLOOR_THICKNESS: float = 0.5
# Full floor-to-floor height (room height + floor slab). elevator_controller.gd has no
# generator instance to ask, so it reads this directly as
# HotelLevelGenerator.BASE_FLOOR_TO_FLOOR_HEIGHT - keep it in sync with the two consts above.
const BASE_FLOOR_TO_FLOOR_HEIGHT: float = BASE_CORRIDOR_HEIGHT + BASE_FLOOR_THICKNESS  # 4.5

const BUILDING_LENGTH_Z: float = 60.0   # full north-south extent, Z = -30..+30
const BUILDING_WIDTH_X: float = 25.3    # symmetric width, half_x = 12.65 on each side.
# DoubleRoom's true west edge (from its own RoomNorthWall/RoomSouthWall span, not
# WCWestWall - that's just the WC nook's internal partition) sits at
# DOUBLE_ROOM_BASE_X - 4.9 = -12.55, i.e. 0.1m inside the west wall's inner face
# (-12.65) - same natural clearance as SingleRoom gets on the east side. There is
# NO gap to trim here; a west_trim const briefly existed and was wrong - it was
# derived from mistaking WCWestWall for the room's outer wall, and cut the actual
# west wall in from the real room edge, leaving DoubleRoom's beds outside it.
const NORTH_ZONE_INNER_X: float = -2.55 # Floor_NW/Roof_NW's east edge (corridor side)

const DOUBLE_ROOM_BASE_X: float = -7.65  # DoubleRoom instance anchor (= WCWestWall's local X=0,
                                          # an interior partition; the room's true outer wall is
                                          # 4.9m further west - see BUILDING_WIDTH_X note above)
const SINGLE_ROOM_BASE_X: float = 8.7    # SingleRoom instance X

const CORRIDOR_WEST_EDGE_X: float = -2.75  # DoubleRoom's east (corridor-facing) wall - must
                                            # match double_room.tscn's RoomEastWall
const CORRIDOR_EAST_EDGE_X: float = 4.85   # SingleRoom's west (corridor-facing) wall - must
                                            # match single_room.tscn's RoomWestWall

const NORTH_STAIRS_CENTER_X: float = 1.05
const NORTH_STAIRS_CENTER_Z: float = -30.0

const ELEVATOR_CENTER_X: float = 7.2
const ELEVATOR_CENTER_Z: float = -25.0
# The old single-panel door (native 1.4m mesh, squeezed by a generator-applied X scale down to
# ~1.3m to fit) needed that scale retuned every time the hole size or open_offset changed, and
# still had only ~0.25m of clearance from the car's own side wall when open - see
# elevator_door.tscn's own history. Replaced 2026-08-24 with two panels
# (sliding_door_pair.gd) sized directly at their real width, no generator-side scale hack
# needed any more - removed the constant entirely, not just its usage, since nothing else
# referenced it once tests/test_elevator_alignment.gd was updated for the two-panel layout.

const SOUTH_STAIRS_DOOR_CENTER_X: float = 1.05  # same corridor centerline as north stairs
const SOUTH_STAIRS_ZONE_Z_START: float = 25.0
const SOUTH_STAIRS_ZONE_Z_END: float = 30.0
const SOUTH_STAIRS_RAMP_INNER_X: float = 1.87   # Floor_SW's east edge - shared by both ramps
const SOUTH_STAIRS_LANDING_INNER_X: float = 8.03
const SOUTH_STAIRS_LANDING_OUTER_X: float = 12.65

# Room number -> {z: position along the corridor, mirror: whether scale.z=-1 is applied}.
# Contiguous by design (e.g. 403/405 touch with no gap at z=0) - the missing numbers
# (404, 407, 414, 418, 419) are intentional room-numbering flavor, not physical gaps;
# the blueprint texture (assets/textures/hotel_map.jpg) shows the same skips.
const DOUBLE_ROOM_LAYOUT := {
	401: {"z": -30.0, "mirror": false},
	402: {"z": -20.0, "mirror": false},
	403: {"z": 0.0, "mirror": true},
	405: {"z": 0.0, "mirror": false},
	406: {"z": 10.0, "mirror": false},
	408: {"z": 30.0, "mirror": true},
}
const SINGLE_ROOM_LAYOUT := {
	410: {"z": -20.0, "mirror": false},
	411: {"z": -10.0, "mirror": true},
	412: {"z": -10.0, "mirror": false},
	413: {"z": 0.0, "mirror": true},
	415: {"z": 0.0, "mirror": false},
	416: {"z": 10.0, "mirror": true},
	417: {"z": 15.0, "mirror": true},
	420: {"z": 15.0, "mirror": false},
	421: {"z": 25.0, "mirror": true},
}

# Where along a room's outer wall (local Z from the room's own origin, before mirroring) the
# secret exit door goes - a stretch with no furniture against it. Not the layout "z" itself:
# that's the room's edge, i.e. the partition between two rooms (or the building's corner).
const DOUBLE_ROOM_EXIT_DOOR_LOCAL_Z: float = 5.0   # room center; beds end at Z=2.6
const SINGLE_ROOM_EXIT_DOOR_LOCAL_Z: float = 3.05  # between Table (ends Z=2.43) and Bed (starts Z=3.66)

@export var floor_number: int = 4
@export var floor_thickness: float = BASE_FLOOR_THICKNESS
@export var corridor_height: float = BASE_CORRIDOR_HEIGHT
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
	var parent = Node3D.new()
	parent.name = "GeneratedFloor_" + suffix
	parent.position.y = y_offset
	add_child(parent)
	
	var z_length = BUILDING_LENGTH_Z * f_scale
	var x_width = BUILDING_WIDTH_X * f_scale
	var height = corridor_height * f_scale
	var thickness = wall_thickness * f_scale
	var floor_thick = floor_thickness * f_scale

	var half_x = x_width / 2.0

	var floor_y = -floor_thick / 2.0
	# Pull ceiling down by CEIL_BIAS so its top face is never co-planar with
	# the bottom face of the floor slab one storey above (Android Z-fighting fix).
	var ceil_y = height + (floor_thick / 2.0) - CEIL_BIAS
	
	var floor_mat = StandardMaterial3D.new()
	if not is_empty:
		floor_mat.albedo_texture = carpet_texture
	floor_mat.albedo_color = c_color
	floor_mat.uv1_scale = Vector3(10, 10, 10)
	# Force depth writes on gl_compatibility to prevent texture flickering on Android.
	floor_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	
	var ceil_mat = StandardMaterial3D.new()
	ceil_mat.albedo_texture = ceiling_texture
	ceil_mat.uv1_scale = Vector3(10, 10, 10)
	# Force depth writes and explicit backface culling to prevent bleed-through on Android.
	ceil_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	ceil_mat.cull_mode = BaseMaterial3D.CULL_BACK
	
	var wall_mat = StandardMaterial3D.new()
	if f_num == 1:
		wall_mat.albedo_texture = retro_wall_texture
	else:
		wall_mat.albedo_texture = wall_texture
	wall_mat.uv1_scale = Vector3(15, 3, 1)
	wall_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS

	# 1 & 2. Floor and Ceiling (Split into parts to leave holes for North and South Stairs)
	var z_main_len = 50.18 * f_scale
	var z_main_pos = -0.09 * f_scale
	
	var z_north_len = 4.82 * f_scale
	var z_north_pos = -27.59 * f_scale
	var x_nw_east = NORTH_ZONE_INNER_X * f_scale
	var x_nw_len = x_nw_east + half_x
	var x_nw_pos = (x_nw_east - half_x) / 2.0
	var x_ne_len = 8.0 * f_scale
	var x_ne_pos = 8.65 * f_scale

	var z_sw_len = (SOUTH_STAIRS_ZONE_Z_END - SOUTH_STAIRS_ZONE_Z_START) * f_scale
	var z_sw_pos = (SOUTH_STAIRS_ZONE_Z_START + SOUTH_STAIRS_ZONE_Z_END) / 2.0 * f_scale
	var x_sw_east = SOUTH_STAIRS_RAMP_INNER_X * f_scale
	var x_sw_len = x_sw_east + half_x
	var x_sw_pos = (x_sw_east - half_x) / 2.0

	# Central Main (covers everything from Z=-25.18 to Z=25.0)
	_create_static_box(parent, "Floor_Main", Vector3(0, floor_y, z_main_pos), Vector3(x_width, floor_thick, z_main_len), floor_mat)
	_create_static_box(parent, "Ceiling_Main", Vector3(0, ceil_y, z_main_pos), Vector3(x_width, floor_thick, z_main_len), ceil_mat)

	# The main slab as an occluder: it has no holes (both stairwells are cut out of the separate
	# N/S slabs), so everything on the floor below is hidden behind it.
	var slab_occluder = OccluderInstance3D.new()
	slab_occluder.name = "Occluder_FloorMain"
	var slab_box = BoxOccluder3D.new()
	slab_box.size = Vector3(x_width, floor_thick, z_main_len)
	slab_occluder.occluder = slab_box
	slab_occluder.position = Vector3(0, floor_y, z_main_pos)
	parent.add_child(slab_occluder)

	# South West (covers Z=25.0 to 30.0, X=-12.65 to 1.87)
	_create_static_box(parent, "Floor_SW", Vector3(x_sw_pos, floor_y, z_sw_pos), Vector3(x_sw_len, floor_thick, z_sw_len), floor_mat)
	_create_static_box(parent, "Ceiling_SW", Vector3(x_sw_pos, ceil_y, z_sw_pos), Vector3(x_sw_len, floor_thick, z_sw_len), ceil_mat)
	
	# South Stairs Intermediate Landing (East side). y_landing is the box CENTER, not its
	# walkable surface - the surface sits floor_thick/2 above center, at
	# y_landing + floor_thick/2 = height/2 + floor_thick/2 = (height+floor_thick)/2, which is
	# the true midpoint between this floor's surface (Y=0) and the floor-above's (Y=height+
	# floor_thick). (A previous version set y_landing = (height+floor_thick)/2 directly,
	# mistaking the desired *surface* height for the box's center - that left the landing
	# floor_thick/2 (~0.15-0.25m) too high, forming an unwalkable step where the ramps meet it.)
	var x_landing_len = (SOUTH_STAIRS_LANDING_OUTER_X - SOUTH_STAIRS_LANDING_INNER_X) * f_scale
	var x_landing_pos = (SOUTH_STAIRS_LANDING_INNER_X + SOUTH_STAIRS_LANDING_OUTER_X) / 2.0 * f_scale
	var y_landing = height / 2.0
	_create_static_box(parent, "Landing_SouthStairs", Vector3(x_landing_pos, y_landing, z_sw_pos), Vector3(x_landing_len, floor_thick, z_sw_len), floor_mat)

	# Landing checkpoint (see stairs_gate.gd) - a second floor-lock check on this flat landing,
	# roughly halfway up the flight. Independent of stairs_fall_catcher.gd (that one catches
	# falling through open air on North Stairs specifically) - this instead catches a player who
	# slips slightly past the South Stairs door gate while still walking on solid ground, same
	# "went a bit below/above a locked floor - bounce back" idea, just checked a second time on
	# the one flat spot every up/down trip through this staircase is guaranteed to cross. Skipped
	# on floor 1 (is_empty) like the door/wall/ramp themselves - see the is_empty check a few
	# lines below in this same function.
	if not is_empty:
		var landing_gate = Area3D.new()
		landing_gate.name = "SouthStairsLandingGate"
		landing_gate.collision_layer = 0
		landing_gate.collision_mask = 1 # Player layer
		landing_gate.set_script(load("res://scripts/levels/blocks/stairs_gate.gd"))
		landing_gate.floor_num = f_num
		landing_gate.y_step = BASE_FLOOR_TO_FLOOR_HEIGHT * f_scale
		landing_gate.position = Vector3(x_landing_pos, y_landing + floor_thick / 2.0 + 1.1, z_sw_pos)

		var landing_gate_coll = CollisionShape3D.new()
		var landing_gate_shape = BoxShape3D.new()
		landing_gate_shape.size = Vector3(x_landing_len, 2.2, z_sw_len)
		landing_gate_coll.shape = landing_gate_shape
		landing_gate.add_child(landing_gate_coll)
		parent.add_child(landing_gate)

	# North West (covers Z=-30.0 to -25.2, X=-12.65 to -2.55)
	_create_static_box(parent, "Floor_NW", Vector3(x_nw_pos, floor_y, z_north_pos), Vector3(x_nw_len, floor_thick, z_north_len), floor_mat)
	_create_static_box(parent, "Ceiling_NW", Vector3(x_nw_pos, ceil_y, z_north_pos), Vector3(x_nw_len, floor_thick, z_north_len), ceil_mat)
	
	# North East (covers Z=-30.0 to -25.2, X=4.65 to 12.65)
	_create_static_box(parent, "Floor_NE", Vector3(x_ne_pos, floor_y, z_north_pos), Vector3(x_ne_len, floor_thick, z_north_len), floor_mat)
	_create_static_box(parent, "Ceiling_NE", Vector3(x_ne_pos, ceil_y, z_north_pos), Vector3(x_ne_len, floor_thick, z_north_len), ceil_mat)
	
	# 3. Outer Walls
	var half_z = z_length / 2.0

	var outer_wall_height = height + floor_thick
	var outer_wall_y = (height - floor_thick) / 2.0

	_create_static_box(parent, "Wall_West", Vector3(-half_x - thickness/2.0, outer_wall_y, 0), Vector3(thickness, outer_wall_height, z_length), wall_mat)
	_create_static_box(parent, "Wall_East", Vector3(half_x + thickness/2.0, outer_wall_y, 0), Vector3(thickness, outer_wall_height, z_length), wall_mat)
	_create_static_box(parent, "Wall_North", Vector3(0, outer_wall_y, -half_z - thickness/2.0), Vector3(x_width + thickness * 2.0, outer_wall_height, thickness), wall_mat)
	_create_static_box(parent, "Wall_South", Vector3(0, outer_wall_y, half_z + thickness/2.0), Vector3(x_width + thickness * 2.0, outer_wall_height, thickness), wall_mat)
	
	if f_num == 1:
		_create_static_box(parent, "Floor_NorthStairs", Vector3(NORTH_STAIRS_CENTER_X * f_scale, floor_y, -27.6 * f_scale), Vector3(7.6 * f_scale, floor_thick, 4.8 * f_scale), floor_mat)
		
		# Fill the South Stairs hole for the ground floor
		var x_se_len = 10.78 * f_scale
		var x_se_pos = 7.26 * f_scale
		_create_static_box(parent, "Floor_SouthStairs", Vector3(x_se_pos, floor_y, z_sw_pos), Vector3(x_se_len, floor_thick, z_sw_len), floor_mat)

	# 3.6 Elevator
	_generate_elevator(parent, f_scale)
	
	# 3.7 North Stairs
	_generate_north_stairs(parent, f_scale, f_num)

	if is_empty:
		# Floor 1 has no rooms - it is the lobby. It still needs its own flight of the south
		# stairs (the "second staircase" at the far end of the hall), which the furnished
		# floors get further down.
		_generate_south_stairs_wall(parent, f_scale, height, thickness, wall_mat)
		_generate_south_stairs_ramp(parent, f_scale, height, floor_thick, floor_mat)
		_add_south_stairs_gate(parent, f_num, f_scale)
		_build_lobby(parent, f_scale, height, wall_mat)
		_build_lab(parent, f_scale)
		return parent

	# 3.5 Maintenance Room
	_generate_maintenance_room(parent, f_scale, height, thickness, wall_mat)
	
	# 3.7.5 South Stairs Wall
	_generate_south_stairs_wall(parent, f_scale, height, thickness, wall_mat)
	_generate_south_stairs_ramp(parent, f_scale, height, floor_thick, floor_mat)
	_add_south_stairs_gate(parent, f_num, f_scale)


	for room_num in DOUBLE_ROOM_LAYOUT:
		_generate_double_room(parent, f_scale, f_num, room_num)
	for room_num in SINGLE_ROOM_LAYOUT:
		_generate_single_room(parent, f_scale, f_num, room_num)
	
	# Floor 5 only - must come before the cassettes, which need to know the sealed room.
	if f_num == 8:
		_add_name_doors(parent, f_num, f_scale)
	if f_num == 5:
		_add_room_shuffle_trap(parent, f_num)

	_spawn_cassettes(parent, f_scale, f_num)
	if f_num == 4 and suffix == "Main":
		_add_wake_up_room(parent)
	# The level scene's own floor already has its hand-placed robot (base_hotel_level.tscn's
	# Enemies/Cerberus) - a generated one on top of it would double it up.
	# Floor 6 has no patrol at all - its robots are the sleepers (see sleeper_cerberus.gd).
	if f_num == 6 or f_num == 2:
		_spawn_sleepers(parent, f_scale, &"floor6_sleepers_off" if f_num == 6 else &"floor2_done")
	elif suffix != "Main":
		_spawn_cerberus(parent, f_scale)

	# Floor 3 only - see _add_floor3_corridor_barrier()'s own comment for why.
	if f_num == 3:
		_add_floor3_corridor_barrier(parent, f_scale)

	# Every floor that reaches this line already excludes floor 1 (empty_box_mode returns out of
	# this function before the room loop above) and the roof (a separate function entirely,
	# never calls this one) - exactly "every floor except the roof and floor 1" per the request.
	_add_floor_terminal(parent, f_scale)

	# 5. Floor Map - drawn from this file's own layout constants (see floor_map.gd), so it shows
	# this floor's number and room numbers and can't drift away from what was actually built.
	var map_mesh = MeshInstance3D.new()
	map_mesh.name = "FloorMap"
	var quad = QuadMesh.new()
	quad.size = Vector2(2.0 * FloorMap.SIZE.x / FloorMap.SIZE.y, 2.0) * f_scale

	var map_tex: Texture2D = FloorMap.make_texture(parent, f_num)
	var map_mat = StandardMaterial3D.new()
	map_mat.albedo_texture = map_tex
	# A faint glow of its own, so the plan is readable in an unlit corridor.
	map_mat.emission_enabled = true
	map_mat.emission_texture = map_tex
	map_mat.emission_energy_multiplier = 0.6
	quad.material = map_mat
	map_mesh.mesh = quad

	map_mesh.position = Vector3(-2.74 * f_scale, 2.0 * f_scale, 0.0 * f_scale)
	map_mesh.rotation.y = PI / 2.0
	parent.add_child(map_mesh)

	
	# 6. Propaganda Screen
	var prog_mesh = MeshInstance3D.new()
	prog_mesh.name = "PropagandaScreen"
	var prog_quad = QuadMesh.new()
	prog_quad.size = Vector2(1.5, 2.0)
	
	var prog_mat = StandardMaterial3D.new()
	var prog_tex = load("res://assets/textures/propaganda.jpg")
	if prog_tex:
		prog_mat.albedo_texture = prog_tex
		prog_mat.emission_enabled = true
		prog_mat.emission_texture = prog_tex
		prog_mat.emission_energy_multiplier = 1.0
	else:
		prog_mat.albedo_color = Color(0.2, 0.2, 0.8)
		prog_mat.emission_enabled = true
		prog_mat.emission = Color(0.2, 0.2, 0.8)
	prog_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	prog_quad.material = prog_mat
	prog_mesh.mesh = prog_quad
	prog_mesh.set_script(load("res://scripts/levels/blocks/flicker_material.gd"))
	prog_mesh.position = Vector3(-2.74 * f_scale, 2.0 * f_scale, -15.5 * f_scale)
	prog_mesh.rotation.y = PI / 2.0
	# The top strip of the picture has a scrap of an English poster in it - cropped off.
	prog_mat.uv1_scale = Vector3(1.0, 0.93, 1.0)
	prog_mat.uv1_offset = Vector3(0.0, 0.07, 0.0)
	# The screen is the hotel's internal broadcast: looking at it and interacting plays the
	# address recorded for this floor - see broadcast_screen.gd.
	var broadcast = Area3D.new()
	broadcast.name = "Broadcast"
	broadcast.collision_layer = 4 # same layer vhs_tape.tscn uses - the interact raycast's mask
	broadcast.collision_mask = 0
	broadcast.set_script(load("res://scripts/interactables/broadcast_screen.gd"))
	broadcast.floor_num = f_num
	var broadcast_coll = CollisionShape3D.new()
	var broadcast_shape = BoxShape3D.new()
	broadcast_shape.size = Vector3(1.5, 2.0, 0.2)
	broadcast_coll.shape = broadcast_shape
	broadcast.add_child(broadcast_coll)
	prog_mesh.add_child(broadcast)
	parent.add_child(prog_mesh)

	# 7. Ad Screen
	var ad_mesh = MeshInstance3D.new()
	ad_mesh.name = "AdScreen"
	var ad_quad = QuadMesh.new()
	ad_quad.size = Vector2(2.0, 1.5)
	
	var ad_mat = StandardMaterial3D.new()
	var ad_tex = load("res://assets/textures/coca_cola.jpg")
	if ad_tex:
		ad_mat.albedo_texture = ad_tex
		ad_mat.emission_enabled = true
		ad_mat.emission_texture = ad_tex
		ad_mat.emission_energy_multiplier = 1.0
	else:
		ad_mat.albedo_color = Color(0.8, 0.2, 0.2)
		ad_mat.emission_enabled = true
		ad_mat.emission = Color(0.8, 0.2, 0.2)
	ad_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ad_quad.material = ad_mat
	ad_mesh.mesh = ad_quad
	ad_mesh.position = Vector3(-2.74 * f_scale, 2.0 * f_scale, 13.5 * f_scale)
	ad_mesh.rotation.y = PI / 2.0
	parent.add_child(ad_mesh)

	return parent

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
			player.global_position = Vector3(ELEVATOR_CENTER_X * f_scale, resume_y + 0.1, (ELEVATOR_CENTER_Z + 2.0) * f_scale)
			player.rotation.y = PI # facing out of the lift lobby, down the corridor
			print("[generator] continued game: player placed by the elevator of floor ", resume_floor, " at ", player.global_position)

func _generate_maintenance_room(parent: Node, f_scale: float, height: float, thickness: float, wall_mat: Material) -> void:
	var wall_y = height / 2.0
	_create_static_box(parent, "Maint_Inner_South", Vector3(11.15 * f_scale, wall_y, -20.0 * f_scale), Vector3(3.0 * f_scale, height, thickness), wall_mat)

	# Doorway gap narrowed from 2.0m to a standard 1.2m (matching the stairs doors) so a
	# single door.tscn leaf covers it instead of leaving 0.8m permanently uncovered.
	# Center stays at Z=-23 (unchanged) - only the two wall segments' extents shrank in.
	var door_w = 1.2 * f_scale
	var door_z_center = -23.0 * f_scale
	var gap_min_z = door_z_center - door_w / 2.0
	var gap_max_z = door_z_center + door_w / 2.0
	var north_len = gap_min_z - (-30.0 * f_scale)
	var north_center_z = ((-30.0 * f_scale) + gap_min_z) / 2.0
	var south_len = (-20.0 * f_scale) - gap_max_z
	var south_center_z = (gap_max_z + (-20.0 * f_scale)) / 2.0
	_create_static_box(parent, "Maint_Inner_West_North", Vector3(9.65 * f_scale, wall_y, north_center_z), Vector3(thickness, height, north_len), wall_mat)
	_create_static_box(parent, "Maint_Inner_West_South", Vector3(9.65 * f_scale, wall_y, south_center_z), Vector3(thickness, height, south_len), wall_mat)
	var door_h = 2.2 * f_scale
	if height > door_h:
		var lintel_h = height - door_h
		var lintel_y = door_h + (lintel_h / 2.0)
		_create_static_box(parent, "Maint_Inner_West_Lintel", Vector3(9.65 * f_scale, lintel_y, door_z_center), Vector3(thickness, lintel_h, door_w), wall_mat)

	# Corridor is west of this wall (smaller X), so basis.z needs to point -X: rotation.y = -PI/2.
	var door_scene_maint = load("res://entities/props/door.tscn")
	if door_scene_maint:
		var maint_door_inst = door_scene_maint.instantiate()
		maint_door_inst.name = "MaintenanceDoor"
		# position/rotation/scale MUST be set before add_child(): add_child() fires _ready()
		# synchronously on the whole subtree (including door.gd's AnimatableBody3D), which
		# would otherwise see the door still at its pre-placement identity transform - i.e.
		# sitting at local (0,0,0), right on top of the player's spawn point at world origin.
		maint_door_inst.position = Vector3(9.65 * f_scale, 0, door_z_center)
		maint_door_inst.rotation.y = -PI / 2.0
		maint_door_inst.scale = Vector3(door_w, f_scale, f_scale)
		parent.add_child(maint_door_inst)

	# Storage wardrobes, backs against the building's own east wall (X=12.65), opening
	# facing west into the room. Kept north of the doorway gap (Z -24..-22) for clearance.
	# maintenance_room.tscn (an older, unused standalone scene) had 2 wardrobes here too,
	# but its own wall layout no longer matches this procedurally-built room - these are
	# placed fresh against the room this function actually builds.
	var wardrobe_scene = load("res://entities/props/wardrobe.tscn")
	if wardrobe_scene:
		for i in range(2):
			var wardrobe_inst = wardrobe_scene.instantiate()
			wardrobe_inst.name = "MaintWardrobe" + str(i + 1)
			wardrobe_inst.transform = Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)), Vector3(12.25 * f_scale, 0, (-28.0 + i * 2.5) * f_scale))
			_bake_csg(wardrobe_inst)
			parent.add_child(wardrobe_inst)

func _generate_elevator(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/elevator_shaft.tscn")
	if scene:
		var inst = scene.instantiate()

		# position/scale MUST be set before add_child() - see _generate_maintenance_room()
		# for why (add_child() fires _ready() synchronously on the whole subtree).
		inst.position = Vector3(ELEVATOR_CENTER_X * f_scale, 0, ELEVATOR_CENTER_Z * f_scale)
		inst.scale.z = -1.0

		# ElevatorDoor MUST be added to inst before inst itself is added to parent: adding inst
		# to parent fires elevator_controller.gd's _ready() synchronously, which looks up
		# "ElevatorDoor/AnimatableBody3D" once and caches it in door_animatable - if that lookup
		# happens before this door exists, door_animatable stays null forever, and the whole
		# button-triggered open/close sequence (_run_elevator_sequence/_arrive_and_open) silently
		# never touches the door (interacting with the door directly still works, since that
		# doesn't go through elevator_controller.gd at all).
		var door_scene = load("res://entities/props/elevator_door.tscn")
		if door_scene:
			var door_inst = door_scene.instantiate()
			door_inst.name = "ElevatorDoor"
			door_inst.position = Vector3(0, 0, 0.1 * f_scale)
			inst.add_child(door_inst)

		_bake_csg(inst)
		parent.add_child(inst)

		# Floor buttons are NOT created here. elevator_shaft.tscn already ships a real,
		# wired-up "ButtonFloor4" template under ElevatorPanel, and elevator_controller.gd's
		# _setup_buttons() duplicates it for floors 1-10 and connects button_pressed itself.
		# This function used to *also* spawn a second, disconnected AnimatableBody3D button
		# almost exactly on top of the real one (off by 1cm) - it never fired
		# _on_button_pressed (nothing connected to it) and was the reason a "phantom" button
		# hitbox could be interacted with near the panel without doing anything.

func _generate_north_stairs(parent: Node, f_scale: float, f_num: int) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/north_stairs.tscn")
	if scene:
		var inst = scene.instantiate()
		# position MUST be set before add_child() - see _generate_maintenance_room() for why.
		inst.position = Vector3(NORTH_STAIRS_CENTER_X * f_scale, 0, NORTH_STAIRS_CENTER_Z * f_scale)

		# Обе двери на южной стене (лицом в коридор, +Z, без поворота), ширина проёма 1.2м.
		# Local coords, NOT multiplied by f_scale here: this whole block (like double_room.tscn/
		# single_room.tscn) is static authored content that GlobalConfig.apply_dynamic_scale()
		# rescales on its own via block.gd's _ready() - scaling it again here would double it
		# for any build with a non-default player/floor scale.
		# Created in code, not embedded in north_stairs.tscn - see _add_room_door()'s comment
		# for why (embedding a second door.tscn instance in one scene file loses nodes when
		# packed into an exported PCK).
		var door_scene = load("res://entities/props/door.tscn")
		if door_scene:
			for door_data in [["DoorEast", 2.8], ["DoorWest", -2.8]]:
				var door_inst = door_scene.instantiate()
				door_inst.name = door_data[0]
				door_inst.position = Vector3(door_data[1], 0, 4.9)
				door_inst.scale = Vector3(1.2, 1.0, 1.0)
				inst.add_child(door_inst)

				# Floor-lock gate at this same doorway - see stairs_gate.gd. Left in inst's own
				# UNSCALED local space like the door above - block.gd's apply_dynamic_scale()
				# rescales this whole subtree itself (a plain Area3D with no
				# "door/bed/table/chair/wardrobe" in its name takes the generic Node3D scaling
				# path, not the human-sized prop path).
				var gate = Area3D.new()
				gate.name = door_data[0] + "Gate"
				gate.collision_layer = 0
				gate.collision_mask = 1 # Player layer
				gate.set_script(load("res://scripts/levels/blocks/stairs_gate.gd"))
				gate.floor_num = f_num
				gate.y_step = BASE_FLOOR_TO_FLOOR_HEIGHT * f_scale
				gate.position = Vector3(door_data[1], 1.1, 4.9)

				var gate_coll = CollisionShape3D.new()
				var gate_shape = BoxShape3D.new()
				gate_shape.size = Vector3(1.2, 2.2, 1.0)
				gate_coll.shape = gate_shape
				gate.add_child(gate_coll)
				inst.add_child(gate)

		# Fall-through-the-shaft safety net (see stairs_fall_catcher.gd) - spans this floor's
		# own slice of the stairwell interior (Y 0..4.5, between StairsWestWall/EastWall at
		# X -3.7/+3.7 and StairsSouthWall/north wall at Z 4.9/0.0), same unscaled local space
		# as the door/gate above. Stacking one of these per floor forms one continuous column
		# covering the whole shaft, so a player who falls off a ramp/landing edge anywhere in
		# the building gets caught regardless of which floor they started falling from.
		var fall_catcher = Area3D.new()
		fall_catcher.name = "FallCatcher"
		fall_catcher.collision_layer = 0
		fall_catcher.collision_mask = 1 # Player layer
		fall_catcher.set_script(load("res://scripts/levels/blocks/stairs_fall_catcher.gd"))
		fall_catcher.position = Vector3(0, 2.25, 2.45)

		var fall_coll = CollisionShape3D.new()
		var fall_shape = BoxShape3D.new()
		fall_shape.size = Vector3(7.0, 4.5, 4.6)
		fall_coll.shape = fall_shape
		fall_catcher.add_child(fall_coll)
		inst.add_child(fall_catcher)

		# Landing checkpoints (see stairs_gate.gd) - a second floor-lock check on each of the
		# two flat landings a player walks across climbing this floor's own dog-leg flights
		# (NELanding, NWLanding - see north_stairs.tscn/AGENTS.md's "North Stairs Block Map").
		# Same idea as the South Stairs landing gate in _build_floor_geometry(): catches a
		# player who slips slightly past the DoorEast/DoorWest gates above while still walking
		# on solid ground, distinct from stairs_fall_catcher.gd's job of catching an actual fall
		# through open air. Same unscaled local space as the doors/gates/fall-catcher above.
		for landing_data in [["NELandingGate", Vector3(2.5, 1.5, 0.6)], ["NWLandingGate", Vector3(-2.5, 3.0, 0.6)]]:
			var l_center: Vector3 = landing_data[1]
			var landing_gate = Area3D.new()
			landing_gate.name = landing_data[0]
			landing_gate.collision_layer = 0
			landing_gate.collision_mask = 1 # Player layer
			landing_gate.set_script(load("res://scripts/levels/blocks/stairs_gate.gd"))
			landing_gate.floor_num = f_num
			landing_gate.y_step = BASE_FLOOR_TO_FLOOR_HEIGHT * f_scale
			landing_gate.position = Vector3(l_center.x, l_center.y + 0.1 + 1.1, l_center.z)

			var landing_gate_coll = CollisionShape3D.new()
			var landing_gate_shape = BoxShape3D.new()
			landing_gate_shape.size = Vector3(2.4, 2.2, 1.2)
			landing_gate_coll.shape = landing_gate_shape
			landing_gate.add_child(landing_gate_coll)
			inst.add_child(landing_gate)

		_bake_csg(inst)
		parent.add_child(inst)

func _generate_south_stairs_wall(parent: Node, f_scale: float, height: float, thickness: float, wall_mat: Material) -> void:
	var z_pos = SOUTH_STAIRS_ZONE_Z_START * f_scale + (thickness / 2.0)
	var door_w = 1.2 * f_scale
	var door_h = 2.2 * f_scale

	var x_left = CORRIDOR_WEST_EDGE_X * f_scale
	var x_right = CORRIDOR_EAST_EDGE_X * f_scale
	var x_center = SOUTH_STAIRS_DOOR_CENTER_X * f_scale
	
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
	# Dog-leg staircase, self-contained per floor (same philosophy as north_stairs.tscn's
	# 3 flights: each floor climbs its own full 0 -> floor-to-floor-height run, and stacking
	# floors is what makes it continuous - no geometry is shared with or duplicated by the
	# neighboring floor). One door only, so both flights start/end at the same X as the door
	# area (Floor_SW's edge), not two separate doors like the north stairs.
	#
	# Layout inside the 5m-deep south-stairs zone (Z 25..30), split into two 2.5m bands so
	# the up-flight and the return flight sit side by side instead of stacked (stacking them
	# would need the upper flight to clear headroom over the lower one; side by side avoids
	# that entirely):
	#   Band 1 (Z 25..27.5):  RampA climbs EAST,  X 1.87 -> 8.03,  Y 0 -> mid_y
	#   Landing (full Z 25..30, X 8.03..12.65, Y mid_y): turn here (reuses Landing_SouthStairs)
	#   Band 2 (Z 27.5..30):  RampB climbs WEST,  X 8.03 -> 1.87,  Y mid_y -> full_y
	# RampB's arrival point (X=1.87, Y=full_y) is exactly where the floor-above's own
	# Floor_SW edge sits, so it needs no landing of its own - the next floor provides it.
	var x_inner = SOUTH_STAIRS_RAMP_INNER_X * f_scale      # Floor_SW's east edge
	var x_outer = SOUTH_STAIRS_LANDING_INNER_X * f_scale   # Landing_SouthStairs' west edge
	var mid_y = (height + floor_thick) / 2.0   # Landing_SouthStairs' walkable SURFACE height
	                                            # (its box center, y_landing, sits floor_thick/2
	                                            # below this, at height/2 - see that comment)
	var full_y = height + floor_thick          # this floor's ceiling = next floor's floor

	var band_depth = (SOUTH_STAIRS_ZONE_Z_END - SOUTH_STAIRS_ZONE_Z_START) / 2.0 * f_scale
	var z_band1 = (SOUTH_STAIRS_ZONE_Z_START * f_scale) + band_depth / 2.0  # center of band 1
	var z_band2 = (SOUTH_STAIRS_ZONE_Z_END * f_scale) - band_depth / 2.0    # center of band 2

	var run = x_outer - x_inner
	var ramp_len = sqrt(run * run + mid_y * mid_y)
	var angle_up = atan2(mid_y, run)

	# _create_static_box positions the box by its geometric CENTER, but a player walks on
	# its top face (local +Y), which - once the box is rotated to form the incline - sits
	# slab_half_t away from the center, perpendicular to the slope, not straight up. Naively
	# centering the box on the two floor-surface points (as an earlier version did) leaves
	# the walkable surface short of both ends by about slab_half_t * cos(angle_up), which
	# was enough of a ledge at the landing to block walking up (not down, since a ledge you
	# step down off doesn't stop you, only one you'd have to step up onto does).
	# Shifting the center by this same perpendicular offset (derived from where a box's top
	# face corners land after rotating around Z) puts the actual walking surface exactly on
	# the intended points instead of the box's centerline.
	var slab_half_t = 0.1 * f_scale
	var offset_x = slab_half_t * sin(angle_up)
	var offset_y = slab_half_t * cos(angle_up)

	# RampA: rises to the east, Band 1
	_create_static_box(
		parent, "SouthStairsRampA",
		Vector3((x_inner + x_outer) / 2.0 + offset_x, mid_y / 2.0 - offset_y, z_band1),
		Vector3(ramp_len, slab_half_t * 2.0, band_depth),
		floor_mat,
		Vector3(0, 0, angle_up)
	)

	# RampB: rises to the west, Band 2 - same shape as RampA, mirrored in X and offset up by mid_y
	_create_static_box(
		parent, "SouthStairsRampB",
		Vector3((x_inner + x_outer) / 2.0 - offset_x, mid_y + (full_y - mid_y) / 2.0 - offset_y, z_band2),
		Vector3(ramp_len, slab_half_t * 2.0, band_depth),
		floor_mat,
		Vector3(0, 0, -angle_up)
	)

# Locks South Stairs floor-hopping at floor f_num's own doorway - see stairs_gate.gd for
# the actual check/teleport. Sized to span the full doorway so the player can't sidestep it.
func _add_south_stairs_gate(parent: Node, f_num: int, f_scale: float) -> void:
	var z_pos = SOUTH_STAIRS_ZONE_Z_START * f_scale
	var x_center = SOUTH_STAIRS_DOOR_CENTER_X * f_scale
	var door_w = 1.2 * f_scale
	var door_h = 2.2 * f_scale

	var gate = Area3D.new()
	gate.name = "SouthStairsGate"
	gate.collision_layer = 0
	gate.collision_mask = 1 # Player layer
	gate.set_script(load("res://scripts/levels/blocks/stairs_gate.gd"))
	gate.floor_num = f_num
	gate.y_step = BASE_FLOOR_TO_FLOOR_HEIGHT * f_scale
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
# request: South Stairs' own Z (SOUTH_STAIRS_ZONE_Z_START) is 0%, this barrier's own position is
# 100%, and crossing it always sends the player back to the 50% mark - halfway back toward the
# South Stairs end, comfortably clear of the barrier so it doesn't immediately re-trigger.
# Deliberately floor 3, not floor 4 (moved 2026-08-23, corrected per user report) - floor 4 is the
# starting floor and is meant to be fully open with no corridor gating; this nightmare belongs to
# the floor reached through the secret exit door (_create_exit_portal(), always floor 3 today),
# pairing with that door's own "leads to an unknown room, wherever the dice landed" nightmare -
# the South Stairs door on floor 3 stays reachable from the south side regardless of where that
# door ended up.
func _add_floor3_corridor_barrier(parent: Node, f_scale: float) -> void:
	var mid_z = -0.09 * f_scale # matches z_main_pos - Floor_Main's own Z center
	var south_z = SOUTH_STAIRS_ZONE_Z_START * f_scale
	var return_z = (south_z + mid_z) / 2.0

	var corridor_center_x = (CORRIDOR_WEST_EDGE_X + CORRIDOR_EAST_EDGE_X) / 2.0 * f_scale
	var corridor_width = (CORRIDOR_EAST_EDGE_X - CORRIDOR_WEST_EDGE_X) * f_scale

	var barrier = Area3D.new()
	barrier.name = "Floor3CorridorBarrier"
	barrier.collision_layer = 0
	barrier.collision_mask = 1 # Player layer
	barrier.set_script(load("res://scripts/levels/blocks/corridor_barrier.gd"))
	barrier.return_z = return_z
	barrier.position = Vector3(corridor_center_x, 1.1 * f_scale, mid_z)

	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(corridor_width, 2.2 * f_scale, 1.0 * f_scale)
	coll.shape = shape
	barrier.add_child(coll)

	parent.add_child(barrier)

# One CRT computer terminal per floor (every floor except 1 - empty_box_mode returns out of
# _build_floor_geometry before this ever runs - and the roof, generated by a wholly separate
# function). Reads out one of the log entries from LORE.md's "Текстовые логи в CRT-терминалах"
# on interact (crt_terminal.gd) - a real, if simple, payoff for content that existed in the lore
# doc but was never actually reachable in-game.
#
# Anchored to DoubleRoom orig_num 406 (z=10.0, never mirrored - see DOUBLE_ROOM_LAYOUT), which
# exists identically on every floor, mounted flush against the OUTSIDE (corridor-facing) surface
# of that room's own RoomEastWall (local X=4.8, size.x=0.2 -> outer face at local X=4.9) so it
# stands in the corridor without touching the wall's own geometry at all - no CSG, no risk of the
# "whole combined shape vanishes" fragility that's bitten this project before. Placed at local
# Z=2.0 (room spans Z 0..10), well clear of that room's own RoomDoorHole at Z=8.5.
func _add_floor_terminal(parent: Node, f_scale: float, at: Vector3 = Vector3.INF, rot_y: float = 0.0) -> void:
	# X=5.05 = wall's own outer face (4.9) + half the casing's depth (0.14) - so the casing's
	# BACK sits flush against the wall instead of embedded inside it or floating in mid-corridor.
	var room_world = Vector3(DOUBLE_ROOM_BASE_X, 0, 10.0) * f_scale
	var local_offset = Vector3(5.05, 1.3, 2.0) * f_scale
	var terminal_pos = room_world + local_offset
	if at != Vector3.INF:
		terminal_pos = at * f_scale # the lab's terminal: an explicit spot instead of the corridor one

	var terminal = Area3D.new()
	terminal.name = "CrtTerminal"
	terminal.collision_layer = 4 # same layer vhs_tape.tscn uses - matches the interact raycast/proximity mask
	terminal.collision_mask = 0
	terminal.set_script(load("res://scripts/interactables/crt_terminal.gd"))
	terminal.position = terminal_pos
	terminal.rotation.y = rot_y

	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.3, 0.4, 0.5) * f_scale
	coll.shape = shape
	terminal.add_child(coll)

	# Beige plastic casing - period-accurate for a Soviet-era terminal, distinct from the dark
	# gunmetal used everywhere else (robot, wardrobe) so it reads as "old computer", not "machine".
	var casing_mat = StandardMaterial3D.new()
	casing_mat.albedo_color = Color(0.72, 0.68, 0.56)
	casing_mat.roughness = 0.7
	var casing = MeshInstance3D.new()
	var casing_mesh = BoxMesh.new()
	casing_mesh.size = Vector3(0.28, 0.35, 0.4) * f_scale
	casing_mesh.material = casing_mat
	casing.mesh = casing_mesh
	terminal.add_child(casing)

	# Recessed monochrome-green screen, glowing regardless of room lighting - the classic look
	# for text-only computer terminals of this era, and a color no other emissive element in the
	# hotel currently uses (holograms are cyan, the robot's eye is red, hazard tape is yellow).
	var screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.05, 0.25, 0.08)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.15, 0.9, 0.3)
	screen_mat.emission_energy_multiplier = 1.5
	var screen = MeshInstance3D.new()
	var screen_mesh = BoxMesh.new()
	screen_mesh.size = Vector3(0.02, 0.22, 0.28) * f_scale
	screen_mesh.material = screen_mat
	screen.position = Vector3(0.13, 0.0, 0.0) * f_scale
	screen.mesh = screen_mesh
	terminal.add_child(screen)

	parent.add_child(terminal)

# Adds a door.tscn instance as a child of a room instance, positioned/rotated in the room's
# OWN local space (so it inherits the room's position and mirror scale like every other prop).
# RoomDoor/WCDoor used to be embedded directly in double_room.tscn/single_room.tscn instead,
# but ANY room .tscn that embeds a door.tscn node instance loses nodes once packed into an
# exported PCK (confirmed 2026-08-22 via PackedScene.get_state(), which showed nodes already
# missing from the raw resource before instantiate() ever runs - not an add_child()/instantiate()
# bug on this end). Creating the door in code sidesteps that entirely, the same way
# MaintenanceDoor/SouthStairsDoor/ElevatorDoor already reliably do across all 10 floors.
func _add_room_door(room_inst: Node3D, node_name: String, local_pos: Vector3, rot_y: float, number: String = "") -> void:
	var door_scene = load("res://entities/props/door.tscn")
	if not door_scene: return
	var door_inst = door_scene.instantiate()
	door_inst.name = node_name
	door_inst.position = local_pos
	door_inst.rotation.y = rot_y

	# Room number plate on the corridor side (door.tscn's label sits on the door's +Z face, the
	# side every door's basis.z points at). A mirrored room (scale.z=-1) would render the text
	# mirrored too - flipping the label's own X cancels that out.
	if number != "":
		var label = door_inst.get_node_or_null("AnimatableBody3D/RoomNumberLabel")
		if label:
			label.text = number
			if room_inst.scale.z < 0.0:
				label.scale.x = -1.0

	room_inst.add_child(door_inst)

func _generate_double_room(parent: Node, f_scale: float, f_num: int, orig_num: int) -> void:
	var layout = DOUBLE_ROOM_LAYOUT.get(orig_num)
	if not layout: return
	var scene = load("res://scenes/levels/hotel_siberia/blocks/double_room.tscn")
	if not scene: return
	var inst = scene.instantiate()
	var room_idx = orig_num % 100
	var final_num = f_num * 100 + room_idx
	inst.name = "DoubleRoom_" + str(final_num)

	# position/scale MUST be set before add_child(): add_child() fires _ready() on the whole
	# subtree synchronously, including every door's AnimatableBody3D - any code that reads
	# global_transform in _ready() (including doors) would otherwise see the room still at
	# its pre-move, pre-mirror identity transform.
	inst.position = Vector3(DOUBLE_ROOM_BASE_X * f_scale, 0, layout["z"] * f_scale)
	if layout["mirror"]:
		inst.scale.z = -1.0

	# Проём в RoomEastWall (X=4.8, Z=8.5), коридор к востоку -> basis.z смотрит +X (поворот +90°).
	_add_room_door(inst, "RoomDoor", Vector3(4.8, 0.0, 8.5), PI / 2.0, str(final_num))
	# Проём в WCSouthWall (X=2.35, Z=4.9), номер к югу -> basis.z смотрит +Z (без поворота).
	_add_room_door(inst, "WCDoor", Vector3(2.35, 0.0, 4.9), 0.0)

	_bake_csg(inst)
	parent.add_child(inst)

func _generate_single_room(parent: Node, f_scale: float, f_num: int, orig_num: int) -> void:
	var layout = SINGLE_ROOM_LAYOUT.get(orig_num)
	if not layout: return
	var scene = load("res://scenes/levels/hotel_siberia/blocks/single_room.tscn")
	if not scene: return
	var inst = scene.instantiate()
	var room_idx = orig_num % 100
	var final_num = f_num * 100 + room_idx
	inst.name = "SingleRoom_" + str(final_num)

	# See _generate_double_room() for why this must happen before add_child().
	inst.position = Vector3(SINGLE_ROOM_BASE_X * f_scale, 0, layout["z"] * f_scale)
	if layout["mirror"]:
		inst.scale.z = -1.0

	# Проём в RoomWestWall (X=-3.75, Z=3.5), коридор к западу -> basis.z смотрит -X (поворот -90°).
	_add_room_door(inst, "RoomDoor", Vector3(-3.75, 0.0, 3.5), -PI / 2.0, str(final_num))
	# Проём в WCSouthWall (X=-2.55, Z=2.5), номер к югу -> basis.z смотрит +Z (без поворота).
	_add_room_door(inst, "WCDoor", Vector3(-2.55, 0.0, 2.5), 0.0)

	_bake_csg(inst)
	parent.add_child(inst)

# A two-part trigger for a room's doorway, shared by the floor traps that act on ENTERING a room
# (room_shuffle_trap.gd, name_door_trap.gd): the returned Area3D is a slab 0.35..0.95m inside
# the door, and its "Threshold" child sits in the doorway itself. The scripts arm on the
# threshold and fire on the slab, so walking out (slab first) never triggers them. Positions are
# the room's own local ones mapped through its transform, so mirrored rooms come out right; the
# trigger is meant to be parented to the FLOOR, keeping its shapes out from under a mirrored scale.
func _make_doorway_trigger(room: Node3D, is_double: bool, trigger_script: Script) -> Area3D:
	var doorway: Vector3 = Vector3(4.8, 1.1, 8.5) if is_double else Vector3(-3.75, 1.1, 3.5)
	var inward_x: float = -1.0 if is_double else 1.0

	var trigger = Area3D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = 1 # Player layer
	trigger.set_script(trigger_script)
	trigger.position = room.transform * (doorway + Vector3(inward_x * 0.65, 0, 0))
	var inner_shape = BoxShape3D.new()
	inner_shape.size = Vector3(0.6, 2.2, 1.2)
	var inner_coll = CollisionShape3D.new()
	inner_coll.shape = inner_shape
	trigger.add_child(inner_coll)

	var threshold = Area3D.new()
	threshold.name = "Threshold"
	threshold.collision_layer = 0
	threshold.collision_mask = 1
	threshold.position = Vector3(-inward_x * 0.65, 0, 0) # back at the doorway itself
	var threshold_shape = BoxShape3D.new()
	threshold_shape.size = Vector3(0.5, 2.2, 1.0)
	var threshold_coll = CollisionShape3D.new()
	threshold_coll.shape = threshold_shape
	threshold.add_child(threshold_coll)
	trigger.add_child(threshold)
	return trigger

# Floor 8's nightmare - see name_door_trap.gd for the rule. Every room door gets a surname
# instead of its number and a trigger behind it; one random room is the hero's own, and
# _spawn_cassettes_other_floor() puts two of the floor's tapes in it (the third is always in
# the maintenance room, which has neither a plate nor a trigger).
const FLOOR8_OTHER_NAMES: Array = ["КРЫЛОВА", "СОКОЛОВ", "ЛЕБЕДЕВ", "ВОЛКОВ", "ЗАЙЦЕВА", "МОРОЗОВ", "ПАВЛОВ",
	"ОРЛОВА", "ГУСЕВ", "ТИТОВ", "БЕЛОВА", "КОМАРОВ", "ЖУКОВ", "НЕЧАЕВА"]
const FLOOR8_OWN_NAME: String = "НЕЧАЕВ"

func _add_name_doors(parent: Node3D, f_num: int, f_scale: float) -> void:
	var trap_script = load("res://scripts/levels/blocks/name_door_trap.gd")
	var nums: Array = DOUBLE_ROOM_LAYOUT.keys() + SINGLE_ROOM_LAYOUT.keys()
	nums.sort()
	var own_num: int = nums[randi() % nums.size()]
	var other_names: Array = FLOOR8_OTHER_NAMES.duplicate()
	other_names.shuffle()
	for num in nums:
		var is_double: bool = DOUBLE_ROOM_LAYOUT.has(num)
		var room: Node3D = parent.get_node_or_null(("DoubleRoom_" if is_double else "SingleRoom_") + str(f_num * 100 + num % 100))
		if not room:
			continue
		var is_own: bool = num == own_num
		var label: Label3D = room.get_node_or_null("RoomDoor/AnimatableBody3D/RoomNumberLabel")
		if label:
			label.text = FLOOR8_OWN_NAME if is_own else other_names.pop_back()
			label.font_size = 36 # a surname is longer than a three-digit number
		var trap: Area3D = _make_doorway_trigger(room, is_double, trap_script)
		trap.name = "NameDoorTrap_" + str(num)
		trap.is_own_room = is_own
		trap.return_position = parent.global_position + Vector3(ELEVATOR_CENTER_X * f_scale, 0.1, (ELEVATOR_CENTER_Z + 2.0) * f_scale)
		parent.add_child(trap)
		if is_own:
			parent.set_meta("own_room", room)

# Floor 5's nightmare - see room_shuffle_trap.gd for the rule. Gives every room on the floor a
# trap just inside its doorway, and seals one random room's door from the corridor side so that
# room can only be reached through the trap; _spawn_cassettes_other_floor() puts a tape in it.
# Coordinates are each room's own local ones (double_room.tscn / single_room.tscn), mapped
# through the room's transform so mirrored rooms come out right; the triggers themselves hang
# off the floor node, not the room, to keep physics shapes out from under a mirrored scale.
var _sealed_room_door: Node = null

func _add_room_shuffle_trap(parent: Node3D, f_num: int) -> void:
	var trap_script = load("res://scripts/levels/blocks/room_shuffle_trap.gd")
	var traps: Array = []
	var nums: Array = DOUBLE_ROOM_LAYOUT.keys() + SINGLE_ROOM_LAYOUT.keys()
	nums.sort()
	for num in nums:
		var is_double: bool = DOUBLE_ROOM_LAYOUT.has(num)
		var room: Node3D = parent.get_node_or_null(("DoubleRoom_" if is_double else "SingleRoom_") + str(f_num * 100 + num % 100))
		if not room:
			continue
		var trap: Area3D = _make_doorway_trigger(room, is_double, trap_script)
		trap.name = "RoomShuffleTrap_" + str(num)
		trap.room = room
		trap.traps = traps
		trap.index = traps.size()
		trap.inside_local = Vector3(2.5, 0.1, 7.5) if is_double else Vector3(-1.5, 0.1, 3.6)
		trap.facing_yaw = PI / 2.0 if is_double else -PI / 2.0

		traps.append(trap)
		parent.add_child(trap)

	if traps.is_empty():
		return
	var sealed_room: Node3D = traps[randi() % traps.size()].room
	parent.set_meta("sealed_room", sealed_room)
	_sealed_room_door = sealed_room.get_node_or_null("RoomDoor/AnimatableBody3D")
	if _sealed_room_door:
		_sealed_room_door.locked_from_corridor = not GameStateManager.floor5_rooms_unlocked # false in a continued game past floor 5

func _create_static_box(parent: Node, node_name: String, pos: Vector3, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> void:
	var static_body = StaticBody3D.new()
	static_body.name = node_name
	static_body.position = pos
	static_body.rotation = rot
	static_body.collision_layer = 2 # Matches old floor layer
	
	# Named explicitly: an unnamed node gets an auto-generated "@MeshInstance3D@123" name, and
	# _create_exit_portal() looks this one up by path.
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = mat
	mesh_inst.mesh = box_mesh
	static_body.add_child(mesh_inst)
	
	var coll = CollisionShape3D.new()
	coll.name = "CollisionShape3D"
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	coll.shape = box_shape
	static_body.add_child(coll)
	
	parent.add_child(static_body)

func _find_props(node: Node, prop_name: String, arr: Array) -> void:
	if node.name.begins_with(prop_name):
		arr.append(node)
	for child in node.get_children():
		_find_props(child, prop_name, arr)

# Per LORE.md, Cassette #1 ("Личность") is found in the starting room's furniture and
# Cassette #2 ("Инцидент") is nearby in the corridor - both close to where the player actually
# appears. The player spawns at the same world (X=0, Z=0) on every floor (see _move_player()),
# so "closest to spawn" is a stand-in for "in/near the starting room" that works on any floor,
# not just the one the player happens to be reading this on.
func _closest_to_spawn(props: Array) -> Node:
	var closest: Node = null
	var closest_dist_sq = INF
	for p in props:
		var pos = p.global_position
		var dist_sq = pos.x * pos.x + pos.z * pos.z
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest = p
	return closest

# Used for cassette placement on every floor except 4 (see _spawn_cassettes_other_floor()) -
# those floors have no "closest to spawn" relationship to preserve, so a genuinely random pick
# keeps their layout from being predictable across floors.
func _random_from(props: Array) -> Node:
	if props.is_empty():
		return null
	return props[randi() % props.size()]

func _spawn_cassettes(parent: Node, f_scale: float, f_num: int) -> void:
	var scene = load("res://entities/interactables/vhs_tape.tscn")
	if not scene: return

	# Floor 4 is the player's starting floor - Cassette #1 ("Личность") always sits in the same
	# room the player spawns in (see _move_player()), which relies on "closest wardrobe/table to
	# world origin" specifically. Every other floor has no such spawn-point relationship, so it
	# gets a simpler, fully-random layout instead (table/maintenance-room/wardrobe - see
	# _spawn_cassettes_other_floor()).
	if f_num == 4:
		_spawn_cassettes_start_floor(parent, f_scale, scene)
	else:
		_spawn_cassettes_other_floor(parent, f_scale, scene)

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
	var wardrobes = []
	_find_props(parent, "Wardrobe", wardrobes)
	var chosen_wardrobe = _closest_to_spawn(wardrobes)

	# Excludes tables in the wardrobe's own room before picking the closest one - every room has
	# both a wardrobe and a table, so without this the globally-closest table is almost always in
	# the SAME room as the globally-closest wardrobe (that room being closest to spawn is exactly
	# why it got picked as the starting room in the first place), landing both Cassette #1 and #2
	# on top of each other in the player's own starting room instead of two separate ones.
	var tables = []
	_find_props(parent, "Table", tables)
	if chosen_wardrobe != null:
		var wardrobe_room = chosen_wardrobe.get_parent()
		tables = tables.filter(func(t): return t.get_parent() != wardrobe_room)
	var chosen_table = _closest_to_spawn(tables)

	if parent.name == "GeneratedFloor_Main":
		print("[generator] _spawn_cassettes on ", parent.name, ": wardrobes found=", wardrobes.size(),
			" chosen=", (chosen_wardrobe.get_path() if chosen_wardrobe else "NONE"),
			" | tables found=", tables.size(),
			" chosen=", (chosen_table.get_path() if chosen_table else "NONE"))

	for i in range(3):
		var inst = scene.instantiate()
		inst.name = "Cassette_" + str(i)
		# Without this, every cassette keeps vhs_tape.gd's @export default (tape_id=0) - all 3
		# would collect as the same id, so GameStateManager.tapes_found (a Set keyed by id) never
		# grows past size 1, all_tapes_collected never fires,
		# and every cassette narrates tape #1's text regardless of which one was picked up.
		inst.tape_id = i

		# inst has no parent yet, so its OWN global_transform/global_position are unreliable
		# (Godot only tracks a node's global transform correctly once it's actually inside the
		# tree - writing/reading them on an orphan silently behaves as if its position were
		# zero, which is exactly what put cassettes near world origin/the corridor instead of
		# on the chosen furniture). chosen_wardrobe/chosen_table themselves ARE already in the
		# tree, so reading THEIR global_transform is fine - the fix is to convert that world-
		# space target into parent-relative LOCAL coordinates and assign inst.transform
		# (not inst.global_transform) before add_child(), the same pattern used everywhere
		# else in this generator.
		if i == 0 and chosen_wardrobe != null:
			inst.location_hint = "tape_hint_start_wardrobe"
			var target = chosen_wardrobe.global_transform
			# X=-0.28 matches the shelf zone's center in wardrobe.tscn (the other half of the
			# interior is now an open hanging compartment with a rod, not a shelf).
			target.origin += chosen_wardrobe.global_basis * Vector3(-0.28, 1.15, 0.05)
			inst.transform = parent.global_transform.affine_inverse() * target
		elif i == 1 and chosen_table != null:
			inst.location_hint = "tape_hint_table"
			var target = chosen_table.global_transform
			target.origin += chosen_table.global_basis * Vector3(0.0, 0.8, 0.0)
			inst.transform = parent.global_transform.affine_inverse() * target
		elif i == 2:
			inst.location_hint = "tape_hint_lift"
			inst.position = Vector3(7.2 * f_scale, 0.05 * f_scale, -23.5 * f_scale)
			inst.rotation.y = randf_range(0, PI * 2)
		else:
			var rand_x = randf_range(-2.0, 4.0)
			var rand_z = randf_range(-20.0, 40.0)
			inst.position = Vector3(rand_x * f_scale, 0.5 * f_scale, rand_z * f_scale)
			inst.rotation.y = randf_range(0, PI * 2)

		parent.add_child(inst)
		if parent.name == "GeneratedFloor_Main":
			print("[generator] Cassette_", i, " global_position=", inst.global_position)

# Every floor except 4 (see _spawn_cassettes()): one cassette on a table in a random room, one in
# the maintenance room, one in a wardrobe in a random room - none of floor 4's "closest to spawn"
# logic applies since the player doesn't start on these floors.
func _spawn_cassettes_other_floor(parent: Node, f_scale: float, scene: PackedScene) -> void:
	# Floor 5 has one room sealed off from the corridor (_add_room_shuffle_trap()) - the wardrobe
	# tape goes there, and the table tape anywhere else.
	var sealed_room = parent.get_meta("sealed_room") if parent.has_meta("sealed_room") else null

	var tables = []
	_find_props(parent, "Table", tables)
	if sealed_room != null:
		tables = tables.filter(func(t): return t.get_parent() != sealed_room)
	var chosen_table = _random_from(tables)

	# Excludes the table's own room before picking the wardrobe - same reasoning as
	# _spawn_cassettes_start_floor()'s wardrobe/table split: every room has both, so without this
	# the two could easily land in the same room by pure chance.
	var wardrobes = []
	_find_props(parent, "Wardrobe", wardrobes)
	if chosen_table != null:
		var table_room = chosen_table.get_parent()
		wardrobes = wardrobes.filter(func(w): return w.get_parent() != table_room)
	var chosen_wardrobe = _random_from(wardrobes)
	if sealed_room != null:
		chosen_wardrobe = sealed_room.get_node_or_null("Wardrobe")

	# Floor 8 lets the hero into one room only, his own (_add_name_doors()) - both room tapes
	# go there, on its table and in its wardrobe.
	var own_room = parent.get_meta("own_room") if parent.has_meta("own_room") else null
	if own_room != null:
		var own_tables = []
		_find_props(own_room, "Table", own_tables)
		chosen_table = own_tables[0] if not own_tables.is_empty() else chosen_table
		chosen_wardrobe = own_room.get_node_or_null("Wardrobe")

	# _find_props() only matches nodes named "Wardrobe" - the maintenance room's own two
	# ("MaintWardrobe1"/"MaintWardrobe2", see _generate_maintenance_room()) don't match that
	# prefix, so they're never candidates for chosen_wardrobe above; used here instead as the
	# actual "in the maintenance room" spot.
	var maint_wardrobe = parent.get_node_or_null("MaintWardrobe1")

	for i in range(3):
		var inst = scene.instantiate()
		inst.name = "Cassette_" + str(i)
		inst.tape_id = i

		# See _spawn_cassettes_start_floor() for why position must be set via a parent-relative
		# LOCAL transform (converted from the target's global_transform) before add_child().
		if i == 0 and chosen_table != null:
			inst.location_hint = "tape_hint_own_room" if own_room != null else "tape_hint_table"
			var target = chosen_table.global_transform
			target.origin += chosen_table.global_basis * Vector3(0.0, 0.8, 0.0)
			inst.transform = parent.global_transform.affine_inverse() * target
		elif i == 1 and maint_wardrobe != null:
			inst.location_hint = "tape_hint_maintenance"
			var target = maint_wardrobe.global_transform
			target.origin += maint_wardrobe.global_basis * Vector3(-0.28, 1.15, 0.05)
			inst.transform = parent.global_transform.affine_inverse() * target
		elif i == 2 and chosen_wardrobe != null:
			inst.location_hint = "tape_hint_sealed" if sealed_room != null else ("tape_hint_own_room" if own_room != null else "tape_hint_wardrobe")
			var target = chosen_wardrobe.global_transform
			target.origin += chosen_wardrobe.global_basis * Vector3(-0.28, 1.15, 0.05)
			inst.transform = parent.global_transform.affine_inverse() * target
		else:
			# Fallback if a floor is somehow missing one of the three spots (shouldn't happen -
			# every floor generates the same room/maintenance layout).
			var rand_x = randf_range(-2.0, 4.0)
			var rand_z = randf_range(-20.0, 40.0)
			inst.position = Vector3(rand_x * f_scale, 0.5 * f_scale, rand_z * f_scale)
			inst.rotation.y = randf_range(0, PI * 2)

		parent.add_child(inst)

func _spawn_cerberus(parent: Node, f_scale: float) -> void:
	var scene = load("res://entities/enemies/cerberus/cerberus.tscn")
	if not scene: return
	var inst = scene.instantiate()
	inst.name = "Cerberus"
	# position MUST be set before add_child() - see _generate_maintenance_room() for why.
	inst.position = Vector3(1.0 * f_scale, 0, 10.0 * f_scale)

	# cerberus_ai.gd starts in State.IDLE and only ever leaves it for State.PATROL if
	# patrol_points is non-empty - left empty (the default), a spawned robot just stands at this
	# exact spot forever, only reacting if the player happens to wander into its 12m
	# DetectionArea. Two Marker3D points give it a back-and-forth patrol instead of standing
	# frozen - spanning the full central corridor (Z ~[-25.18, 25.0], see z_main_len/z_main_pos
	# in _build_floor_geometry, inset 1.2m from each end wall) rather than just a few meters
	# around the spawn point, so it actually walks the length of the hallway it's guarding.
	# Positions are LOCAL to inst (which isn't in the tree yet), so they're offsets from its own
	# origin (spawned at local Z=10.0), not world/parent coordinates.
	var patrol_a = Marker3D.new()
	patrol_a.position = Vector3(0, 0, (-24.0 - 10.0) * f_scale)
	inst.add_child(patrol_a)
	var patrol_b = Marker3D.new()
	patrol_b.position = Vector3(0, 0, (24.0 - 10.0) * f_scale)
	inst.add_child(patrol_b)
	# Typed on purpose: patrol_points is Array[Marker3D], and assigning a plain untyped Array to
	# it is a script error that aborts this function before add_child() below - which is why no
	# generated floor actually had its robot.
	var patrol_points: Array[Marker3D] = [patrol_a, patrol_b]
	inst.patrol_points = patrol_points

	parent.add_child(inst)

# Floor 6's nightmare - see sleeper_cerberus.gd for the rule. Four of them stand along the main
# corridor, alternating sides so none blocks the way. Corridor only, on purpose: a sleeper shut
# inside a room could never be lured away from it (closed doors are solid to the navmesh), so
# taking a tape there would be a guaranteed catch instead of a decision.
const SLEEPER_POSTS: Array = [Vector2(-0.6, -16.0), Vector2(2.8, -5.0), Vector2(-0.6, 7.0), Vector2(2.8, 19.0)] # X, Z

func _spawn_sleepers(parent: Node3D, f_scale: float, off_flag: StringName) -> void:
	var scene = load("res://entities/enemies/cerberus/cerberus.tscn")
	var sleeper_script = load("res://scripts/enemies/sleeper_cerberus.gd")
	if not scene or not sleeper_script: return
	for i in range(SLEEPER_POSTS.size()):
		var post: Vector2 = SLEEPER_POSTS[i]
		var inst = scene.instantiate()
		inst.set_script(sleeper_script)
		inst.name = "Sleeper_" + str(i + 1)
		inst.off_flag = off_flag
		# position MUST be set before add_child() - see _generate_maintenance_room() for why.
		inst.position = Vector3(post.x * f_scale, 0, post.y * f_scale)
		inst.rotation.y = PI / 2.0 if post.x < 1.0 else -PI / 2.0 # backs to the wall, facing across
		# Where one of them puts a caught player: the open corridor in front of this floor's
		# elevator door (elevator at ELEVATOR_CENTER_X, its door on the Z=-25 face).
		inst.return_position = parent.global_position + Vector3(ELEVATOR_CENTER_X * f_scale, 0.1, (ELEVATOR_CENTER_Z + 2.0) * f_scale)
		parent.add_child(inst)

# Floor 7's nightmare - see blackout_trap.gd for the rule. It gets this floor's own lights (the
# same list _set_lit_floor() switches) and the glowing ceiling panels that go with them, and the
# same "back by the elevator" spot floor 6's sleepers use.
func _add_blackout_trap(parent: Node3D, f_num: int, lights: Array, f_scale: float) -> void:
	var trap = Node3D.new()
	trap.name = "BlackoutTrap"
	trap.set_script(load("res://scripts/levels/blocks/blackout_trap.gd"))
	trap.floor_num = f_num
	trap.off_flag = &"floor7_lights_steady" if f_num == 7 else &"floor2_done"
	trap.lights = lights
	trap.lamp_meshes = parent.find_children("*LightMesh", "MeshInstance3D", true, false)
	trap.return_position = parent.global_position + Vector3(ELEVATOR_CENTER_X * f_scale, 0.1, (ELEVATOR_CENTER_Z + 2.0) * f_scale)
	parent.add_child(trap)

# Floor 9's sweeping ceiling units (sweep_camera_trap.gd) and floor 10's advancing edge
# (edge_wall_trap.gd): one node each, sitting at the floor's own origin so the script can work
# in floor-local coordinates. Both put a caught player back by that floor's elevator.
func _add_floor_wide_trap(parent: Node3D, f_num: int, f_scale: float) -> void:
	var trap = Node3D.new()
	if f_num == 9:
		trap.name = "SweepCameraTrap"
		trap.set_script(load("res://scripts/levels/blocks/sweep_camera_trap.gd"))
		trap.corridor_x_min = CORRIDOR_WEST_EDGE_X * f_scale
		trap.corridor_x_max = CORRIDOR_EAST_EDGE_X * f_scale
	else:
		trap.name = "EdgeWallTrap"
		trap.set_script(load("res://scripts/levels/blocks/edge_wall_trap.gd"))
		trap.width = BUILDING_WIDTH_X * f_scale
		trap.height = corridor_height * f_scale
	trap.floor_num = f_num
	trap.return_position = parent.global_position + Vector3(ELEVATOR_CENTER_X * f_scale, 0.1, (ELEVATOR_CENTER_Z + 2.0) * f_scale)
	parent.add_child(trap)

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
const LOBBY_CORRIDOR_HALF_WIDTH: float = 2.5   # the corridor to the entrance, centred on Z=0
const LOBBY_NORTH_ZONE_Z: float = -20.0        # south edge of the wider zone in front of the lift
const LOBBY_NORTH_ZONE_EAST_X: float = 9.65    # its east wall - where the maintenance room starts upstairs

func _build_lobby(parent: Node3D, f_scale: float, height: float, wall_mat: Material) -> void:
	var hh: float = height / f_scale
	var west: float = CORRIDOR_WEST_EDGE_X
	var east: float = CORRIDOR_EAST_EDGE_X
	var half_x: float = BUILDING_WIDTH_X / 2.0
	var north_z: float = ELEVATOR_CENTER_Z            # -25: the lift's and the north stairs' own doors
	var south_z: float = SOUTH_STAIRS_ZONE_Z_START    # 25: the south stairs wall
	var cw: float = LOBBY_CORRIDOR_HALF_WIDTH
	var parts_script = load("res://scripts/levels/blocks/lobby_parts.gd")
	# A box given by its extents (unscaled meters) rather than by center and size.
	var box = func(box_name: String, mat: Material, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> void:
		_create_static_box(parent, box_name, Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0) * f_scale,
			Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0)) * f_scale, mat)

	# --- Walls ---
	box.call("Lobby_WestWall_N", wall_mat, west - 0.2, west, 0.0, hh, north_z, -cw)
	box.call("Lobby_WestWall_S", wall_mat, west - 0.2, west, 0.0, hh, cw, south_z)
	box.call("Lobby_Corridor_N", wall_mat, -half_x, west, 0.0, hh, -cw - 0.2, -cw)
	box.call("Lobby_Corridor_S", wall_mat, -half_x, west, 0.0, hh, cw, cw + 0.2)
	box.call("Lobby_EastWall", wall_mat, east, east + 0.2, 0.0, hh, LOBBY_NORTH_ZONE_Z, south_z)
	box.call("Lobby_NorthZone_S", wall_mat, east, LOBBY_NORTH_ZONE_EAST_X, 0.0, hh, LOBBY_NORTH_ZONE_Z, LOBBY_NORTH_ZONE_Z + 0.2)
	box.call("Lobby_NorthZone_E", wall_mat, LOBBY_NORTH_ZONE_EAST_X, LOBBY_NORTH_ZONE_EAST_X + 0.2, 0.0, hh, north_z, LOBBY_NORTH_ZONE_Z + 0.2)
	box.call("Lobby_NorthWall_W", wall_mat, west - 0.2, NORTH_STAIRS_CENTER_X - 3.8, 0.0, hh, north_z - 0.2, north_z)

	# --- Reception: a long desk in the middle of the hall, in front of the east wall, facing
	# the corridor to the entrance. There is room to walk round either end and behind it. ---
	var wood = StandardMaterial3D.new()
	wood.albedo_color = Color(0.28, 0.16, 0.08)
	wood.roughness = 0.6
	box.call("Reception_Desk", wood, 2.5, 3.3, 0.0, 1.1, -2.6, 2.6)
	box.call("Reception_Top", wood, 2.3, 3.4, 1.1, 1.18, -2.7, 2.7)
	var desk_light = OmniLight3D.new()
	desk_light.name = "ReceptionLight"
	desk_light.light_color = Color(1.0, 0.85, 0.6)
	desk_light.light_energy = 1.0
	desk_light.omni_range = 7.0 * f_scale
	desk_light.position = Vector3(2.9, 2.6, 0.0) * f_scale
	parent.add_child(desk_light)

	# --- The second lift, the one that goes underground: doors in the east wall behind the
	# desk, and a panel beside them (see lobby_parts.gd, role "lift"). ---
	var steel = StandardMaterial3D.new()
	steel.albedo_color = Color(0.4, 0.4, 0.45)
	steel.metallic = 0.8
	steel.roughness = 0.25
	box.call("LowerLift_DoorL", steel, east - 0.08, east, 0.0, 2.5, -0.66, 0.0)
	box.call("LowerLift_DoorR", steel, east - 0.1, east, 0.0, 2.5, 0.0, 0.66)
	box.call("LowerLift_Frame", steel, east - 0.14, east, 2.5, 2.7, -0.8, 0.8)
	# Its panel is created in _build_lab(), together with the panels on the levels below.

	# --- The aquarium: against the east wall, right next to the reception. Glowing, cloudy
	# water you cannot quite see through, and something in it (lobby_parts.gd, "creature"). ---
	var tank_x0: float = 3.55
	var tank_x1: float = east - 0.05
	var tank_z0: float = 3.4
	var tank_z1: float = 9.4
	var tank_h: float = 2.8
	var tank_body = StaticBody3D.new()
	tank_body.name = "Aquarium"
	tank_body.collision_layer = 2
	tank_body.position = Vector3((tank_x0 + tank_x1) / 2.0, tank_h / 2.0 + 0.3, (tank_z0 + tank_z1) / 2.0) * f_scale
	var tank_size: Vector3 = Vector3(tank_x1 - tank_x0, tank_h, tank_z1 - tank_z0) * f_scale
	var tank_coll = CollisionShape3D.new()
	var tank_shape = BoxShape3D.new()
	tank_shape.size = tank_size
	tank_coll.shape = tank_shape
	tank_body.add_child(tank_coll)
	var water = MeshInstance3D.new()
	water.name = "Water"
	var water_box = BoxMesh.new()
	water_box.size = tank_size
	var water_mat = StandardMaterial3D.new()
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.albedo_color = Color(0.1, 0.55, 0.45, 0.78)
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.1, 0.9, 0.7)
	water_mat.emission_energy_multiplier = 0.7
	water_mat.roughness = 0.1
	water_box.material = water_mat
	water.mesh = water_box
	tank_body.add_child(water)
	var creature = Node3D.new()
	creature.name = "Creature"
	creature.set_script(parts_script)
	creature.role = "creature"
	creature.swim_half_length = (tank_z1 - tank_z0) / 2.0 * f_scale - 1.2 * f_scale
	var creature_mat = StandardMaterial3D.new()
	creature_mat.albedo_color = Color(0.01, 0.02, 0.02)
	creature_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Body, and something long trailing behind it - only ever a darker shape in the murk.
	for part in [[Vector3(0.28, 0.5, 1.0), Vector3(0, 0, 0)], [Vector3(0.12, 0.2, 1.3), Vector3(0, -0.1, -1.0)], [Vector3(0.5, 0.08, 0.5), Vector3(0, 0.2, 0.3)]]:
		var shape_mesh = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.material = creature_mat
		shape_mesh.mesh = sphere
		shape_mesh.scale = part[0] * 2.0 * f_scale
		shape_mesh.position = part[1] * f_scale
		creature.add_child(shape_mesh)
	tank_body.add_child(creature)
	box.call("Aquarium_Base", steel, tank_x0 - 0.05, tank_x1, 0.0, 0.3, tank_z0 - 0.05, tank_z1 + 0.05)
	parent.add_child(tank_body)
	var tank_light = OmniLight3D.new()
	tank_light.name = "AquariumLight"
	tank_light.light_color = Color(0.2, 1.0, 0.8)
	tank_light.light_energy = 2.2
	tank_light.omni_range = 12.0 * f_scale
	tank_light.position = Vector3(tank_x0 - 0.8, 1.8, (tank_z0 + tank_z1) / 2.0) * f_scale
	parent.add_child(tank_light)

	# --- The main entrance at the west end of the corridor, and the turrets over it. ---
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.12, 0.1, 0.08)
	door_mat.metallic = 0.3
	box.call("Entrance_DoorL", door_mat, -half_x, -half_x + 0.12, 0.0, 2.6, -1.3, -0.02)
	box.call("Entrance_DoorR", door_mat, -half_x, -half_x + 0.12, 0.0, 2.6, 0.02, 1.3)
	var exit_sign = MeshInstance3D.new()
	exit_sign.name = "Entrance_Sign"
	var sign_box = BoxMesh.new()
	sign_box.size = Vector3(0.05, 0.3, 1.2) * f_scale
	var sign_mat = StandardMaterial3D.new()
	sign_mat.albedo_color = Color(0.1, 0.5, 0.15)
	sign_mat.emission_enabled = true
	sign_mat.emission = Color(0.2, 1.0, 0.3)
	sign_mat.emission_energy_multiplier = 2.5
	sign_box.material = sign_mat
	exit_sign.mesh = sign_box
	exit_sign.position = Vector3(-half_x + 0.16, 2.95, 0.0) * f_scale
	parent.add_child(exit_sign)
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.6, 0.05, 0.05)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.15, 0.05)
	eye_mat.emission_energy_multiplier = 3.0
	var turret_x: float = west - 2.0
	for side in [-1.0, 1.0]:
		box.call("Turret_%s" % ("N" if side < 0.0 else "S"), steel, turret_x - 0.25, turret_x + 0.25, hh - 0.45, hh, side * 1.5 - 0.25, side * 1.5 + 0.25)
		box.call("TurretEye_%s" % ("N" if side < 0.0 else "S"), eye_mat, turret_x - 0.32, turret_x - 0.25, hh - 0.32, hh - 0.2, side * 1.5 - 0.08, side * 1.5 + 0.08)
	var turret_light = OmniLight3D.new()
	turret_light.name = "TurretLight"
	turret_light.light_color = Color(1.0, 0.12, 0.08)
	turret_light.light_energy = 1.5
	turret_light.omni_range = 9.0 * f_scale
	turret_light.position = Vector3(turret_x - 2.0, hh - 0.6, 0.0) * f_scale
	parent.add_child(turret_light)

	# The kill zone: the corridor from just past its mouth all the way to the door.
	var zone_x0: float = -half_x + 0.2
	var zone_x1: float = west - 1.5
	var kill_zone = Area3D.new()
	kill_zone.name = "TurretKillZone"
	kill_zone.collision_layer = 0
	kill_zone.collision_mask = 1 # Player layer
	kill_zone.set_script(parts_script)
	kill_zone.role = "turrets"
	kill_zone.position = Vector3((zone_x0 + zone_x1) / 2.0, 1.2, 0.0) * f_scale
	# Where he comes to: in front of the lift he arrived by.
	kill_zone.return_position = parent.global_position + Vector3(ELEVATOR_CENTER_X * f_scale, 0.1, (ELEVATOR_CENTER_Z + 2.0) * f_scale)
	var zone_coll = CollisionShape3D.new()
	var zone_shape = BoxShape3D.new()
	zone_shape.size = Vector3(zone_x1 - zone_x0, 2.4, cw * 2.0 - 0.2) * f_scale
	zone_coll.shape = zone_shape
	kill_zone.add_child(zone_coll)
	parent.add_child(kill_zone)

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
	var body = StaticBody3D.new()
	body.name = tank_name
	body.collision_layer = 2
	body.position = center * f_scale
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size * f_scale
	coll.shape = shape
	body.add_child(coll)
	var water = MeshInstance3D.new()
	var water_box = BoxMesh.new()
	water_box.size = size * f_scale
	var water_mat = StandardMaterial3D.new()
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.albedo_color = Color(0.1, 0.55, 0.45, 0.78)
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.1, 0.9, 0.7)
	water_mat.emission_energy_multiplier = 0.7
	water_box.material = water_mat
	water.mesh = water_box
	body.add_child(water)
	var creature = Node3D.new()
	creature.name = "Creature"
	creature.set_script(parts_script)
	creature.role = "creature"
	creature.swim_half_length = maxf(0.1, size.z / 2.0 - 0.9) * f_scale
	var dark = StandardMaterial3D.new()
	dark.albedo_color = Color(0.01, 0.02, 0.02)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for part in [[Vector3(0.28, 0.5, 1.0), Vector3.ZERO], [Vector3(0.12, 0.2, 1.3), Vector3(0, -0.1, -1.0)]]:
		var blob = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.material = dark
		blob.mesh = sphere
		blob.scale = part[0] * 1.6 * f_scale
		blob.position = part[1] * 0.8 * f_scale
		creature.add_child(blob)
	body.add_child(creature)
	parent.add_child(body)

func _build_lab(parent: Node3D, f_scale: float) -> void:
	var half_x: float = BUILDING_WIDTH_X / 2.0
	var half_z: float = BUILDING_LENGTH_Z / 2.0
	var drop: float = LAB_LEVEL_DROP
	var y1: float = -drop          # level -1 floor
	var y2: float = -2.0 * drop    # level -2 floor
	var parts_script = load("res://scripts/levels/blocks/lobby_parts.gd")
	var concrete = StandardMaterial3D.new()
	concrete.albedo_color = Color(0.32, 0.33, 0.35)
	concrete.roughness = 0.95
	var steel = StandardMaterial3D.new()
	steel.albedo_color = Color(0.4, 0.4, 0.45)
	steel.metallic = 0.8
	steel.roughness = 0.3
	var wood = StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.3, 0.32)
	var lamp_mat = StandardMaterial3D.new()
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.95, 0.8)
	lamp_mat.emission_energy_multiplier = 2.0
	var box = func(box_name: String, mat: Material, x0: float, x1: float, y0: float, y1b: float, z0: float, z1: float) -> void:
		_create_static_box(parent, box_name, Vector3((x0 + x1) / 2.0, (y0 + y1b) / 2.0, (z0 + z1) / 2.0) * f_scale,
			Vector3(absf(x1 - x0), absf(y1b - y0), absf(z1 - z0)) * f_scale, mat)
	var light = func(light_name: String, pos: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
		var omni = OmniLight3D.new()
		omni.name = light_name
		omni.light_color = color
		omni.light_energy = energy
		omni.omni_range = reach * f_scale
		omni.position = pos * f_scale
		parent.add_child(omni)
		return omni
	# A panel of the second lift, one per stop: where it stands and which stop it is. Every
	# panel knows all three stops - it opens the same floor-select screen as the main lift.
	var lift_stops: Dictionary = {}
	for stop in [[1, 0.0], [-1, y1], [-2, y2]]:
		lift_stops[stop[0]] = parent.global_position + Vector3(LAB_ARRIVE_X, stop[1] + 0.1, 0.0) * f_scale
	var lift_panel = func(panel_name: String, at: Vector3, here: int, needs_code: bool) -> void:
		var panel = Area3D.new()
		panel.name = panel_name
		panel.collision_layer = 4 # the interact raycast's layer
		panel.collision_mask = 0
		panel.set_script(parts_script)
		panel.role = "lift"
		panel.needs_code = needs_code
		panel.here = here
		panel.stops = lift_stops
		panel.position = at * f_scale
		var coll = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(0.2, 0.5, 0.35) * f_scale
		coll.shape = shape
		panel.add_child(coll)
		var mesh = MeshInstance3D.new()
		var mesh_box = BoxMesh.new()
		mesh_box.size = Vector3(0.05, 0.4, 0.25) * f_scale
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.1, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.6, 0.1)
		mat.emission_energy_multiplier = 1.5
		mesh_box.material = mat
		mesh.mesh = mesh_box
		panel.add_child(mesh)
		parent.add_child(panel)

	# --- Shell: two floor slabs and four walls two levels tall. Level -1's ceiling is the
	# lobby's own floor slab. ---
	box.call("Lab_Floor1", concrete, -half_x, half_x, y1 - 0.5, y1, -half_z, half_z)
	box.call("Lab_Floor2", concrete, -half_x, half_x, y2 - 0.5, y2, -half_z, half_z)
	box.call("Lab_Wall_W", concrete, -half_x - 0.2, -half_x, y2 - 0.5, -0.5, -half_z, half_z)
	box.call("Lab_Wall_E", concrete, half_x, half_x + 0.2, y2 - 0.5, -0.5, -half_z, half_z)
	box.call("Lab_Wall_N", concrete, -half_x, half_x, y2 - 0.5, -0.5, -half_z - 0.2, -half_z)
	box.call("Lab_Wall_S", concrete, -half_x, half_x, y2 - 0.5, -0.5, half_z, half_z + 0.2)

	# --- The second lift: the lobby's panel (down, needs the code) and, on each level below, a
	# shaft front with doors and its own panels. ---
	lift_panel.call("LowerLiftPanel", Vector3(LAB_LIFT_X - 0.1, 1.3, 1.05), 1, true)
	for level in [[y1, "1"], [y2, "2"]]:
		var ly: float = level[0]
		box.call("Lab%s_LiftShaft" % level[1], steel, LAB_LIFT_X, LAB_LIFT_X + 1.6, ly, ly + 3.2, -2.2, 2.2)
		box.call("Lab%s_LiftDoor" % level[1], concrete, LAB_LIFT_X - 0.06, LAB_LIFT_X, ly, ly + 2.5, -0.66, 0.66)
		lift_panel.call("Lab%s_LiftPanel" % level[1], Vector3(LAB_LIFT_X - 0.1, ly + 1.3, 1.05), -int(level[1]), false)

	# --- Level -1: the open-plan office. ---
	for col in range(3):
		for row in range(9):
			var dx: float = -9.0 + col * 4.0
			var dz: float = -24.0 + row * 6.0
			box.call("Lab1_Desk_%d_%d" % [col, row], wood, dx - 0.8, dx + 0.8, y1, y1 + 0.75, dz - 0.4, dz + 0.4)
			var lamp = MeshInstance3D.new()
			var lamp_box = BoxMesh.new()
			lamp_box.size = Vector3(0.18, 0.06, 0.3) * f_scale
			lamp_box.material = lamp_mat
			lamp.mesh = lamp_box
			lamp.position = Vector3(dx + 0.5, y1 + 1.05, dz) * f_scale
			parent.add_child(lamp)
	for i in range(5):
		light.call("Lab1_Light_%d" % i, Vector3(-5.0, y1 + 3.2, -22.0 + i * 11.0), Color(0.85, 0.92, 1.0), 1.6, 12.0)
	# The crates the nine Cerberus units came in (the waybill in the terminal archive), empty.
	for i in range(9):
		box.call("Lab1_Crate_%d" % i, wood, -half_x + 0.3, -half_x + 1.5, y1, y1 + 1.9, -21.0 + i * 2.3, -19.2 + i * 2.3)
	# The lab's own terminal, by the lift: its documents open once the player has come down.
	_add_floor_terminal(parent, f_scale, Vector3(LAB_LIFT_X - 0.15, y1 + 1.3, -1.9), PI)

	# --- Level -2: the plant. ---
	for i in range(4):
		for side in [-1.0, 1.0]:
			_add_lab_tank(parent, "Lab2_Tank_%d_%s" % [i, "N" if side < 0.0 else "S"],
				Vector3(-10.0 + i * 4.0, y2 + 1.75, side * 14.0), Vector3(2.4, 3.0, 3.6), f_scale, parts_script)
			box.call("Lab2_Rack_%d_%s" % [i, "N" if side < 0.0 else "S"], steel, -10.5 + i * 4.0, -8.5 + i * 4.0, y2, y2 + 2.2, side * 28.6 - 0.4, side * 28.6 + 0.4)
	light.call("Lab2_TankLight_N", Vector3(-4.0, y2 + 2.2, -10.5), Color(0.2, 1.0, 0.8), 2.0, 14.0)
	light.call("Lab2_TankLight_S", Vector3(-4.0, y2 + 2.2, 10.5), Color(0.2, 1.0, 0.8), 2.0, 14.0)
	# The installation: a column of light in a housing, in the middle of the hall.
	var installation = Node3D.new()
	installation.name = "Lab2_Installation"
	installation.set_script(parts_script)
	installation.role = "installation"
	installation.position = Vector3(-4.0, y2, 0.0) * f_scale
	var housing = MeshInstance3D.new()
	housing.name = "Housing"
	var torus = TorusMesh.new()
	torus.inner_radius = 1.3 * f_scale
	torus.outer_radius = 1.7 * f_scale
	torus.material = steel
	housing.mesh = torus
	housing.position = Vector3(0, 1.2, 0) * f_scale
	installation.add_child(housing)
	var column = MeshInstance3D.new()
	column.name = "Column"
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.5 * f_scale
	cylinder.bottom_radius = 0.5 * f_scale
	cylinder.height = 4.0 * f_scale
	var column_mat = StandardMaterial3D.new()
	column_mat.emission_enabled = true
	column_mat.emission = Color(0.75, 0.85, 1.0)
	column_mat.emission_energy_multiplier = 6.0
	cylinder.material = column_mat
	column.mesh = cylinder
	column.position = Vector3(0, 2.0, 0) * f_scale
	installation.add_child(column)
	var core_light = OmniLight3D.new()
	core_light.light_color = Color(0.75, 0.85, 1.0)
	core_light.light_energy = 4.0
	core_light.omni_range = 16.0 * f_scale
	core_light.position = Vector3(0, 2.0, 0) * f_scale
	installation.add_child(core_light)
	parent.add_child(installation)
	_create_static_box(parent, "Lab2_InstallationBody", Vector3(-4.0, y2 + 2.0, 0.0) * f_scale, Vector3(1.0, 4.0, 1.0) * f_scale, steel)
	# The three consoles around it, numbered - they only work in order (lobby_parts.gd).
	var console_spots: Array = [Vector3(-4.0, y2, -4.0), Vector3(-8.0, y2, 0.0), Vector3(-4.0, y2, 4.0)]
	for i in range(3):
		var spot: Vector3 = console_spots[i]
		box.call("Lab2_ConsoleBody_%d" % (i + 1), steel, spot.x - 0.5, spot.x + 0.5, y2, y2 + 1.0, spot.z - 0.3, spot.z + 0.3)
		var console = Area3D.new()
		console.name = "Lab2_Console_%d" % (i + 1)
		console.collision_layer = 4
		console.collision_mask = 0
		console.set_script(parts_script)
		console.role = "console"
		console.index = i + 1
		console.position = (spot + Vector3(0, 1.15, 0)) * f_scale
		var console_coll = CollisionShape3D.new()
		var console_shape = BoxShape3D.new()
		console_shape.size = Vector3(1.1, 0.5, 0.9) * f_scale
		console_coll.shape = console_shape
		console.add_child(console_coll)
		var number = Label3D.new()
		number.text = str(i + 1)
		number.font_size = 96
		number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		number.modulate = Color(1.0, 0.7, 0.2)
		number.position = Vector3(0, 0.35, 0) * f_scale
		console.add_child(number)
		parent.add_child(console)

func _generate_roof(y_offset: float, f_scale: float) -> void:
	var parent = Node3D.new()
	parent.name = "GeneratedRoof"
	parent.position.y = y_offset
	add_child(parent)
	
	var z_length = BUILDING_LENGTH_Z * f_scale
	var x_width = BUILDING_WIDTH_X * f_scale
	var thickness = wall_thickness * f_scale
	var floor_thick = floor_thickness * f_scale

	var half_x = x_width / 2.0

	var roof_mat = StandardMaterial3D.new()
	var roof_tex = _load_texture_safe("res://assets/textures/roof_concrete.jpg")
	if roof_tex:
		roof_mat.albedo_texture = roof_tex
		roof_mat.uv1_scale = Vector3(10, 10, 10)
	else:
		roof_mat.albedo_color = Color(0.8, 0.8, 0.8)
	
	# Roof slabs (same logic as floor slabs)
	var floor_y = -floor_thick / 2.0
	var z_south_len = 55.18 * f_scale
	var z_south_pos = 2.41 * f_scale
	var z_north_len = 4.82 * f_scale
	var z_north_pos = -27.59 * f_scale
	
	var x_nw_east = NORTH_ZONE_INNER_X * f_scale
	var x_nw_len = x_nw_east + half_x
	var x_nw_pos = (x_nw_east - half_x) / 2.0
	var x_ne_len = 8.0 * f_scale
	var x_ne_pos = 8.65 * f_scale

	# The main slab stops at the south stairs zone: the part of that zone over the upper ramp
	# (X SOUTH_STAIRS_RAMP_INNER_X..LANDING_INNER_X, the southern half of the zone) is left open,
	# so the top flight of floor 10's south stairs comes out onto the roof instead of running
	# into the underside of the slab.
	var half_z_roof = z_length / 2.0
	var z_stairs_mid = (SOUTH_STAIRS_ZONE_Z_START + SOUTH_STAIRS_ZONE_Z_END) / 2.0 * f_scale
	var z_main_north = z_south_pos - z_south_len / 2.0
	var x_ramp_west = SOUTH_STAIRS_RAMP_INNER_X * f_scale
	var x_ramp_east = SOUTH_STAIRS_LANDING_INNER_X * f_scale
	_create_static_box(parent, "Roof_Main", Vector3(0, floor_y, (z_main_north + z_stairs_mid) / 2.0), Vector3(x_width, floor_thick, z_stairs_mid - z_main_north), roof_mat)
	_create_static_box(parent, "Roof_SW", Vector3((x_ramp_west - half_x) / 2.0, floor_y, (z_stairs_mid + half_z_roof) / 2.0), Vector3(x_ramp_west + half_x, floor_thick, half_z_roof - z_stairs_mid), roof_mat)
	_create_static_box(parent, "Roof_SE", Vector3((x_ramp_east + half_x) / 2.0, floor_y, (z_stairs_mid + half_z_roof) / 2.0), Vector3(half_x - x_ramp_east, floor_thick, half_z_roof - z_stairs_mid), roof_mat)
	_create_static_box(parent, "Roof_NW", Vector3(x_nw_pos, floor_y, z_north_pos), Vector3(x_nw_len, floor_thick, z_north_len), roof_mat)
	_create_static_box(parent, "Roof_NE", Vector3(x_ne_pos, floor_y, z_north_pos), Vector3(x_ne_len, floor_thick, z_north_len), roof_mat)

	# Parapets (Outer walls)
	var parapet_height = 1.0 * f_scale + floor_thick
	var parapet_y = (1.0 * f_scale - floor_thick) / 2.0
	var half_z = z_length / 2.0

	_create_static_box(parent, "Parapet_West", Vector3(-half_x - thickness/2.0, parapet_y, 0), Vector3(thickness, parapet_height, z_length), roof_mat)
	_create_static_box(parent, "Parapet_East", Vector3(half_x + thickness/2.0, parapet_y, 0), Vector3(thickness, parapet_height, z_length), roof_mat)
	_create_static_box(parent, "Parapet_North", Vector3(0, parapet_y, -half_z - thickness/2.0), Vector3(x_width + thickness * 2.0, parapet_height, thickness), roof_mat)
	_create_static_box(parent, "Parapet_South", Vector3(0, parapet_y, half_z + thickness/2.0), Vector3(x_width + thickness * 2.0, parapet_height, thickness), roof_mat)

	_build_roof_structures(parent, f_scale, roof_mat)

# What stands on the roof: a bulkhead over each stairwell (so the stairs come out through a
# door instead of an open hole in the slab) and the elevator machine room over the lift shaft,
# with the code plate inside. Coordinates are the roof node's own - Y=0 is the roof surface.
const ROOF_ROOM_HEIGHT: float = 2.6
const ROOF_FLOOR_INDEX: int = 11 # what stairs_gate.gd / GameStateManager call the roof

func _build_roof_structures(parent: Node3D, f_scale: float, mat: Material) -> void:
	var hh: float = ROOF_ROOM_HEIGHT
	var door_w: float = 1.2 * f_scale
	var door_h: float = 2.2 * f_scale
	var door_scene = load("res://entities/props/door.tscn")
	var gate_script = load("res://scripts/levels/blocks/stairs_gate.gd")
	# A box given by its extents (unscaled meters) rather than by center and size.
	var box = func(box_name: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> void:
		_create_static_box(parent, box_name, Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0) * f_scale,
			Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0)) * f_scale, mat)
	var add_door = func(door_name: String, pos: Vector3, rot_y: float) -> void:
		if not door_scene:
			return
		var door_inst = door_scene.instantiate()
		door_inst.name = door_name
		door_inst.position = pos * f_scale
		door_inst.rotation.y = rot_y
		door_inst.scale = Vector3(door_w, f_scale, f_scale)
		parent.add_child(door_inst)
	# The same floor-lock gate every stairwell door has. The roof counts as "floor 11", which
	# floor 10's tapes unlock (see _on_all_tapes_collected()); until then stepping through
	# puts the player back on floor 10, exactly like any other locked floor.
	var add_gate = func(gate_name: String, pos: Vector3, rot_y: float) -> void:
		var gate = Area3D.new()
		gate.name = gate_name
		gate.collision_layer = 0
		gate.collision_mask = 1 # Player layer
		gate.set_script(gate_script)
		gate.floor_num = ROOF_FLOOR_INDEX
		gate.y_step = BASE_FLOOR_TO_FLOOR_HEIGHT * f_scale
		gate.position = (pos + Vector3(0, 1.1, 0)) * f_scale
		gate.rotation.y = rot_y
		var gate_coll = CollisionShape3D.new()
		var gate_shape = BoxShape3D.new()
		gate_shape.size = Vector3(door_w, door_h, 1.0 * f_scale)
		gate_coll.shape = gate_shape
		gate.add_child(gate_coll)
		parent.add_child(gate)

	# --- North stairs bulkhead, over the stairwell hole (X -2.65..4.75, Z -30..-25.1). Its door
	# is where every floor's own "west" stair door is (X = NORTH_STAIRS_CENTER_X - 2.8): that is
	# where floor 10's top flight arrives. ---
	var nx0: float = NORTH_STAIRS_CENTER_X - 3.8
	var nx1: float = NORTH_STAIRS_CENTER_X + 3.8
	var nz0: float = -BUILDING_LENGTH_Z / 2.0
	var nz1: float = -25.1
	var ndoor: float = NORTH_STAIRS_CENTER_X - 2.8
	box.call("NorthExit_West", nx0, nx0 + 0.2, 0.0, hh, nz0, nz1)
	box.call("NorthExit_East", nx1 - 0.2, nx1, 0.0, hh, nz0, nz1)
	box.call("NorthExit_North", nx0, nx1, 0.0, hh, nz0, nz0 + 0.2)
	box.call("NorthExit_SouthA", nx0, ndoor - 0.6, 0.0, hh, nz1 - 0.1, nz1 + 0.1)
	box.call("NorthExit_SouthB", ndoor + 0.6, nx1, 0.0, hh, nz1 - 0.1, nz1 + 0.1)
	box.call("NorthExit_Lintel", ndoor - 0.6, ndoor + 0.6, 2.2, hh, nz1 - 0.1, nz1 + 0.1)
	box.call("NorthExit_Cap", nx0, nx1, hh, hh + 0.2, nz0, nz1 + 0.1)
	add_door.call("NorthExitDoor", Vector3(ndoor, 0, nz1), 0.0) # basis.z -> +Z, out onto the roof
	add_gate.call("NorthExitGate", Vector3(ndoor, 0, nz1), 0.0)

	# --- South stairs bulkhead, over the opening left in the slab above the upper ramp. The
	# ramp climbs west and arrives at X = SOUTH_STAIRS_RAMP_INNER_X, so the door is in the west
	# side, opening west onto Roof_SW. ---
	var sx0: float = SOUTH_STAIRS_RAMP_INNER_X
	var sx1: float = SOUTH_STAIRS_LANDING_INNER_X
	var sz0: float = (SOUTH_STAIRS_ZONE_Z_START + SOUTH_STAIRS_ZONE_Z_END) / 2.0
	var sz1: float = SOUTH_STAIRS_ZONE_Z_END
	var sdoor: float = (sz0 + sz1) / 2.0
	box.call("SouthExit_North", sx0, sx1, 0.0, hh, sz0 - 0.2, sz0)
	box.call("SouthExit_South", sx0, sx1, 0.0, hh, sz1 - 0.2, sz1)
	box.call("SouthExit_East", sx1, sx1 + 0.2, 0.0, hh, sz0 - 0.2, sz1)
	box.call("SouthExit_WestA", sx0 - 0.1, sx0 + 0.1, 0.0, hh, sz0 - 0.2, sdoor - 0.6)
	box.call("SouthExit_WestB", sx0 - 0.1, sx0 + 0.1, 0.0, hh, sdoor + 0.6, sz1)
	box.call("SouthExit_Lintel", sx0 - 0.1, sx0 + 0.1, 2.2, hh, sdoor - 0.6, sdoor + 0.6)
	box.call("SouthExit_Cap", sx0 - 0.1, sx1 + 0.2, hh, hh + 0.2, sz0 - 0.2, sz1)
	add_door.call("SouthExitDoor", Vector3(sx0, 0, sdoor), -PI / 2.0) # basis.z -> -X, out onto the roof
	add_gate.call("SouthExitGate", Vector3(sx0, 0, sdoor), -PI / 2.0)

	# --- Elevator machine room, over the lift shaft (shaft interior X 4.95..9.45, Z -30..-25).
	# An ordinary room on the roof: a door, no floor gate. ---
	var mx0: float = ELEVATOR_CENTER_X - 2.0
	var mx1: float = ELEVATOR_CENTER_X + 2.0
	var mz0: float = -29.6
	var mz1: float = -26.0
	box.call("MachineRoom_West", mx0, mx0 + 0.2, 0.0, hh, mz0, mz1)
	box.call("MachineRoom_East", mx1 - 0.2, mx1, 0.0, hh, mz0, mz1)
	box.call("MachineRoom_North", mx0, mx1, 0.0, hh, mz0, mz0 + 0.2)
	box.call("MachineRoom_SouthA", mx0, ELEVATOR_CENTER_X - 0.6, 0.0, hh, mz1 - 0.1, mz1 + 0.1)
	box.call("MachineRoom_SouthB", ELEVATOR_CENTER_X + 0.6, mx1, 0.0, hh, mz1 - 0.1, mz1 + 0.1)
	box.call("MachineRoom_Lintel", ELEVATOR_CENTER_X - 0.6, ELEVATOR_CENTER_X + 0.6, 2.2, hh, mz1 - 0.1, mz1 + 0.1)
	box.call("MachineRoom_Cap", mx0, mx1, hh, hh + 0.2, mz0, mz1 + 0.1)
	add_door.call("MachineRoomDoor", Vector3(ELEVATOR_CENTER_X, 0, mz1), 0.0)

	var room_light = OmniLight3D.new()
	room_light.name = "MachineRoomLight"
	room_light.light_color = Color(1.0, 0.25, 0.15) # emergency red
	room_light.light_energy = 1.2
	room_light.omni_range = 5.0 * f_scale
	room_light.position = Vector3(ELEVATOR_CENTER_X, 2.2, (mz0 + mz1) / 2.0) * f_scale
	parent.add_child(room_light)

	# The code plate on the back wall - see roof_code_plate.gd.
	var plate = Area3D.new()
	plate.name = "LiftCodePlate"
	plate.collision_layer = 4 # same layer vhs_tape.tscn uses - the interact raycast's mask
	plate.collision_mask = 0
	plate.set_script(load("res://scripts/interactables/roof_code_plate.gd"))
	plate.position = Vector3(ELEVATOR_CENTER_X, 1.4, mz0 + 0.26) * f_scale
	var plate_coll = CollisionShape3D.new()
	var plate_shape = BoxShape3D.new()
	plate_shape.size = Vector3(0.9, 0.6, 0.2) * f_scale
	plate_coll.shape = plate_shape
	plate.add_child(plate_coll)
	var plate_mesh = MeshInstance3D.new()
	var plate_box = BoxMesh.new()
	plate_box.size = Vector3(0.8, 0.5, 0.04) * f_scale
	var plate_mat = StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.55, 0.5, 0.2)
	plate_mat.metallic = 0.6
	plate_mat.roughness = 0.5
	plate_box.material = plate_mat
	plate_mesh.mesh = plate_box
	plate.add_child(plate_mesh)
	var plate_text = Label3D.new()
	plate_text.name = "Text"
	plate_text.font_size = 40
	plate_text.modulate = Color(0.05, 0.05, 0.05)
	plate_text.outline_size = 0
	plate_text.position = Vector3(0, 0, 0.03) * f_scale
	plate.add_child(plate_text)
	parent.add_child(plate)

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
		var layout = DOUBLE_ROOM_LAYOUT if is_double else SINGLE_ROOM_LAYOUT
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
	var f_scale = GlobalConfig.get_floor_scale()
	var floor_num = GameStateManager.secret_portal_floor
	var suffix = "Main" if floor_num == floor_number else str(floor_num)
	var floor_node = get_node_or_null("GeneratedFloor_" + suffix)
	if not floor_node: return

	var is_double = GameStateManager.secret_portal_is_double
	var layout = DOUBLE_ROOM_LAYOUT if is_double else SINGLE_ROOM_LAYOUT
	var room_layout = layout.get(GameStateManager.secret_portal_room_num)
	if not room_layout: return
	var door_local_z = DOUBLE_ROOM_EXIT_DOOR_LOCAL_Z if is_double else SINGLE_ROOM_EXIT_DOOR_LOCAL_Z
	if room_layout["mirror"]:
		door_local_z = -door_local_z
	var room_z = (room_layout["z"] + door_local_z) * f_scale

	# Rooms only own their corridor-facing wall (RoomEastWall/RoomWestWall's equivalent) - the
	# building's actual OUTER wall is one long Wall_West/Wall_East shared by every room on that
	# side, built once per floor in _build_floor_geometry(). It's a plain StaticBody3D+BoxMesh,
	# not CSG, so a doorway is cut by replacing it with two shorter segments plus a gap - the
	# same "union boxes instead of CSG subtraction" approach already used for the wardrobe back
	# panel and the stairs walls (CSG subtraction on a wall this size is exactly the kind of
	# operation that's repeatedly made a WHOLE combined shape vanish elsewhere in this project).
	var wall_name = "Wall_West" if is_double else "Wall_East"
	var old_wall = floor_node.get_node_or_null(wall_name)
	if not old_wall: return

	var wall_mesh: MeshInstance3D = old_wall.get_node("MeshInstance3D")
	var wall_mat: Material = wall_mesh.mesh.material

	var half_x = (BUILDING_WIDTH_X * f_scale) / 2.0
	var half_z = (BUILDING_LENGTH_Z * f_scale) / 2.0
	var thickness = wall_thickness * f_scale
	var height = corridor_height * f_scale
	var floor_thick = floor_thickness * f_scale
	var outer_wall_height = height + floor_thick
	var outer_wall_y = (height - floor_thick) / 2.0
	var wall_x = (-half_x - thickness / 2.0) if is_double else (half_x + thickness / 2.0)

	var door_w = 1.2 * f_scale
	var door_h = 2.2 * f_scale
	var gap_half = door_w / 2.0

	old_wall.queue_free()

	var seg_a_len = (room_z - gap_half) - (-half_z)
	if seg_a_len > 0.1:
		var seg_a_z = (-half_z + (room_z - gap_half)) / 2.0
		_create_static_box(floor_node, wall_name + "_A", Vector3(wall_x, outer_wall_y, seg_a_z), Vector3(thickness, outer_wall_height, seg_a_len), wall_mat)

	var seg_b_len = half_z - (room_z + gap_half)
	if seg_b_len > 0.1:
		var seg_b_z = ((room_z + gap_half) + half_z) / 2.0
		_create_static_box(floor_node, wall_name + "_B", Vector3(wall_x, outer_wall_y, seg_b_z), Vector3(thickness, outer_wall_height, seg_b_len), wall_mat)

	# Standard door.tscn, same as everywhere else in the hotel - basis.z points outward, away
	# from the building interior, matching the "always points toward the corridor" rule doors
	# use elsewhere (here there's no corridor beyond it, just the portal).
	var door_scene = load("res://entities/props/door.tscn")
	if door_scene:
		var door_inst = door_scene.instantiate()
		door_inst.name = "SecretExitDoor"
		door_inst.position = Vector3(wall_x, 0, room_z)
		door_inst.rotation.y = (-PI / 2.0) if is_double else (PI / 2.0)
		door_inst.scale = Vector3(door_w, f_scale, f_scale)
		floor_node.add_child(door_inst)

	# Teleport trigger filling the doorway - stepping through leads to the fixed floor-3 room
	# rolled once in _on_all_tapes_collected(), and permanently unlocks stairs access to floor 3
	# (secret_portal.gd calls GameStateManager.unlock_floor() itself once target_floor is set).
	if GameStateManager.secret_portal_target != Vector3.ZERO:
		var area = Area3D.new()
		area.collision_layer = 0
		area.collision_mask = 1 # Player layer
		var coll = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		# Starts just PAST the wall's own center plane and extends outward from there, so it can
		# only be reached by opening the door and stepping into the doorway. (It used to straddle
		# the wall and reach 0.3m into the room - touching the still-closed door set it off.)
		var portal_depth: float = 0.8 * f_scale
		var outward: float = -1.0 if is_double else 1.0
		shape.size = Vector3(portal_depth, door_h, door_w * 0.8)
		coll.shape = shape
		area.add_child(coll)
		var script = load("res://scripts/interactables/secret_portal.gd")
		if script:
			area.set_script(script)
		area.target_position = GameStateManager.secret_portal_target
		area.target_floor = GameStateManager.secret_portal_target_floor
		area.position = Vector3(wall_x + outward * (0.05 * f_scale + portal_depth / 2.0), door_h / 2.0, room_z)
		floor_node.add_child(area)

	# "Something heavy just fell/crashed somewhere in the hotel" cue, per the request that
	# triggered this feature - reusing door_open.wav pitched way down instead of a new asset,
	# the same trick this project's now-deleted legacy exit_door rumble sound used.
	var audio = AudioStreamPlayer3D.new()
	audio.stream = load("res://assets/audio/sfx/door_open.wav")
	audio.pitch_scale = 0.3
	audio.volume_db = 15.0
	audio.position = Vector3(wall_x, outer_wall_y, room_z)
	floor_node.add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

# Picks a random room on floor 3 specifically (per the request this implements) and a safe
# standing spot just inside it - same relative offsets already proven by the room-to-room secret
# portal this replaces.
func _pick_random_floor3_target() -> Vector3:
	var is_single = randi() % 2 == 1
	var layout = SINGLE_ROOM_LAYOUT if is_single else DOUBLE_ROOM_LAYOUT
	var keys = layout.keys()
	var room_num = keys[randi() % keys.size()]
	var prefix = "SingleRoom_" if is_single else "DoubleRoom_"
	var room_name = prefix + str(3 * 100 + (room_num % 100))
	var room_node = find_child(room_name, true, false)
	if not room_node:
		return Vector3.ZERO
	var target_pos = room_node.global_position
	if is_single:
		# Open floor just inside RoomDoor, south of the WC. (Was Z=2.5 - dead center of
		# WCSouthWall, which spans X -3.75..-1.35 there outside its own door hole.)
		target_pos += room_node.global_basis * Vector3(-1.5, 0.5, 3.6)
	else:
		target_pos += room_node.global_basis * Vector3(2.5, 0.5, 7.5)
	return target_pos
