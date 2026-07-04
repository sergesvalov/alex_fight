@tool
extends HotelLevelGeneratorGeometry
class_name HotelLevelGenerator

# region Initialization

func _ready() -> void:
	if not Engine.is_editor_hint():
		_generate_level()
		_apply_stylization()
		
		await get_tree().physics_frame
		await get_tree().physics_frame
		
		var nav_region = get_parent()
		if nav_region is NavigationRegion3D:
			nav_region.bake_navigation_mesh()

func _apply_stylization() -> void:
	var orig_carpet = carpet_color
	var orig_map = map_texture
	
	for floor_node in get_children():
		if floor_node.name.begins_with("GeneratedFloor"):
			var f_num = floor_number
			if floor_node.name.ends_with("_Above"):
				f_num += 1
			elif floor_node.name.ends_with("_Below"):
				f_num -= 1
				
			if f_num != floor_number:
				_apply_external_styles(f_num)
			else:
				carpet_color = orig_carpet
				map_texture = orig_map
				
			for node_name in ["CorridorFloor", "CorridorCeiling"]:
				if floor_node.has_node(node_name):
					var cf = floor_node.get_node(node_name)
					if cf is CSGBox3D:
						var material = StandardMaterial3D.new()
						material.albedo_texture = preload("res://assets/textures/hotel_carpet.jpg")
						material.albedo_color = carpet_color
						material.uv1_scale = Vector3(10, 10, 10)
						cf.material = material
			
			for child in floor_node.get_children():
				if child is HotelRoom:
					child.carpet_color = carpet_color
					
	carpet_color = orig_carpet
	map_texture = orig_map

# endregion

# region Core Generation Logic

func _generate_level() -> void:
	print("Generating hotel level geometry...")
	_clear_generated_nodes()
	
	_create_floor_group("GeneratedFloor_Main", 0.0, true)
	_create_floor_group("GeneratedFloor_Above", floor_height, false)
	_create_floor_group("GeneratedFloor_Below", -floor_height, false)

func _create_floor_group(name: String, y_pos: float, is_main: bool) -> void:
	var parent = CSGCombiner3D.new()
	parent.name = name
	parent.transform.origin.y = y_pos
	parent.use_collision = true
	parent.collision_layer = 2
	add_child(parent)
	parent.owner = get_tree().edited_scene_root
	
	var f_num = floor_number
	if name.ends_with("_Above"):
		f_num += 1
	elif name.ends_with("_Below"):
		f_num -= 1
		
	var orig_carpet = carpet_color
	var orig_map = map_texture
		
	if not is_main:
		f_num = _apply_external_styles(f_num)
		
	_generate_floor(f_num, parent, is_main)
	
	carpet_color = orig_carpet
	map_texture = orig_map

func _apply_external_styles(target_floor: int) -> int:
	var scene_path = "res://scenes/levels/hotel_siberia/hotel_level_" + str(target_floor) + ".tscn"
	if ResourceLoader.exists(scene_path):
		var scene = load(scene_path)
		if scene:
			var instance = scene.instantiate()
			var gen = instance.find_child("HotelGeometry", true, false)
			if gen:
				carpet_color = gen.carpet_color
				map_texture = gen.map_texture
			instance.free()
			return target_floor
	return floor_number

func _generate_floor(f_num: int, parent: Node3D, is_main: bool) -> void:
	var corridor_start_z = double_room_start_z + (double_room_step / 2.0)
	var max_double_z = double_room_start_z - (num_double_rooms - 1) * double_room_step - double_room_wall_len
	var max_single_z = single_room_start_z - (num_single_rooms - 1) * single_room_step - single_room_wall_len
	var corridor_end_z = min(max_double_z, max_single_z)
	var stair_z = corridor_end_z - stairwell_south_offset
	var total_corridor_end = stair_z - total_corridor_end_margin
	
	_generate_corridor_shell(parent, corridor_start_z, total_corridor_end)
	_generate_north_block(parent, corridor_start_z)
	_generate_south_block(parent, stair_z)
	
	_generate_rooms_side(f_num, parent, true, corridor_start_z, total_corridor_end)
	_generate_rooms_side(f_num, parent, false, corridor_start_z, total_corridor_end)
	
	_generate_map_decals(parent)
	
	if is_main:
		_generate_entities(corridor_end_z)
		
	print("Level geometry generated for floor " + str(f_num))

# endregion

# region Entities

func _generate_entities(end_z: float) -> void:
	_spawn_player()
	_spawn_enemies(end_z)

func _spawn_player() -> void:
	var player = get_node_or_null("../../Player")
	if player:
		player.transform.origin = player_spawn_pos

func _spawn_enemies(end_z: float) -> void:
	var enemies_node = get_node_or_null("../../Enemies")
	if not enemies_node:
		return
		
	var spawn_z = end_z + enemies_spawn_z_offset
	if "spawn_position" in enemies_node:
		enemies_node.spawn_position = Vector3(0, 1, spawn_z)
		
	var cerberus = enemies_node.get_node_or_null("Cerberus")
	if cerberus:
		cerberus.transform.origin = Vector3(0, 1, spawn_z)
		
	var patrol_points = enemies_node.get_node_or_null("PatrolPoints")
	if patrol_points:
		var points_array = _generate_patrol_points(end_z, patrol_points)
		if cerberus and "patrol_points" in cerberus:
			cerberus.patrol_points = points_array

func _generate_patrol_points(end_z: float, patrol_points_node: Node) -> Array:
	for child in patrol_points_node.get_children():
		patrol_points_node.remove_child(child)
		child.queue_free()
		
	var points_array = []
	var current_z = -patrol_point_step
	var idx = 1
	
	while current_z > end_z + patrol_end_margin:
		var marker = Marker3D.new()
		marker.name = "Point" + str(idx)
		marker.transform.origin = Vector3(0, 0, current_z)
		patrol_points_node.add_child(marker)
		marker.owner = get_tree().edited_scene_root
		points_array.append(NodePath("../PatrolPoints/" + str(marker.name)))
		
		current_z -= patrol_point_step
		idx += 1
		
	if points_array.size() == 0:
		var marker = Marker3D.new()
		marker.name = "Point1"
		marker.transform.origin = Vector3(0, 0, min(patrol_fallback_z, end_z / 2.0))
		patrol_points_node.add_child(marker)
		marker.owner = get_tree().edited_scene_root
		points_array.append(NodePath("../PatrolPoints/Point1"))
		
	return points_array

# endregion