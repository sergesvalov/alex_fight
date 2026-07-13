@tool
extends Node3D
class_name HotelLevelGenerator

# Small vertical offset to prevent Z-fighting between the ceiling of one floor
# and the floor slab of the floor above on Android (gl_compatibility / 16-bit depth).
const CEIL_BIAS: float = 0.001

@export var floor_number: int = 4
@export var player_spawn_pos: Vector3 = Vector3(0, 1.0, 0)
@export var floor_thickness: float = 0.5
@export var corridor_height: float = 4.0
@export var wall_thickness: float = 0.2
@export var carpet_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var map_texture: Texture2D = null
@export var empty_box_mode: bool = false

static func _load_texture_safe(path: String) -> Texture2D:
	if DisplayServer.get_name() == "headless":
		if FileAccess.file_exists(path):
			var img = Image.new()
			if img.load(path) == OK:
				return ImageTexture.create_from_image(img)
		return null
		
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

@onready var carpet_texture = _load_texture_safe("res://assets/textures/hotel_carpet.jpg")
@onready var wall_texture = _load_texture_safe("res://assets/textures/hotel_wallpaper.jpg")
@onready var retro_wall_texture = _load_texture_safe("res://assets/textures/retro_wallpaper.png")
@onready var ceiling_texture = _load_texture_safe("res://assets/textures/hotel_wallpaper.jpg")
@onready var floor_texture = _load_texture_safe("res://assets/textures/hotel_carpet.jpg")

func _ready() -> void:
	GameStateManager.all_tapes_collected.connect(_on_all_tapes_collected)
	_generate_level()
	if GameStateManager.secret_portal_active:
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
			
		_build_floor_geometry(i, y_offset, suffix, c_color, m_tex, is_empty, f_scale)
		
	# Generate roof above the 10th floor
	var roof_y_offset = (11 - floor_number) * y_step
	_generate_roof(roof_y_offset, f_scale)
		
	call_deferred("_move_player", f_scale)

