@tool
extends Node3D
class_name HotelLevelGenerator

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
# Single source of truth for the elevator door's X scale - used to be duplicated (and
# drifted slightly out of sync) between this generator and tests/test_elevator_alignment.gd.
# 1.42 (native 1.4m panel -> ~1.99m wide) never fit: the pocket between ElevatorDoorHole's edge
# and the car's own ElevatorEastWall is only 1.5m (2.25 - 0.75), so a ~2m-wide door could never
# be slid fully clear of the hole no matter the open_offset - some of the panel always remained
# stuck in the doorway, and the rest punched through the car's side wall into the hotel wall
# beyond it, appearing to "vanish behind the hotel wall" (confirmed via the ASCII bounds test in
# tests/test_elevator_alignment.gd, which only ever checked the CLOSED position and so never
# caught this - see hole size in elevator_shaft.tscn and open_offset in elevator_door.tscn,
# updated together with this value).
const ELEVATOR_DOOR_SCALE_X: float = 0.93

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
	421: {"z": 20.0, "mirror": false},
}

@export var floor_number: int = 4
@export var player_spawn_pos: Vector3 = Vector3(0, 1.0, 0)
@export var floor_thickness: float = BASE_FLOOR_THICKNESS
@export var corridor_height: float = BASE_CORRIDOR_HEIGHT
@export var wall_thickness: float = 0.2
@export var carpet_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var map_texture: Texture2D = null
@export var empty_box_mode: bool = false

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
@onready var floor_texture = _load_texture_safe("res://assets/textures/hotel_carpet.jpg")

# Per-floor lighting: all 10 floors physically coexist in this one scene, stacked at
# different Y offsets (see _generate_level) - without this, every room/stairs/elevator
# light on all 10 floors would be lit simultaneously even though the player can only
# ever be on one of them at a time.
var _floor_lights_by_index: Dictionary = {}   # int floor index (1..10) -> Array[Light3D]
var _lit_floor_index: int = -1
var _light_y_step: float = 0.0

func _ready() -> void:
	if GameStateManager.has_signal("all_tapes_collected"):
		GameStateManager.connect("all_tapes_collected", _on_all_tapes_collected)
	_generate_level()
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
			nav_region.bake_navigation_mesh()
			await nav_region.bake_finished
			print("[generator] navigation mesh baked - releasing enemies to patrol")
			get_tree().call_group("enemies", "_on_navmesh_ready")
		else:
			print("[generator] WARNING: parent is not NavigationRegion3D, navmesh never baked - ", nav_region)

func _generate_level() -> void:
	print("Generating 3 hotel levels geometry with StaticBodies...")
	
	for child in get_children():
		child.free()
	_floor_lights_by_index.clear()
	_lit_floor_index = -1

	var f_scale = GlobalConfig.get_floor_scale()
	var height = corridor_height * f_scale
	var floor_thick = floor_thickness * f_scale
	var y_step = height + floor_thick

	# Stairs gates (stairs_gate.gd, South and North) compare against this to tell a floor-hop
	# attempt apart from the player just visiting their own floor's stairwell.
	GameStateManager.current_floor = floor_number
	# Seeds the stairs-access range at the spawn floor only - a no-op if already initialized
	# (e.g. this level scene reloading mid-playthrough), since the range is meant to persist.
	GameStateManager.init_floor_access(floor_number)

	var get_color_from_scene = func(level_num: int) -> Color:
		var scene_path = "res://scenes/levels/hotel_siberia/hotel_level_" + str(level_num) + ".tscn"
		if ResourceLoader.exists(scene_path):
			var packed = load(scene_path)
			if packed:
				var temp = packed.instantiate()
				var geom = temp.get_node_or_null("NavigationRegion3D/HotelGeometry")
				if geom and "carpet_color" in geom:
					var c = geom.carpet_color
					temp.queue_free()
					return c
				temp.queue_free()
		return Color(1, 1, 1) # Default
		
	for i in range(1, 11):
		var y_offset = (i - floor_number) * y_step
		var suffix = str(i)
		if i == floor_number:
			suffix = "Main"
			
		var c_color = carpet_color
		if i == 4:
			c_color = Color(1.0, 1.0, 1.0, 1.0)
		elif i != floor_number:
			c_color = get_color_from_scene.call(i)
			
		var m_tex = null
		if i == floor_number:
			m_tex = map_texture
			
		var is_empty = false
		if i == 1:
			is_empty = true

		var floor_node = _build_floor_geometry(i, y_offset, suffix, c_color, m_tex, is_empty, f_scale)
		var lights: Array = []
		_find_lights(floor_node, lights)
		_floor_lights_by_index[i] = lights

	# Generate roof above the 10th floor
	var roof_y_offset = (11 - floor_number) * y_step
	_generate_roof(roof_y_offset, f_scale)

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

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _light_y_step <= 0.0:
		return
	var player = get_node_or_null("../../Player")
	if not player:
		if get_tree() and get_tree().current_scene:
			player = get_tree().current_scene.get_node_or_null("Player")
	if not player:
		return
	var floor_index = int(round(player.global_position.y / _light_y_step)) + floor_number
	floor_index = clampi(floor_index, 1, 10)
	_set_lit_floor(floor_index)

