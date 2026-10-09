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
		# Floor 10 has them too, on top of its own edge (edge_wall_trap.gd waits out the dark).
		if i == 7 or i == 2 or i == 10:
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
		# Uses the exact same "closest wardrobe to world origin" pick HotelPropSpawner.spawn_cassettes()
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


# Floor 5's sealed room door (HotelTrapBuilder.add_room_shuffle_trap()); opened again by
# HotelProgression once that floor's tapes are in.
var _sealed_room_door: Node = null

func _find_props(node: Node, prop_name: String, arr: Array) -> void:
	HotelPropSpawner.find_props(node, prop_name, arr)

# Per LORE.md, Cassette #1 ("Личность") is found in the starting room's furniture and
# Cassette #2 ("Инцидент") is nearby in the corridor - both close to where the player actually
# appears. The player spawns at the same world (X=0, Z=0) on every floor (see _move_player()),
# so "closest to spawn" is a stand-in for "in/near the starting room" that works on any floor,
# not just the one the player happens to be reading this on.
func _closest_to_spawn(props: Array) -> Node:
	return HotelPropSpawner.closest_to_spawn(props)

# The game's tutorial - see wake_up_room.gd. The room is the one the player starts in, i.e. the
# one whose wardrobe holds Cassette #1 (same pick as HotelPropSpawner.spawn_cassettes_start_floor() and
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

func _generate_roof(y_offset: float, f_scale: float) -> void:
	HotelRoofBuilder.generate_roof(self, y_offset, f_scale)
func _on_all_tapes_collected() -> void:
	HotelProgression.on_all_tapes_collected(self)

# Rebuilds the same doorway from GameStateManager's persisted secret_portal_* fields - called
# both right after _on_all_tapes_collected() rolls them, and from _ready() if this level scene
# reloads after the door already exists (so it doesn't move to a new random spot on reload).
func _create_exit_portal() -> void:
	HotelPortalSpawner.create_exit_portal(self)