func _build_floor_geometry(f_num: int, y_offset: float, suffix: String, c_color: Color, m_texture: Texture2D, is_empty: bool, f_scale: float) -> void:
	var parent = Node3D.new()
	parent.name = "GeneratedFloor_" + suffix
	parent.position.y = y_offset
	add_child(parent)
	
	var z_length = 60.0 * f_scale
	var x_width = 25.3 * f_scale
	var height = corridor_height * f_scale
	var thickness = wall_thickness * f_scale
	var floor_thick = floor_thickness * f_scale
	
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
	var x_nw_len = 10.1 * f_scale
	var x_nw_pos = -7.6 * f_scale
	var x_ne_len = 8.0 * f_scale
	var x_ne_pos = 8.65 * f_scale
	
	var z_sw_len = 5.0 * f_scale
	var z_sw_pos = 27.5 * f_scale
	var x_sw_len = 14.52 * f_scale
	var x_sw_pos = -5.39 * f_scale
	
	# Central Main (covers everything from Z=-25.18 to Z=25.0)
	_create_static_box(parent, "Floor_Main", Vector3(0, floor_y, z_main_pos), Vector3(x_width, floor_thick, z_main_len), floor_mat)
	_create_static_box(parent, "Ceiling_Main", Vector3(0, ceil_y, z_main_pos), Vector3(x_width, floor_thick, z_main_len), ceil_mat)
	
	# South West (covers Z=25.0 to 30.0, X=-12.65 to 1.87)
	_create_static_box(parent, "Floor_SW", Vector3(x_sw_pos, floor_y, z_sw_pos), Vector3(x_sw_len, floor_thick, z_sw_len), floor_mat)
	_create_static_box(parent, "Ceiling_SW", Vector3(x_sw_pos, ceil_y, z_sw_pos), Vector3(x_sw_len, floor_thick, z_sw_len), ceil_mat)
	
	# South Stairs Intermediate Landing (East Wall, half height)
	var x_landing_len = 4.62 * f_scale
	var x_landing_pos = 10.34 * f_scale
	var y_landing = height / 2.0
	_create_static_box(parent, "Landing_SouthStairs", Vector3(x_landing_pos, y_landing, z_sw_pos), Vector3(x_landing_len, floor_thick, z_sw_len), floor_mat)
	
	# North West (covers Z=-30.0 to -25.2, X=-12.65 to -2.55)
	_create_static_box(parent, "Floor_NW", Vector3(x_nw_pos, floor_y, z_north_pos), Vector3(x_nw_len, floor_thick, z_north_len), floor_mat)
	_create_static_box(parent, "Ceiling_NW", Vector3(x_nw_pos, ceil_y, z_north_pos), Vector3(x_nw_len, floor_thick, z_north_len), ceil_mat)
	
	# North East (covers Z=-30.0 to -25.2, X=4.65 to 12.65)
	_create_static_box(parent, "Floor_NE", Vector3(x_ne_pos, floor_y, z_north_pos), Vector3(x_ne_len, floor_thick, z_north_len), floor_mat)
	_create_static_box(parent, "Ceiling_NE", Vector3(x_ne_pos, ceil_y, z_north_pos), Vector3(x_ne_len, floor_thick, z_north_len), ceil_mat)
	
	# 3. Outer Walls
	var half_x = x_width / 2.0
	var half_z = z_length / 2.0
	
	var outer_wall_height = height + floor_thick
	var outer_wall_y = (height - floor_thick) / 2.0
	
	_create_static_box(parent, "Wall_West", Vector3(-half_x - thickness/2.0, outer_wall_y, 0), Vector3(thickness, outer_wall_height, z_length), wall_mat)
	_create_static_box(parent, "Wall_East", Vector3(half_x + thickness/2.0, outer_wall_y, 0), Vector3(thickness, outer_wall_height, z_length), wall_mat)
	_create_static_box(parent, "Wall_North", Vector3(0, outer_wall_y, -half_z - thickness/2.0), Vector3(x_width + thickness * 2.0, outer_wall_height, thickness), wall_mat)
	_create_static_box(parent, "Wall_South", Vector3(0, outer_wall_y, half_z + thickness/2.0), Vector3(x_width + thickness * 2.0, outer_wall_height, thickness), wall_mat)
	
	if f_num == 1:
		_create_static_box(parent, "Floor_NorthStairs", Vector3(1.05 * f_scale, floor_y, -27.6 * f_scale), Vector3(7.6 * f_scale, floor_thick, 4.8 * f_scale), floor_mat)
		
		# Fill the South Stairs hole for the ground floor
		var x_se_len = 10.78 * f_scale
		var x_se_pos = 7.26 * f_scale
		_create_static_box(parent, "Floor_SouthStairs", Vector3(x_se_pos, floor_y, z_sw_pos), Vector3(x_se_len, floor_thick, z_sw_len), floor_mat)

	# 3.6 Elevator
	_generate_elevator(parent, f_scale, height, thickness, wall_mat, f_num)
	
	# 3.7 North Stairs
	_generate_north_stairs(parent, f_scale)

	if is_empty:
		return
	
	# 3.5 Maintenance Room
	_generate_maintenance_room(parent, f_scale, height, thickness, wall_mat)
	
	# 3.7.5 South Stairs Wall
	_generate_south_stairs_wall(parent, f_scale, height, thickness, wall_mat)
	
	_generate_double_room(parent, f_scale, f_num, 401)
	_generate_double_room(parent, f_scale, f_num, 402)
	_generate_double_room(parent, f_scale, f_num, 403)
	_generate_double_room(parent, f_scale, f_num, 405)
	_generate_double_room(parent, f_scale, f_num, 406)
	_generate_double_room(parent, f_scale, f_num, 408)
	
	_generate_single_room(parent, f_scale, f_num, 410)
	_generate_single_room(parent, f_scale, f_num, 411)
	_generate_single_room(parent, f_scale, f_num, 412)
	_generate_single_room(parent, f_scale, f_num, 413)
	_generate_single_room(parent, f_scale, f_num, 415)
	_generate_single_room(parent, f_scale, f_num, 416)
	_generate_single_room(parent, f_scale, f_num, 417)
	_generate_single_room(parent, f_scale, f_num, 420)
	_generate_single_room(parent, f_scale, f_num, 421)
	
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
	_create_static_box(parent, "Maint_Inner_West_North", Vector3(9.65 * f_scale, wall_y, -27.0 * f_scale), Vector3(thickness, height, 6.0 * f_scale), wall_mat)
	_create_static_box(parent, "Maint_Inner_West_South", Vector3(9.65 * f_scale, wall_y, -21.0 * f_scale), Vector3(thickness, height, 2.0 * f_scale), wall_mat)
	var door_h = 2.2 * f_scale
	if height > door_h:
		var lintel_h = height - door_h
		var lintel_y = door_h + (lintel_h / 2.0)
		_create_static_box(parent, "Maint_Inner_West_Lintel", Vector3(9.65 * f_scale, lintel_y, -23.0 * f_scale), Vector3(thickness, lintel_h, 2.0 * f_scale), wall_mat)