func _build_floor_geometry(f_num: int, y_offset: float, suffix: String, c_color: Color, m_texture: Texture2D, is_empty: bool, f_scale: float) -> Node3D:
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
	_generate_elevator(parent, f_scale, height, thickness, wall_mat)
	
	# 3.7 North Stairs
	_generate_north_stairs(parent, f_scale, f_num)

	if is_empty:
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
	
	_spawn_cassettes(parent, f_scale, f_num)
	_spawn_cerberus(parent, f_scale)

	# Floor 4 only - see _add_floor4_corridor_barrier()'s own comment for why.
	if f_num == 4:
		_add_floor4_corridor_barrier(parent, f_scale)

	# 5. Floor Map
	var map_mesh = MeshInstance3D.new()
	map_mesh.name = "FloorMap"
	var quad = QuadMesh.new()
	quad.size = Vector2(2.0, 1.5)
	
	var map_mat = StandardMaterial3D.new()
	if m_texture:
		map_mat.albedo_texture = m_texture
	else:
		var map_tex = load("res://assets/textures/hotel_map.jpg")
		if map_tex:
			map_mat.albedo_texture = map_tex
		else:
			map_mat.albedo_color = Color(1.0, 0.0, 0.0)
	map_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
		print("Player moved to: ", p_spawn)

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
			parent.add_child(wardrobe_inst)

func _generate_elevator(parent: Node, f_scale: float, height: float, thickness: float, wall_mat: Material) -> void:
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
			door_inst.scale = Vector3(ELEVATOR_DOOR_SCALE_X, 1.0, 1.0)
			inst.add_child(door_inst)

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

# Floor 4's own "endless corridor" nightmare: until its 3 tapes are collected, this splits the
# main corridor in half at its own center (z_main_pos in _build_floor_geometry - reused here as
# a plain constant since that local var isn't in scope) and bounces the player back whenever they
# cross it, keeping the elevator and North Stairs (the north end) permanently just out of reach -
# the corridor never actually gets you there, no matter how far you walk. Percentages per the
# original request: South Stairs' own Z (SOUTH_STAIRS_ZONE_Z_START) is 0%, this barrier's own
# position is 100%, and crossing it always sends the player back to the 50% mark - halfway back
# toward the South Stairs end, comfortably clear of the barrier so it doesn't immediately
# re-trigger. Pairs with the OTHER nightmare this session added - the secret exit door
# (_create_exit_portal()) that leads to an unknown room on floor 3, wherever the dice landed;
# that one is untouched by this and stays reachable from the south side regardless of where it
# ended up (per the request: "if the door didn't land in the south part, that's fine - it just
# becomes the far edge of the reachable area").
func _add_floor4_corridor_barrier(parent: Node, f_scale: float) -> void:
	var mid_z = -0.09 * f_scale # matches z_main_pos - Floor_Main's own Z center
	var south_z = SOUTH_STAIRS_ZONE_Z_START * f_scale
	var return_z = (south_z + mid_z) / 2.0

	var corridor_center_x = (CORRIDOR_WEST_EDGE_X + CORRIDOR_EAST_EDGE_X) / 2.0 * f_scale
	var corridor_width = (CORRIDOR_EAST_EDGE_X - CORRIDOR_WEST_EDGE_X) * f_scale

	var barrier = Area3D.new()
	barrier.name = "Floor4CorridorBarrier"
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

# Adds a door.tscn instance as a child of a room instance, positioned/rotated in the room's
# OWN local space (so it inherits the room's position and mirror scale like every other prop).
# RoomDoor/WCDoor used to be embedded directly in double_room.tscn/single_room.tscn instead,
# but ANY room .tscn that embeds a door.tscn node instance loses nodes once packed into an
# exported PCK (confirmed 2026-08-22 via PackedScene.get_state(), which showed nodes already
# missing from the raw resource before instantiate() ever runs - not an add_child()/instantiate()
# bug on this end). Creating the door in code sidesteps that entirely, the same way
# MaintenanceDoor/SouthStairsDoor/ElevatorDoor already reliably do across all 10 floors.
func _add_room_door(room_inst: Node, node_name: String, local_pos: Vector3, rot_y: float) -> void:
	var door_scene = load("res://entities/props/door.tscn")
	if not door_scene: return
	var door_inst = door_scene.instantiate()
	door_inst.name = node_name
	door_inst.position = local_pos
	door_inst.rotation.y = rot_y
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
	_add_room_door(inst, "RoomDoor", Vector3(4.8, 0.0, 8.5), PI / 2.0)
	# Проём в WCSouthWall (X=2.35, Z=4.9), номер к югу -> basis.z смотрит +Z (без поворота).
	_add_room_door(inst, "WCDoor", Vector3(2.35, 0.0, 4.9), 0.0)

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
	_add_room_door(inst, "RoomDoor", Vector3(-3.75, 0.0, 3.5), -PI / 2.0)
	# Проём в WCSouthWall (X=-2.55, Z=2.5), номер к югу -> basis.z смотрит +Z (без поворота).
	_add_room_door(inst, "WCDoor", Vector3(-2.55, 0.0, 2.5), 0.0)

	parent.add_child(inst)

