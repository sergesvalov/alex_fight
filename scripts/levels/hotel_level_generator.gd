@tool
extends Node3D
class_name HotelLevelGenerator

@export var floor_number: int = 4
@export var player_spawn_pos: Vector3 = Vector3(0, 1.0, 0)
@export var floor_thickness: float = 0.5
@export var corridor_height: float = 3.0
@export var wall_thickness: float = 0.2

var carpet_texture = preload("res://assets/textures/hotel_carpet.jpg")
var wall_texture = preload("res://assets/textures/hotel_wallpaper.jpg")
var ceiling_texture = preload("res://assets/textures/hotel_ceiling.jpg")

func _ready() -> void:
	if not Engine.is_editor_hint():
		_generate_level()
		
		# Allow physics to settle before spawning/navmesh (matching old logic)
		await get_tree().physics_frame
		await get_tree().physics_frame
		
		var nav_region = get_parent()
		if nav_region is NavigationRegion3D:
			nav_region.bake_navigation_mesh()

func _generate_level() -> void:
	print("Generating SIMPLE hotel level geometry...")
	
	# Clean up any previously generated nodes in editor
	for child in get_children():
		child.queue_free()
		
	var parent = CSGCombiner3D.new()
	parent.name = "GeneratedFloor_Main"
	parent.use_collision = true
	parent.collision_layer = 2
	add_child(parent)
	if Engine.is_editor_hint():
		parent.owner = get_tree().edited_scene_root
		
	var f_scale = GlobalConfig.get_floor_scale()
	
	# Dimensions based on 5-meter modular grid and AGENTS.md
	# Z length = 60.0m (from -30 to 30)
	var z_length = 60.0 * f_scale
	# X width = 21.5m (from -10.75 to 10.75 based on old generator)
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
	_create_box(parent, "Floor", Vector3(0, floor_y, 0), Vector3(x_width, floor_thick, z_length), floor_mat)
	
	# 2. Ceiling
	_create_box(parent, "Ceiling", Vector3(0, ceil_y, 0), Vector3(x_width, floor_thick, z_length), ceil_mat)
	
	# 3. Outer Walls
	var half_x = x_width / 2.0
	var half_z = z_length / 2.0
	var wall_y = height / 2.0
	
	_create_box(parent, "Wall_West", Vector3(-half_x - thickness/2.0, wall_y, 0), Vector3(thickness, height, z_length), wall_mat)
	_create_box(parent, "Wall_East", Vector3(half_x + thickness/2.0, wall_y, 0), Vector3(thickness, height, z_length), wall_mat)
	_create_box(parent, "Wall_North", Vector3(0, wall_y, -half_z - thickness/2.0), Vector3(x_width + thickness*2, height, thickness), wall_mat)
	_create_box(parent, "Wall_South", Vector3(0, wall_y, half_z + thickness/2.0), Vector3(x_width + thickness*2, height, thickness), wall_mat)
	
	# 4. Light
	var light = OmniLight3D.new()
	light.name = "MainRoomLight"
	light.position = Vector3(0, height - 0.5, 0)
	light.omni_range = 50.0
	light.light_energy = 2.0
	light.light_color = Color(1.0, 0.95, 0.9)
	light.shadow_enabled = true
	add_child(light)
	if Engine.is_editor_hint():
		light.owner = get_tree().edited_scene_root
		
	# 5. Spawn Player in Center
	var player = get_node_or_null("../../Player")
	if player:
		# player_spawn_pos should be scaled by f_scale
		var p_spawn = player_spawn_pos * f_scale
		player.transform.origin = p_spawn
		print("Player spawned at: ", p_spawn)

func _create_box(parent: Node, node_name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var box = CSGBox3D.new()
	box.name = node_name
	box.position = pos
	box.size = size
	box.material = mat
	parent.add_child(box)
	if Engine.is_editor_hint():
		box.owner = get_tree().edited_scene_root