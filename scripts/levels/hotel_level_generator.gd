@tool
extends Node3D
class_name HotelLevelGenerator

@export var floor_number: int = 4
@export var player_spawn_pos: Vector3 = Vector3(0, 1.0, 0)
@export var floor_thickness: float = 0.5
@export var corridor_height: float = 4.0
@export var wall_thickness: float = 0.2

var carpet_texture = preload("res://assets/textures/hotel_carpet.jpg")
var wall_texture = preload("res://assets/textures/hotel_wallpaper.jpg")
var ceiling_texture = preload("res://assets/textures/hotel_wallpaper.jpg")

func _ready() -> void:
	if not Engine.is_editor_hint():
		_generate_level()
		
		# Allow physics to settle
		await get_tree().physics_frame
		await get_tree().physics_frame
		
		var nav_region = get_parent()
		if nav_region is NavigationRegion3D:
			nav_region.bake_navigation_mesh()

func _generate_level() -> void:
	print("Generating SIMPLE hotel level geometry with StaticBodies...")
	
	for child in get_children():
		child.queue_free()
		
	var parent = Node3D.new()
	parent.name = "GeneratedFloor_Main"
	add_child(parent)
		
	var f_scale = GlobalConfig.get_floor_scale()
	
	var z_length = 60.0 * f_scale
	var x_width = 25.3 * f_scale
	var height = corridor_height * f_scale
	var thickness = wall_thickness * f_scale
	var floor_thick = floor_thickness * f_scale
	
	var floor_y = -floor_thick / 2.0
	var ceil_y = height + (floor_thick / 2.0)
	
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_texture = carpet_texture
	floor_mat.uv1_scale = Vector3(10, 10, 10)
	
	var ceil_mat = StandardMaterial3D.new()
	ceil_mat.albedo_texture = ceiling_texture
	ceil_mat.uv1_scale = Vector3(10, 10, 10)
	
	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_texture = wall_texture
	wall_mat.uv1_scale = Vector3(15, 3, 1)

	# 1. Floor
	_create_static_box(parent, "Floor", Vector3(0, floor_y, 0), Vector3(x_width, floor_thick, z_length), floor_mat)
	
	# 2. Ceiling
	_create_static_box(parent, "Ceiling", Vector3(0, ceil_y, 0), Vector3(x_width, floor_thick, z_length), ceil_mat)
	
	# 3. Outer Walls
	var half_x = x_width / 2.0
	var half_z = z_length / 2.0
	var wall_y = height / 2.0
	
	_create_static_box(parent, "Wall_West", Vector3(-half_x - thickness/2.0, wall_y, 0), Vector3(thickness, height, z_length), wall_mat)
	_create_static_box(parent, "Wall_East", Vector3(half_x + thickness/2.0, wall_y, 0), Vector3(thickness, height, z_length), wall_mat)
	_create_static_box(parent, "Wall_North", Vector3(0, wall_y, -half_z - thickness/2.0), Vector3(x_width + thickness*2, height, thickness), wall_mat)
	_create_static_box(parent, "Wall_South", Vector3(0, wall_y, half_z + thickness/2.0), Vector3(x_width + thickness*2, height, thickness), wall_mat)
	
	# 3.5 Maintenance Room
	_generate_maintenance_room(parent, f_scale, height, thickness, wall_mat)
	
	# 3.6 Elevator
	_generate_elevator(parent, f_scale, height, thickness, wall_mat)
	
	# 3.7 North Stairs
	_generate_north_stairs(parent, f_scale)
	
	# 3.7.5 South Stairs Wall
	_generate_south_stairs_wall(parent, f_scale, height, thickness, wall_mat)
	
	# 3.8 Double Room 401
	_generate_double_room_401(parent, f_scale)
	
	# 3.9 Double Room 402
	_generate_double_room_402(parent, f_scale)
	
	# 3.10 Double Room 403
	_generate_double_room_403(parent, f_scale)
	
	# 3.11 Double Room 405
	_generate_double_room_405(parent, f_scale)
	
	# 3.12 Double Room 406
	_generate_double_room_406(parent, f_scale)
	
	# 3.13 Double Room 408
	_generate_double_room_408(parent, f_scale)
	
	# 3.14 Single Room 410
	_generate_single_room_410(parent, f_scale)
	
	# 3.15 Single Room 411
	_generate_single_room_411(parent, f_scale)
	
	# 3.16 Single Room 412
	_generate_single_room_412(parent, f_scale)
	
	# 3.17 Single Room 413
	_generate_single_room_413(parent, f_scale)
	
	# 3.18 Single Room 415
	_generate_single_room_415(parent, f_scale)
	
	# 3.19 Single Room 416
	_generate_single_room_416(parent, f_scale)
	
	# 3.20 Single Room 417
	_generate_single_room_417(parent, f_scale)
	
	# 3.21 Single Room 420
	_generate_single_room_420(parent, f_scale)
	
	# 3.22 Single Room 421
	_generate_single_room_421(parent, f_scale)
	
	# 4. Light
	var light = OmniLight3D.new()
	light.name = "MainRoomLight"
	light.position = Vector3(0, height - 0.5, 0)
	light.omni_range = 50.0
	light.light_energy = 2.0
	light.light_color = Color(1.0, 0.95, 0.9)
	light.shadow_enabled = true
	add_child(light)

	# 5. Floor Map
	var map_mesh = MeshInstance3D.new()
	map_mesh.name = "FloorMap"
	var quad = QuadMesh.new()
	quad.size = Vector2(2.0, 1.5)
	
	var map_mat = StandardMaterial3D.new()
	var map_tex = load("res://assets/textures/hotel_map.jpg")
	if map_tex:
		map_mat.albedo_texture = map_tex
	else:
		map_mat.albedo_color = Color(1.0, 0.0, 0.0)
	map_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	quad.material = map_mat
	map_mesh.mesh = quad
	
	# Wall face is at X = -2.75. We place it slightly off the wall (X = -2.74) to avoid z-fighting.
	# Height 2.0m, Z = 0.0 (exactly between 403 and 405).
	map_mesh.position = Vector3(-2.74 * f_scale, 2.0 * f_scale, 0.0 * f_scale)
	# QuadMesh faces +Z. Rotate 90 degrees around Y to face +X (East).
	map_mesh.rotation.y = PI / 2.0
	parent.add_child(map_mesh)

	# 6. Talking Head Screen
	var screen_mesh = MeshInstance3D.new()
	screen_mesh.name = "TalkingHeadScreen"
	var screen_quad = QuadMesh.new()
	screen_quad.size = Vector2(2.5, 1.5)
	
	var screen_mat = StandardMaterial3D.new()
	var screen_tex = load("res://assets/textures/propaganda.jpg")
	if screen_tex:
		screen_mat.albedo_texture = screen_tex
		screen_mat.emission_enabled = true
		screen_mat.emission_texture = screen_tex
		screen_mat.emission_energy_multiplier = 1.2
	else:
		screen_mat.albedo_color = Color(0.2, 0.2, 0.8)
		screen_mat.emission_enabled = true
		screen_mat.emission = Color(0.2, 0.2, 0.8)
	screen_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	screen_quad.material = screen_mat
	screen_mesh.mesh = screen_quad
	
	# Wall face is at X = -2.75. We place it slightly off the wall (X = -2.74) to avoid z-fighting.
	# Height 2.0m, Z = -20.0 (exactly between 401 and 402).
	screen_mesh.position = Vector3(-2.74 * f_scale, 2.0 * f_scale, -20.0 * f_scale)
	# QuadMesh faces +Z. Rotate 90 degrees around Y to face +X (East).
	screen_mesh.rotation.y = PI / 2.0
	parent.add_child(screen_mesh)

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
	
	# Wall face is at X = -2.75. Slightly off to avoid z-fighting.
	# Height 2.0m, Z = 10.0 (exactly between 405 and 406).
	ad_mesh.position = Vector3(-2.74 * f_scale, 2.0 * f_scale, 10.0 * f_scale)
	ad_mesh.rotation.y = PI / 2.0
	parent.add_child(ad_mesh)

	# Call deferred to ensure nodes are physically in tree and physics updated
	call_deferred("_move_player", f_scale)

