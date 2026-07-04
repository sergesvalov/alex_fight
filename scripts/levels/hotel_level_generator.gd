@tool
extends Node3D
class_name HotelLevelGenerator

# region Export Variables

@export var generate: bool = false:
	set(value):
		if value:
			_generate_level()

@export_group("Rooms Count & Steps")
@export var num_double_rooms: int = 6
@export var num_single_rooms: int = 9
@export var double_room_step: float = 12.0
@export var single_room_step: float = 7.2

@export_group("Layout & Dimensions")
@export var corridor_width: float = 7.0
@export var corridor_height: float = 4.25
@export var floor_height: float = 5.0
@export var floor_thickness: float = 0.5
@export var wall_thickness: float = 1.0

@export_group("North Block Layout")
@export var side_corridor_z_start: float = 0.0
@export var side_corridor_z_end: float = 3.0
@export var side_corridor_depth: float = 5.0
@export var elev_shaft_depth: float = 5.0
@export var maint_room_depth: float = 5.0

@export_subgroup("Double Rooms Position")
@export var double_room_x: float = -8.3
@export var double_room_start_z: float = 4.0
@export var double_room_wall_len: float = 6.6

@export_subgroup("Single Rooms Position")
@export var single_room_x: float = 7.1
@export var single_room_start_z: float = -3.6
@export var single_room_wall_len: float = 2.8

@export_group("Doors & Openings")
@export var room_y_offset: float = 0.15
@export var room_door_width: float = 1.84
@export var util_door_width: float = 2.3
@export var util_door_height: float = 2.875
@export var util_door_scale: float = 1.15

@export_group("Stylization")
@export var floor_number: int = 4
@export var carpet_color: Color = Color.WHITE
@export var map_texture: Texture2D

@export_group("Room Suffixes")
@export var double_room_suffixes: Array[String] = ["01", "02", "03", "05", "06", "08"]
@export var single_room_suffixes: Array[String] = ["10", "11", "12", "13", "15", "16", "17", "20", "21"]

@export_group("Entities Spawn")
@export var player_spawn_pos: Vector3 = Vector3(0.0, 2.0, 4.0)
@export var enemies_spawn_z_offset: float = 10.0
@export var patrol_point_step: float = 20.0

# endregion

# region Preloaded Scenes

var double_room_scene = preload("res://scenes/levels/hotel_siberia/rooms/double_room.tscn")
var double_room_large_scene = preload("res://scenes/levels/hotel_siberia/rooms/double_room_large.tscn")
var single_room_scene = preload("res://scenes/levels/hotel_siberia/rooms/single_room.tscn")
var stairwell_scene = preload("res://scenes/levels/hotel_siberia/stairwell_north.tscn")
var door_scene = preload("res://entities/props/door.tscn")
var elevator_door_scene = preload("res://entities/props/elevator_door.tscn")

# endregion

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
	for floor_node in get_children():
		if floor_node.name.begins_with("GeneratedFloor"):
			if floor_node.has_node("CorridorFloor"):
				var cf = floor_node.get_node("CorridorFloor")
				if cf is CSGBox3D:
					var material = StandardMaterial3D.new()
					material.albedo_texture = preload("res://assets/textures/hotel_carpet.jpg")
					material.albedo_color = carpet_color
					material.uv1_scale = Vector3(10, 10, 10)
					cf.material = material
			
			for child in floor_node.get_children():
				if child is HotelRoom:
					child.carpet_color = carpet_color

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
		var scene_path = "res://scenes/levels/hotel_siberia/hotel_level_" + str(f_num) + ".tscn"
		if ResourceLoader.exists(scene_path):
			var scene = load(scene_path)
			if scene:
				var instance = scene.instantiate()
				var gen = instance.find_child("HotelGeometry", true, false)
				if gen:
					carpet_color = gen.carpet_color
					map_texture = gen.map_texture
				instance.free()
		else:
			f_num = floor_number
		
	_generate_floor(f_num, parent, is_main)
	
	carpet_color = orig_carpet
	map_texture = orig_map