func _generate_elevator(parent: Node, f_scale: float, height: float, thickness: float, wall_mat: Material, f_num: int) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/elevator_shaft.tscn")
	if scene:
		var inst = scene.instantiate()
		parent.add_child(inst)
		inst.position = Vector3(7.2 * f_scale, 0, -25.0 * f_scale)
		inst.scale.z = -1.0
		
		var door_scene = load("res://entities/props/elevator_door.tscn")
		if door_scene:
			var door_inst = door_scene.instantiate()
			door_inst.name = "ElevatorDoor"
			inst.add_child(door_inst)
			door_inst.position = Vector3(0, 0, 0.1 * f_scale)
			door_inst.scale = Vector3(1.42, 1.0, 1.0)
			
		var btn_script = load("res://scripts/interactables/elevator_button.gd")
		if btn_script:
			var btn = AnimatableBody3D.new()
			btn.name = "ButtonFloor" + str(f_num)
			btn.collision_layer = 3
			btn.set_script(btn_script)
			
			var btn_shape = CollisionShape3D.new()
			var shape = BoxShape3D.new()
			shape.size = Vector3(0.04, 0.1, 0.1)
			btn_shape.shape = shape
			btn.add_child(btn_shape)
			
			var btn_mesh = MeshInstance3D.new()
			var mesh = BoxMesh.new()
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.8, 0.8, 0.8)
			mesh.material = mat
			mesh.size = Vector3(0.04, 0.1, 0.1)
			btn_mesh.mesh = mesh
			btn.add_child(btn_mesh)
			
			var label = Label3D.new()
			label.text = str(f_num)
			label.font_size = 24
			label.outline_size = 4
			label.transform.basis = Basis(Vector3.UP, -PI/2)
			label.position = Vector3(0.021, 0, 0)
			btn.add_child(label)
			
			inst.add_child(btn)
			btn.position = Vector3(-2.13 * f_scale, 1.2 * f_scale, 2.5 * f_scale)