func _move_player(f_scale: float) -> void:
	var player = get_node_or_null("../../Player")
	if not player:
		# Fallback if relative path fails
		if get_tree() and get_tree().current_scene:
			player = get_tree().current_scene.get_node_or_null("Player")
	
	if player:
		# Use Y=2.0 to be absolutely sure the player's feet don't clip the floor
		var p_spawn = Vector3(0, 2.0, 0) * f_scale
		player.global_position = p_spawn
		if "velocity" in player:
			player.velocity = Vector3.ZERO
		print("Player moved to: ", p_spawn)

func _generate_maintenance_room(parent: Node, f_scale: float, height: float, thickness: float, wall_mat: Material) -> void:
	var wall_y = height / 2.0
	
	# Inner South Wall (runs along Z = -20.0, from X = 9.65 to 12.65)
	# Center X = 11.15, Size X = 3.0
	_create_static_box(parent, "Maint_Inner_South", Vector3(11.15 * f_scale, wall_y, -20.0 * f_scale), Vector3(3.0 * f_scale, height, thickness), wall_mat)
	
	# Inner West Wall (runs along X = 9.65, from Z = -30.0 to -20.0)
	# Door hole at Z from -24.0 to -22.0, up to height 2.2
	
	# Part 1: Solid North Part (Z = -30.0 to -24.0). Center Z = -27.0, Size Z = 6.0
	_create_static_box(parent, "Maint_Inner_West_North", Vector3(9.65 * f_scale, wall_y, -27.0 * f_scale), Vector3(thickness, height, 6.0 * f_scale), wall_mat)
	
	# Part 2: Solid South Part (Z = -22.0 to -20.0). Center Z = -21.0, Size Z = 2.0
	_create_static_box(parent, "Maint_Inner_West_South", Vector3(9.65 * f_scale, wall_y, -21.0 * f_scale), Vector3(thickness, height, 2.0 * f_scale), wall_mat)
	
	# Part 3: Door Lintel (Z = -24.0 to -22.0)
	var door_h = 2.2 * f_scale
	if height > door_h:
		var lintel_h = height - door_h
		var lintel_y = door_h + (lintel_h / 2.0)
		_create_static_box(parent, "Maint_Inner_West_Lintel", Vector3(9.65 * f_scale, lintel_y, -23.0 * f_scale), Vector3(thickness, lintel_h, 2.0 * f_scale), wall_mat)