func _generate_floor(f_num: int, parent: Node3D, is_main: bool) -> void:
	var corridor_start_z = double_room_start_z + (double_room_step / 2.0)
	var max_double_z = double_room_start_z - (num_double_rooms - 1) * double_room_step - double_room_wall_len
	var max_single_z = single_room_start_z - (num_single_rooms - 1) * single_room_step - single_room_wall_len
	var corridor_end_z = min(max_double_z, max_single_z)
	var stair_z = corridor_end_z - 10.0
	var total_corridor_end = stair_z - 1.5
	
	_generate_corridor_shell(parent, corridor_start_z, total_corridor_end)
	_generate_north_block(parent, corridor_start_z)
	_generate_south_block(parent, stair_z)
	
	_generate_double_rooms(f_num, parent, corridor_start_z, total_corridor_end)
	_generate_single_rooms(f_num, parent, 0.0, total_corridor_end)
	
	_generate_map_decals(parent)
	
	if is_main:
		_generate_entities(corridor_end_z)
		
	print("Level geometry generated for floor " + str(f_num))

# endregion

# region Corridor Shell & Rooms

func _generate_corridor_shell(parent: Node3D, corridor_start_z: float, total_corridor_end: float) -> void:
	var corridor_length = corridor_start_z - total_corridor_end
	var corridor_center_z = (corridor_start_z + total_corridor_end) / 2.0
	
	var floor_y = -floor_thickness / 2.0
	var ceil_y = corridor_height + (floor_thickness / 2.0)
	
	_create_csg_box(parent, "CorridorFloor", Vector3(0, floor_y, corridor_center_z), Vector3(35.0, floor_thickness, corridor_length), true)
	_create_csg_box(parent, "CorridorCeiling", Vector3(0, ceil_y, corridor_center_z), Vector3(35.0, floor_thickness, corridor_length), true)

func _generate_double_rooms(f_num: int, parent: Node3D, corridor_start_z: float, total_corridor_end: float) -> void:
	var prev_z_left = corridor_start_z
	var wall_x_left = -corridor_width / 2.0
	
	for i in range(num_double_rooms):
		var c_z = double_room_start_z - i * double_room_step
		var room = double_room_large_scene.instantiate() if i < 2 else double_room_scene.instantiate()
		
		room.name = "DoubleRoomL" + str(i + 1) + "_F" + str(f_num)
		room.transform.origin = Vector3(double_room_x, room_y_offset, c_z)
		parent.add_child(room)
		room.owner = get_tree().edited_scene_root
		
		if "room_number" in room:
			room.room_number = str(f_num) + double_room_suffixes[i % double_room_suffixes.size()]
		if "carpet_color" in room:
			room.carpet_color = carpet_color
			
		var door_top_z = c_z + 0.5 + 1.0
		var door_bottom_z = c_z + 0.5 - 1.0
		
		if prev_z_left > door_top_z:
			_create_wall(parent, "CorrWall_L_" + str(i), Vector3(wall_x_left, 0, (prev_z_left + door_top_z) / 2.0), prev_z_left - door_top_z)
		prev_z_left = door_bottom_z
		
	if prev_z_left > total_corridor_end:
		_create_wall(parent, "CorrWall_L_end", Vector3(wall_x_left, 0, (total_corridor_end + prev_z_left) / 2.0), prev_z_left - total_corridor_end)

