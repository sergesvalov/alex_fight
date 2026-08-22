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
const ELEVATOR_DOOR_SCALE_X: float = 1.42

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
		_create_secret_portal()
		
	if not Engine.is_editor_hint():
		# Allow physics to settle
		await get_tree().physics_frame
		await get_tree().physics_frame
		
		var nav_region = get_parent()
		if nav_region is NavigationRegion3D:
			nav_region.bake_navigation_mesh()

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
	_generate_north_stairs(parent, f_scale)

	if is_empty:
		return parent

	# 3.5 Maintenance Room
	_generate_maintenance_room(parent, f_scale, height, thickness, wall_mat)
	
	# 3.7.5 South Stairs Wall
	_generate_south_stairs_wall(parent, f_scale, height, thickness, wall_mat)
	_generate_south_stairs_ramp(parent, f_scale, height, floor_thick, floor_mat)


	for room_num in DOUBLE_ROOM_LAYOUT:
		_generate_double_room(parent, f_scale, f_num, room_num)
	for room_num in SINGLE_ROOM_LAYOUT:
		_generate_single_room(parent, f_scale, f_num, room_num)
	
	_spawn_cassettes(parent, f_scale)
	_spawn_cerberus(parent, f_scale)

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
		parent.add_child(inst)

		var door_scene = load("res://entities/props/elevator_door.tscn")
		if door_scene:
			var door_inst = door_scene.instantiate()
			door_inst.name = "ElevatorDoor"
			door_inst.position = Vector3(0, 0, 0.1 * f_scale)
			door_inst.scale = Vector3(ELEVATOR_DOOR_SCALE_X, 1.0, 1.0)
			inst.add_child(door_inst)

		# Floor buttons are NOT created here. elevator_shaft.tscn already ships a real,
		# wired-up "ButtonFloor4" template under ElevatorPanel, and elevator_controller.gd's
		# _setup_buttons() duplicates it for floors 1-10 and connects button_pressed itself.
		# This function used to *also* spawn a second, disconnected AnimatableBody3D button
		# almost exactly on top of the real one (off by 1cm) - it never fired
		# _on_button_pressed (nothing connected to it) and was the reason a "phantom" button
		# hitbox could be interacted with near the panel without doing anything.

func _generate_north_stairs(parent: Node, f_scale: float) -> void:
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

func _spawn_cassettes(parent: Node, f_scale: float) -> void:
	var scene = load("res://entities/interactables/vhs_tape.tscn")
	if not scene: return
	
	var wardrobes = []
	_find_props(parent, "Wardrobe", wardrobes)
	var chosen_wardrobe = null
	if wardrobes.size() > 0:
		chosen_wardrobe = wardrobes[randi() % wardrobes.size()]

	var tables = []
	_find_props(parent, "Table", tables)
	var chosen_table = null
	if tables.size() > 0:
		chosen_table = tables[randi() % tables.size()]
		
	for i in range(3):
		var inst = scene.instantiate()
		inst.name = "Cassette_" + str(i)

		# position/transform MUST be set before add_child() - see _generate_maintenance_room()
		# for why. chosen_wardrobe/chosen_table are unrelated, already-placed nodes, so reading
		# their global_transform here is unaffected by inst's own tree membership.
		if i == 0 and chosen_wardrobe != null:
			inst.global_transform = chosen_wardrobe.global_transform
			# X=-0.28 matches the shelf zone's center in wardrobe.tscn (the other half of the
			# interior is now an open hanging compartment with a rod, not a shelf).
			inst.global_position += chosen_wardrobe.global_basis * Vector3(-0.28, 1.15, 0.05)
		elif i == 1 and chosen_table != null:
			inst.global_transform = chosen_table.global_transform
			inst.global_position += chosen_table.global_basis * Vector3(0.0, 0.8, 0.0)
		elif i == 2:
			inst.position = Vector3(7.2 * f_scale, 0.05 * f_scale, -23.5 * f_scale)
			inst.rotation.y = randf_range(0, PI * 2)
		else:
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

func _on_all_tapes_collected() -> void:
	if GameStateManager.secret_portal_active: return
	var valid_rooms = [1, 2, 3, 5, 6, 8, 10, 11, 12, 13, 15, 16, 17, 20, 21]
	GameStateManager.secret_portal_room_a = valid_rooms[randi() % valid_rooms.size()]
	GameStateManager.secret_portal_room_b = valid_rooms[randi() % valid_rooms.size()]
	GameStateManager.secret_portal_active = true
	_create_secret_portal()

func _create_secret_portal() -> void:
	_create_portal_for_room(GameStateManager.secret_portal_room_a, 4, GameStateManager.secret_portal_room_b, 3)
	_create_portal_for_room(GameStateManager.secret_portal_room_b, 3, GameStateManager.secret_portal_room_a, 4)

func _create_portal_for_room(room_idx: int, floor_num: int, target_room_idx: int, target_floor_num: int) -> void:
	var is_single = (room_idx >= 10)
	var prefix = "SingleRoom_" if is_single else "DoubleRoom_"
	var room_name = prefix + str(floor_num * 100 + room_idx)
	var room_node = find_child(room_name, true, false)
	if not room_node: return
	
	var geometry = room_node.get_node_or_null("RoomGeometry")
	if not geometry: return
	
	var hole = CSGBox3D.new()
	hole.operation = CSGBox3D.OPERATION_SUBTRACTION
	hole.size = Vector3(1.0, 2.2, 1.0)
	
	if is_single:
		# West wall
		hole.position = Vector3(-3.75, 1.1, 2.5)
	else:
		# East wall
		hole.position = Vector3(4.8, 1.1, 5.0)
		
	geometry.add_child(hole)
	
	var area = Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1 # Player layer
	
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.8, 2.0, 0.8)
	coll.shape = shape
	area.add_child(coll)
	
	var script = load("res://scripts/interactables/secret_portal.gd")
	if script:
		area.set_script(script)
		
	var target_is_single = (target_room_idx >= 10)
	var target_prefix = "SingleRoom_" if target_is_single else "DoubleRoom_"
	var target_room_name = target_prefix + str(target_floor_num * 100 + target_room_idx)
	var target_room_node = find_child(target_room_name, true, false)
	
	if target_room_node:
		var target_pos = target_room_node.global_position
		if target_is_single:
			target_pos += target_room_node.global_basis * Vector3(-1.5, 0.5, 2.5)
		else:
			target_pos += target_room_node.global_basis * Vector3(2.5, 0.5, 7.5)
		area.target_position = target_pos
		
	hole.add_child(area)

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