func _generate_north_stairs(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/north_stairs.tscn")
	if scene:
		var inst = scene.instantiate()
		parent.add_child(inst)
		inst.position = Vector3(1.05 * f_scale, 0, -30.0 * f_scale)

func _generate_south_stairs_wall(parent: Node, f_scale: float, height: float, thickness: float, wall_mat: Material) -> void:
	var z_pos = 25.0 * f_scale + (thickness / 2.0)
	var door_w = 1.2 * f_scale
	var door_h = 2.2 * f_scale
	
	var x_left = -2.75 * f_scale
	var x_right = 4.85 * f_scale
	var x_center = 1.05 * f_scale
	
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

func _generate_double_room(parent: Node, f_scale: float, f_num: int, orig_num: int) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/double_room.tscn")
	if not scene: return
	var inst = scene.instantiate()
	var room_idx = orig_num % 100
	var final_num = f_num * 100 + room_idx
	inst.name = "DoubleRoom_" + str(final_num)
	parent.add_child(inst)
	
	var base_x = -7.65
	if orig_num == 401: inst.position = Vector3(base_x * f_scale, 0, -30.0 * f_scale)
	elif orig_num == 402: inst.position = Vector3(base_x * f_scale, 0, -20.0 * f_scale)
	elif orig_num == 403: 
		inst.position = Vector3(base_x * f_scale, 0, 0.0 * f_scale)
		inst.scale.z = -1.0
	elif orig_num == 405: inst.position = Vector3(base_x * f_scale, 0, 0.0 * f_scale)
	elif orig_num == 406: inst.position = Vector3(base_x * f_scale, 0, 10.0 * f_scale)
	elif orig_num == 408:
		inst.position = Vector3(base_x * f_scale, 0, 30.0 * f_scale)
		inst.scale.z = -1.0

func _generate_single_room(parent: Node, f_scale: float, f_num: int, orig_num: int) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/single_room.tscn")
	if not scene: return
	var inst = scene.instantiate()
	var room_idx = orig_num % 100
	var final_num = f_num * 100 + room_idx
	inst.name = "SingleRoom_" + str(final_num)
	parent.add_child(inst)
	
	var base_x = 8.7
	if orig_num == 410: inst.position = Vector3(base_x * f_scale, 0, -20.0 * f_scale)
	elif orig_num == 411:
		inst.position = Vector3(base_x * f_scale, 0, -10.0 * f_scale)
		inst.scale.z = -1.0
	elif orig_num == 412: inst.position = Vector3(base_x * f_scale, 0, -10.0 * f_scale)
	elif orig_num == 413:
		inst.position = Vector3(base_x * f_scale, 0, 0.0 * f_scale)
		inst.scale.z = -1.0
	elif orig_num == 415: inst.position = Vector3(base_x * f_scale, 0, 0.0 * f_scale)
	elif orig_num == 416:
		inst.position = Vector3(base_x * f_scale, 0, 10.0 * f_scale)
		inst.scale.z = -1.0
	elif orig_num == 417:
		inst.position = Vector3(base_x * f_scale, 0, 15.0 * f_scale)
		inst.scale.z = -1.0
	elif orig_num == 420: inst.position = Vector3(base_x * f_scale, 0, 15.0 * f_scale)
	elif orig_num == 421: inst.position = Vector3(base_x * f_scale, 0, 20.0 * f_scale)

func _create_static_box(parent: Node, node_name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var static_body = StaticBody3D.new()
	static_body.name = node_name
	static_body.position = pos
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
		parent.add_child(inst)
		
		if i == 0 and chosen_wardrobe != null:
			inst.global_transform = chosen_wardrobe.global_transform
			inst.global_position += chosen_wardrobe.global_basis * Vector3(0.0, 1.15, 0.05)
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

func _spawn_cerberus(parent: Node, f_scale: float) -> void:
	var scene = load("res://entities/enemies/cerberus/cerberus.tscn")
	if not scene: return
	var inst = scene.instantiate()
	inst.name = "Cerberus"
	parent.add_child(inst)
	inst.position = Vector3(1.0 * f_scale, 0, 10.0 * f_scale)

func _generate_roof(y_offset: float, f_scale: float) -> void:
	var parent = Node3D.new()
	parent.name = "GeneratedRoof"
	parent.position.y = y_offset
	add_child(parent)
	
	var z_length = 60.0 * f_scale
	var x_width = 25.3 * f_scale
	var thickness = wall_thickness * f_scale
	var floor_thick = floor_thickness * f_scale
	
	var roof_mat = StandardMaterial3D.new()
	var roof_tex = _load_texture_safe("res://assets/textures/roof_concrete.png")
	roof_mat.albedo_texture = roof_tex
	roof_mat.uv1_scale = Vector3(10, 10, 10)
	roof_mat.albedo_color = Color(0.8, 0.8, 0.8)
	
	# Roof slabs (same logic as floor slabs)
	var floor_y = -floor_thick / 2.0
	var z_south_len = 55.18 * f_scale
	var z_south_pos = 2.41 * f_scale
	var z_north_len = 4.82 * f_scale
	var z_north_pos = -27.59 * f_scale
	
	var x_nw_len = 10.1 * f_scale
	var x_nw_pos = -7.6 * f_scale
	var x_ne_len = 8.0 * f_scale
	var x_ne_pos = 8.65 * f_scale
	
	_create_static_box(parent, "Roof_Main", Vector3(0, floor_y, z_south_pos), Vector3(x_width, floor_thick, z_south_len), roof_mat)
	_create_static_box(parent, "Roof_NW", Vector3(x_nw_pos, floor_y, z_north_pos), Vector3(x_nw_len, floor_thick, z_north_len), roof_mat)
	_create_static_box(parent, "Roof_NE", Vector3(x_ne_pos, floor_y, z_north_pos), Vector3(x_ne_len, floor_thick, z_north_len), roof_mat)
	
	# Parapets (Outer walls)
	var parapet_height = 1.0 * f_scale + floor_thick
	var parapet_y = (1.0 * f_scale - floor_thick) / 2.0
	var half_x = x_width / 2.0
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
			target_pos += target_room_node.global_basis * Vector3(0, 0.5, 2.5)
		else:
			target_pos += target_room_node.global_basis * Vector3(0, 0.5, 5.0)
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
