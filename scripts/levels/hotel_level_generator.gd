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
	var x_width = 21.5 * f_scale
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
	
	# 4. Light
	var light = OmniLight3D.new()
	light.name = "MainRoomLight"
	light.position = Vector3(0, height - 0.5, 0)
	light.omni_range = 50.0
	light.light_energy = 2.0
	light.light_color = Color(1.0, 0.95, 0.9)
	light.shadow_enabled = true
	add_child(light)

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
	
	# Inner South Wall (runs along Z = -20.0, from X = 7.75 to 10.75)
	# Center X = 9.25, Size X = 3.0
	_create_static_box(parent, "Maint_Inner_South", Vector3(9.25 * f_scale, wall_y, -20.0 * f_scale), Vector3(3.0 * f_scale, height, thickness), wall_mat)
	
	# Inner West Wall (runs along X = 7.75, from Z = -30.0 to -20.0)
	# Door hole at Z from -24.0 to -22.0, up to height 2.2
	
	# Part 1: Solid North Part (Z = -30.0 to -24.0). Center Z = -27.0, Size Z = 6.0
	_create_static_box(parent, "Maint_Inner_West_North", Vector3(7.75 * f_scale, wall_y, -27.0 * f_scale), Vector3(thickness, height, 6.0 * f_scale), wall_mat)
	
	# Part 2: Solid South Part (Z = -22.0 to -20.0). Center Z = -21.0, Size Z = 2.0
	_create_static_box(parent, "Maint_Inner_West_South", Vector3(7.75 * f_scale, wall_y, -21.0 * f_scale), Vector3(thickness, height, 2.0 * f_scale), wall_mat)
	
	# Part 3: Door Lintel (Z = -24.0 to -22.0)
	var door_h = 2.2 * f_scale
	if height > door_h:
		var lintel_h = height - door_h
		var lintel_y = door_h + (lintel_h / 2.0)
		_create_static_box(parent, "Maint_Inner_West_Lintel", Vector3(7.75 * f_scale, lintel_y, -23.0 * f_scale), Vector3(thickness, lintel_h, 2.0 * f_scale), wall_mat)

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
