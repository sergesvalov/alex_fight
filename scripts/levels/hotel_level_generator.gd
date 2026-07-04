@tool
extends HotelLevelGeneratorGeometry
class_name HotelLevelGenerator

# region Initialization

func _ready() -> void:
	if not Engine.is_editor_hint():
		var f_scale = GlobalConfig.get_floor_scale()
		var p_scale = GlobalConfig.get_player_scale()
		
		double_room_step *= f_scale
		single_room_step *= f_scale
		corridor_width *= f_scale
		corridor_height *= f_scale
		wall_thickness *= f_scale
		floor_height *= f_scale
		stairwell_south_offset *= f_scale
		total_corridor_end_margin *= f_scale
		side_corridor_z_start *= f_scale
		side_corridor_z_end *= f_scale
		side_corridor_depth *= f_scale
		elev_shaft_depth *= f_scale
		maint_room_depth *= f_scale
		double_room_x *= f_scale
		double_room_start_z *= f_scale
		double_room_wall_len *= f_scale
		single_room_x *= f_scale
		single_room_start_z *= f_scale
		single_room_wall_len *= f_scale
		room_door_z_offset *= f_scale
		
		# Door and hole variables strictly follow player height
		room_door_width *= p_scale
		room_door_opening_width *= p_scale
		util_door_width *= p_scale
		util_door_height *= p_scale
		door_hole_width_margin *= p_scale
		maint_door_hole_width_margin *= p_scale
		room_hole_margin *= p_scale
		
		player_spawn_pos *= f_scale
		enemies_spawn_z_offset *= f_scale
		patrol_point_step *= f_scale
		patrol_end_margin *= f_scale
		patrol_fallback_z *= f_scale
		
		_generate_level()
		_apply_stylization()
		
		await get_tree().physics_frame
		await get_tree().physics_frame
		
		var nav_region = get_parent()
		if nav_region is NavigationRegion3D:
			nav_region.bake_navigation_mesh()

func _apply_stylization() -> void:
	HotelLevelStylizer.apply_stylization(self)

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
	var orig_ad = ad_texture
		
	if not is_main:
		f_num = HotelLevelStylizer.get_external_floor(self, f_num)
		HotelLevelStylizer._apply_external_styles(self, f_num)
		
	_generate_floor(f_num, parent, is_main)
	
	carpet_color = orig_carpet
	map_texture = orig_map
	ad_texture = orig_ad

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
	_generate_corridor_lights(parent, corridor_start_z, total_corridor_end, f_num)
	
	if is_main:
		HotelLevelEntitySpawner.generate_entities(self, total_corridor_end)
		
	print("Level geometry generated for floor " + str(f_num))

# endregion