func _create_static_box(parent: Node, node_name: String, pos: Vector3, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> void:
	var static_body = StaticBody3D.new()
	static_body.name = node_name
	static_body.position = pos
	static_body.rotation = rot
	static_body.collision_layer = 2 # Matches old floor layer
	
	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = mat
	mesh_inst.mesh = box_mesh
	static_body.add_child(mesh_inst)
	
	var coll = CollisionShape3D.new()
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
		# grows past size 1, all_tapes_collected/exit_code_known never fire,
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
			var target = chosen_wardrobe.global_transform
			# X=-0.28 matches the shelf zone's center in wardrobe.tscn (the other half of the
			# interior is now an open hanging compartment with a rod, not a shelf).
			target.origin += chosen_wardrobe.global_basis * Vector3(-0.28, 1.15, 0.05)
			inst.transform = parent.global_transform.affine_inverse() * target
		elif i == 1 and chosen_table != null:
			var target = chosen_table.global_transform
			target.origin += chosen_table.global_basis * Vector3(0.0, 0.8, 0.0)
			inst.transform = parent.global_transform.affine_inverse() * target
		elif i == 2:
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
	var tables = []
	_find_props(parent, "Table", tables)
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
			var target = chosen_table.global_transform
			target.origin += chosen_table.global_basis * Vector3(0.0, 0.8, 0.0)
			inst.transform = parent.global_transform.affine_inverse() * target
		elif i == 1 and maint_wardrobe != null:
			var target = maint_wardrobe.global_transform
			target.origin += maint_wardrobe.global_basis * Vector3(-0.28, 1.15, 0.05)
			inst.transform = parent.global_transform.affine_inverse() * target
		elif i == 2 and chosen_wardrobe != null:
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
	inst.patrol_points = [patrol_a, patrol_b]

	parent.add_child(inst)

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

	_create_static_box(parent, "Roof_Main", Vector3(0, floor_y, z_south_pos), Vector3(x_width, floor_thick, z_south_len), roof_mat)
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

# Fires once for the FIRST floor whose 3 tapes are all collected (any floor - see
# GameStateManager.collect_tape()) - in practice this is always floor 4, since it's the only
# floor unlocked at game start and every other floor is gated behind mechanics this same
# function unlocks. Two independent rewards happen together:
#   1. Punches a doorway through a random room's OUTER wall on that floor and connects it to a
#      random room on floor 3 (_create_exit_portal()) - an unmarked door to an unknown room,
#      permanently widening the stairs-access range to include floor 3 once actually walked
#      through (secret_portal.gd calls GameStateManager.unlock_floor()).
#   2. Floor 4's own corridor-splitting barrier (_add_floor4_corridor_barrier(),
#      corridor_barrier.gd) is switched off outright, and floor 5 unlocks immediately - no need
#      to walk anywhere first, collecting the tapes is the whole trigger.
# Gated by secret_portal_active so both only ever happen once, regardless of how many other
# floors' tapes get collected afterward.
func _on_all_tapes_collected() -> void:
	if GameStateManager.secret_portal_active: return
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

	GameStateManager.floor4_corridor_unlocked = true
	GameStateManager.unlock_floor(5)

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
	var room_z = room_layout["z"] * f_scale

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
		shape.size = Vector3(thickness + 0.6, door_h, door_w * 0.8)
		coll.shape = shape
		area.add_child(coll)
		var script = load("res://scripts/interactables/secret_portal.gd")
		if script:
			area.set_script(script)
		area.target_position = GameStateManager.secret_portal_target
		area.target_floor = GameStateManager.secret_portal_target_floor
		area.position = Vector3(wall_x, door_h / 2.0, room_z)
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
		target_pos += room_node.global_basis * Vector3(-1.5, 0.5, 2.5)
	else:
		target_pos += room_node.global_basis * Vector3(2.5, 0.5, 7.5)
	return target_pos

var _retro_wall_mat: StandardMaterial3D

func _apply_retro_wallpaper(room_inst: Node3D) -> void:
	if not _retro_wall_mat:
		_retro_wall_mat = StandardMaterial3D.new()
		_retro_wall_mat.albedo_texture = retro_wall_texture
		_retro_wall_mat.uv1_scale = Vector3(20, 2, 2)
		_retro_wall_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	
	var geometry = room_inst.get_node_or_null("RoomGeometry")
	if geometry:
		for child in geometry.get_children():
			if child is CSGBox3D and "Wall" in child.name:
				child.material = _retro_wall_mat
			elif child is CSGCombiner3D and child.name == "RoomNorthWall":
				child.material = _retro_wall_mat