func _generate_single_rooms(f_num: int, parent: Node3D, corridor_start_z: float, total_corridor_end: float) -> void:
	var prev_z_right = corridor_start_z
	var wall_x_right = corridor_width / 2.0
	
	for i in range(num_single_rooms):
		var c_z = single_room_start_z - i * single_room_step
		var room = single_room_scene.instantiate()
		
		room.name = "SingleRoomR" + str(i + 1) + "_F" + str(f_num)
		room.transform.origin = Vector3(single_room_x, room_y_offset, c_z)
		parent.add_child(room)
		room.owner = get_tree().edited_scene_root
		
		if "room_number" in room:
			room.room_number = str(f_num) + single_room_suffixes[i % single_room_suffixes.size()]
		if "carpet_color" in room:
			room.carpet_color = carpet_color
			
		var door_top_z = c_z + 0.5 + 1.0
		var door_bottom_z = c_z + 0.5 - 1.0
		
		if prev_z_right > door_top_z:
			_create_wall(parent, "CorrWall_R_" + str(i), Vector3(wall_x_right, 0, (prev_z_right + door_top_z) / 2.0), prev_z_right - door_top_z)
		prev_z_right = door_bottom_z

	if prev_z_right > total_corridor_end:
		_create_wall(parent, "CorrWall_R_end", Vector3(wall_x_right, 0, (total_corridor_end + prev_z_right) / 2.0), prev_z_right - total_corridor_end)

func _generate_map_decals(parent: Node3D) -> void:
	var map_z = double_room_start_z - (double_room_step / 2.0)
	var decal_positions = [Vector3(-2.99, 2.0, map_z), Vector3(2.99, 2.0, map_z)]
	
	for i in range(decal_positions.size()):
		var pos = decal_positions[i]
		var map_decal = MeshInstance3D.new()
		map_decal.name = "MapDecal_" + str(i + 1)
		map_decal.transform.origin = pos
		map_decal.transform.basis = Basis.from_euler(Vector3(0, PI/2 if pos.x < 0 else -PI/2, 0))
			
		var quad = QuadMesh.new()
		quad.size = Vector2(2, 2)
		var map_mat = StandardMaterial3D.new()
		map_mat.albedo_texture = map_texture if map_texture else preload("res://assets/textures/hotel_map.jpg")
		map_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		quad.material = map_mat
		map_decal.mesh = quad
		parent.add_child(map_decal)
		map_decal.owner = get_tree().edited_scene_root

# endregion

# region Block Generators

func _generate_north_block(parent: Node3D, start_z: float) -> void:
	_generate_elevator_shaft(parent)
	_generate_maintenance_room(parent)
	
	var main_wall_len = start_z - side_corridor_z_end
	if main_wall_len > 0:
		var center_z = side_corridor_z_end + (main_wall_len / 2.0)
		var center_x = corridor_width / 2.0
		_create_csg_box(parent, "MainCorrRightWall", Vector3(center_x, corridor_height / 2.0, center_z), Vector3(wall_thickness, corridor_height, main_wall_len), false, false)
		
	var stair = stairwell_scene.instantiate()
	stair.name = "Stairwell_N"
	stair.transform.basis = Basis.from_euler(Vector3(0, 0, 0))
	stair.transform.origin = Vector3(0, 0, start_z)
	parent.add_child(stair)
	stair.owner = get_tree().edited_scene_root

func _generate_south_block(parent: Node3D, stair_z: float) -> void:
	var stairwell_south_scene = load("res://scenes/levels/hotel_siberia/stairwell_south.tscn")
	if stairwell_south_scene:
		var stair_inst = stairwell_south_scene.instantiate()
		stair_inst.name = "StairwellSouth"
		stair_inst.rotation_degrees.y = 180
		stair_inst.position = Vector3(0, 0, stair_z)
		parent.add_child(stair_inst)
		stair_inst.owner = get_tree().edited_scene_root