func _generate_elevator(parent: Node, f_scale: float, height: float, thickness: float, wall_mat: Material) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/elevator_shaft.tscn")
	if scene:
		var inst = scene.instantiate()
		parent.add_child(inst)
		# Center X = 7.2 (shifted right by 1.9m). North wall Z = -30.0.
		inst.position = Vector3(7.2 * f_scale, 0, -30.0 * f_scale)

func _generate_north_stairs(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/north_stairs.tscn")
	if scene:
		var inst = scene.instantiate()
		parent.add_child(inst)
		# Center X = 1.05. North wall Z = -30.0.
		inst.position = Vector3(1.05 * f_scale, 0, -30.0 * f_scale)

func _generate_south_stairs_wall(parent: Node, f_scale: float, height: float, thickness: float, wall_mat: Material) -> void:
	var z_pos = 25.0 * f_scale + (thickness / 2.0)
	var door_w = 1.2 * f_scale
	var door_h = 2.2 * f_scale
	
	# Corridor spans X from -2.75 to 4.85. Center is 1.05.
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

func _generate_double_room_401(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/double_room.tscn")
	if scene:
		var inst = scene.instantiate()
		inst.name = "DoubleRoom_401"
		parent.add_child(inst)
		# Center X = -7.65. North wall Z = -30.0.
		inst.position = Vector3(-7.65 * f_scale, 0, -30.0 * f_scale)

func _generate_double_room_402(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/double_room.tscn")
	if scene:
		var inst = scene.instantiate()
		inst.name = "DoubleRoom_402"
		parent.add_child(inst)
		# Center X = -7.65. North wall Z = -20.0.
		inst.position = Vector3(-7.65 * f_scale, 0, -20.0 * f_scale)

func _generate_double_room_403(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/double_room.tscn")
	if scene:
		var inst = scene.instantiate()
		inst.name = "DoubleRoom_403"
		parent.add_child(inst)
		# Center X = -7.65. Base Z = 0.0 (Mirrored to go to -10.0)
		inst.position = Vector3(-7.65 * f_scale, 0, 0.0 * f_scale)
		inst.scale.z = -1.0

func _generate_double_room_405(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/double_room.tscn")
	if scene:
		var inst = scene.instantiate()
		inst.name = "DoubleRoom_405"
		parent.add_child(inst)
		# Center X = -7.65. North wall Z = 0.0.
		inst.position = Vector3(-7.65 * f_scale, 0, 0.0 * f_scale)

func _generate_double_room_406(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/double_room.tscn")
	if scene:
		var inst = scene.instantiate()
		inst.name = "DoubleRoom_406"
		parent.add_child(inst)
		# Center X = -7.65. North wall Z = 10.0.
		inst.position = Vector3(-7.65 * f_scale, 0, 10.0 * f_scale)

func _generate_double_room_408(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/double_room.tscn")
	if scene:
		var inst = scene.instantiate()
		inst.name = "DoubleRoom_408"
		parent.add_child(inst)
		# Center X = -7.65. Base Z = 30.0 (Mirrored to go to 20.0)
		inst.position = Vector3(-7.65 * f_scale, 0, 30.0 * f_scale)
		inst.scale.z = -1.0

func _generate_single_room_410(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/single_room.tscn")
	if scene:
		var inst = scene.instantiate()
		inst.name = "SingleRoom_410"
		parent.add_child(inst)
		# Center X = 8.7. North wall Z = -20.0.
		inst.position = Vector3(8.7 * f_scale, 0, -20.0 * f_scale)

func _generate_single_room_411(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/single_room.tscn")
	if scene:
		var inst = scene.instantiate()
		inst.name = "SingleRoom_411"
		parent.add_child(inst)
		# Center X = 8.7. Mirrored, so Base Z = -10.0
		inst.position = Vector3(8.7 * f_scale, 0, -10.0 * f_scale)
		inst.scale.z = -1.0

func _generate_single_room_412(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/single_room.tscn")
	if scene:
		var inst = scene.instantiate()
		inst.name = "SingleRoom_412"
		parent.add_child(inst)
		# Center X = 8.7. North wall Z = -10.0.
		inst.position = Vector3(8.7 * f_scale, 0, -10.0 * f_scale)

func _generate_single_room_413(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/single_room.tscn")
	if scene:
		var inst = scene.instantiate()
		inst.name = "SingleRoom_413"
		parent.add_child(inst)
		# Center X = 8.7. Mirrored, so Base Z = 0.0
		inst.position = Vector3(8.7 * f_scale, 0, 0.0 * f_scale)
		inst.scale.z = -1.0

func _generate_single_room_415(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/single_room.tscn")
	if scene:
		var inst = scene.instantiate()
		inst.name = "SingleRoom_415"
		parent.add_child(inst)
		# Center X = 8.7. North wall Z = 0.0.
		inst.position = Vector3(8.7 * f_scale, 0, 0.0 * f_scale)

func _generate_single_room_416(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/single_room.tscn")
	if scene:
		var inst = scene.instantiate()
		inst.name = "SingleRoom_416"
		parent.add_child(inst)
		# Center X = 8.7. Mirrored, so Base Z = 10.0
		inst.position = Vector3(8.7 * f_scale, 0, 10.0 * f_scale)
		inst.scale.z = -1.0

func _generate_single_room_417(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/single_room.tscn")
	if scene:
		var inst = scene.instantiate()
		inst.name = "SingleRoom_417"
		parent.add_child(inst)
		# Center X = 8.7. Mirrored, so Base Z = 15.0
		inst.position = Vector3(8.7 * f_scale, 0, 15.0 * f_scale)
		inst.scale.z = -1.0

func _generate_single_room_420(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/single_room.tscn")
	if scene:
		var inst = scene.instantiate()
		inst.name = "SingleRoom_420"
		parent.add_child(inst)
		# Center X = 8.7. North wall Z = 15.0.
		inst.position = Vector3(8.7 * f_scale, 0, 15.0 * f_scale)

func _generate_single_room_421(parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/single_room.tscn")
	if scene:
		var inst = scene.instantiate()
		inst.name = "SingleRoom_421"
		parent.add_child(inst)
		# Center X = 8.7. North wall Z = 20.0.
		inst.position = Vector3(8.7 * f_scale, 0, 20.0 * f_scale)

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