func _generate_elevator_shaft(parent: Node3D) -> void:
	var wall_y_center = corridor_height / 2.0
	var hole_y = (util_door_height - corridor_height) / 2.0
	
	var elev_x_center = (corridor_width / 2.0) + (side_corridor_depth / 2.0)
	var elev_z_center = side_corridor_z_end + (elev_shaft_depth / 2.0)
	
	var side_north_wall = _create_csg_box(parent, "SideCorrNorthWall", Vector3(elev_x_center, wall_y_center, side_corridor_z_end), Vector3(side_corridor_depth, corridor_height, wall_thickness), false, false)
	_create_csg_hole(side_north_wall, "ElevatorDoorHole", Vector3(0, hole_y, 0), Vector3(util_door_width, util_door_height, wall_thickness + 0.4))
	
	_create_csg_box(parent, "ElevatorShaft", Vector3(elev_x_center, wall_y_center, elev_z_center), Vector3(side_corridor_depth, corridor_height, elev_shaft_depth), false, false)
	_create_csg_hole(parent, "ElevatorHole", Vector3(elev_x_center, wall_y_center, elev_z_center), Vector3(side_corridor_depth - 0.2, corridor_height, elev_shaft_depth - 0.2))
	
	var light_z = side_corridor_z_end + 0.5
	_create_light(parent, "ElevatorLight", Vector3(elev_x_center, corridor_height - 0.75, light_z), Color(0.9, 0.95, 1, 1))
	
	var elev_doors = elevator_door_scene.instantiate()
	elev_doors.name = "ElevatorDoors"
	elev_doors.transform.origin = Vector3(elev_x_center, 0.0, side_corridor_z_end)
	parent.add_child(elev_doors)
	elev_doors.owner = get_tree().edited_scene_root

func _generate_maintenance_room(parent: Node3D) -> void:
	var wall_y_center = corridor_height / 2.0
	var hole_y = (util_door_height - corridor_height) / 2.0
	
	var side_corridor_z_len = side_corridor_z_end - side_corridor_z_start
	var side_corridor_z_center = side_corridor_z_start + (side_corridor_z_len / 2.0)
	var east_wall_x = (corridor_width / 2.0) + side_corridor_depth
	
	var side_east_wall = _create_csg_box(parent, "SideCorrEastWall", Vector3(east_wall_x, wall_y_center, side_corridor_z_center), Vector3(wall_thickness, corridor_height, side_corridor_z_len), false, false)
	_create_csg_hole(side_east_wall, "MaintenanceDoorHole", Vector3(0, hole_y, 0), Vector3(wall_thickness + 0.4, util_door_height, util_door_width))
	
	var maint_x_center = east_wall_x + (maint_room_depth / 2.0)
	
	_create_csg_box(parent, "MaintenanceRoom", Vector3(maint_x_center, wall_y_center, side_corridor_z_center), Vector3(maint_room_depth, corridor_height, side_corridor_z_len), false, false)
	_create_csg_hole(parent, "MaintenanceRoomHole", Vector3(maint_x_center, wall_y_center, side_corridor_z_center), Vector3(maint_room_depth - 0.2, corridor_height, side_corridor_z_len - 0.2))
	
	_create_csg_hole(parent, "MaintenanceRoomDoorHole", Vector3(east_wall_x, wall_y_center + hole_y, side_corridor_z_center), Vector3(wall_thickness + 0.8, util_door_height, util_door_width))
	_create_light(parent, "MaintenanceLight", Vector3(maint_x_center, corridor_height - 0.75, side_corridor_z_center), Color(1.0, 0.9, 0.7, 1))
	
	var maint_door = door_scene.instantiate()
	maint_door.name = "MaintenanceDoor"
	maint_door.transform.origin = Vector3(east_wall_x, 0, side_corridor_z_center)
	maint_door.transform.basis = Basis.from_euler(Vector3(0, -PI/2, 0))
	maint_door.scale = Vector3(util_door_scale, util_door_scale, util_door_scale) 
	parent.add_child(maint_door)
	maint_door.owner = get_tree().edited_scene_root

# endregion

# region CSG Helpers

func _create_wall(parent: Node, node_name: String, pos: Vector3, length: float) -> void:
	var wall_y_center = corridor_height / 2.0
	var actual_pos = Vector3(pos.x, wall_y_center, pos.z)
	_create_csg_box(parent, node_name, actual_pos, Vector3(wall_thickness, corridor_height, length), false, false)

func _create_csg_box(parent: Node, node_name: String, pos: Vector3, size: Vector3, is_floor: bool, add_occluder: bool = true) -> CSGBox3D:
	var box = CSGBox3D.new()
	box.name = node_name
	box.transform.origin = pos
	box.size = size
	box.use_collision = true
	box.collision_layer = 2
	
	var material = StandardMaterial3D.new()
	if is_floor:
		material.albedo_texture = preload("res://assets/textures/hotel_carpet.jpg")
		material.albedo_color = carpet_color
		material.uv1_scale = Vector3(10, 10, 10)
	else:
		material.albedo_texture = preload("res://assets/textures/hotel_wallpaper.jpg")
		material.uv1_scale = Vector3(20, 2, 2)
		material.roughness = 0.9
		
	box.material = material
	parent.add_child(box)
	box.owner = get_tree().edited_scene_root
	
	if add_occluder:
		var occluder_inst = OccluderInstance3D.new()
		var occ_shape = BoxOccluder3D.new()
		occ_shape.size = Vector3(max(0.1, size.x - 0.1), size.y, max(0.1, size.z - 0.1))
		occluder_inst.occluder = occ_shape
		box.add_child(occluder_inst)
		occluder_inst.owner = get_tree().edited_scene_root

	return box

func _create_csg_hole(parent: Node, node_name: String, pos: Vector3, size: Vector3) -> CSGBox3D:
	var hole = CSGBox3D.new()
	hole.name = node_name
	hole.transform.origin = pos
	hole.size = size
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	parent.add_child(hole)
	hole.owner = get_tree().edited_scene_root
	return hole

func _create_light(parent: Node, node_name: String, pos: Vector3, color: Color) -> OmniLight3D:
	var light = OmniLight3D.new()
	light.name = node_name
	light.transform.origin = pos
	light.light_color = color
	light.omni_range = 8.0
	parent.add_child(light)
	light.owner = get_tree().edited_scene_root
	return light

# endregion

# region Utilities & Entities

func _clear_generated_nodes() -> void:
	var nodes_to_remove = []
	for child in get_children():
		if child.name.begins_with("GeneratedFloor"):
			nodes_to_remove.append(child)
			
	for child in nodes_to_remove:
		remove_child(child)
		child.queue_free()

func _generate_entities(end_z: float) -> void:
	var player = get_node_or_null("../../Player")
	if player:
		player.transform.origin = player_spawn_pos

	var enemies_node = get_node_or_null("../../Enemies")
	if enemies_node:
		var spawn_z = end_z + enemies_spawn_z_offset
		if "spawn_position" in enemies_node:
			enemies_node.spawn_position = Vector3(0, 1, spawn_z)
			
		var cerberus = enemies_node.get_node_or_null("Cerberus")
		if cerberus:
			cerberus.transform.origin = Vector3(0, 1, spawn_z)
			
		var patrol_points = enemies_node.get_node_or_null("PatrolPoints")
		if patrol_points:
			for child in patrol_points.get_children():
				patrol_points.remove_child(child)
				child.queue_free()
				
			var points_array = []
			var current_z = -patrol_point_step
			var idx = 1
			while current_z > end_z + 5.0:
				var marker = Marker3D.new()
				marker.name = "Point" + str(idx)
				marker.transform.origin = Vector3(0, 0, current_z)
				patrol_points.add_child(marker)
				marker.owner = get_tree().edited_scene_root
				points_array.append(NodePath("../PatrolPoints/" + str(marker.name)))
				current_z -= patrol_point_step
				idx += 1
				
			if points_array.size() == 0:
				var marker = Marker3D.new()
				marker.name = "Point1"
				marker.transform.origin = Vector3(0, 0, min(-5.0, end_z / 2.0))
				patrol_points.add_child(marker)
				marker.owner = get_tree().edited_scene_root
				points_array.append(NodePath("../PatrolPoints/Point1"))
				
			if cerberus and "patrol_points" in cerberus:
				cerberus.patrol_points = points_array

# endregion