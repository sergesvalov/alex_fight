@tool
extends Node3D
class_name HotelLevelGeneratorBase

# region Export Variables

@export var generate: bool = false:
	set(value):
		if value:
			_generate_level()

@export_group("Rooms Count & Steps")
@export var num_double_rooms: int = 6
@export var num_single_rooms: int = 9
@export var double_room_step: float = 10.0
@export var single_room_step: float = 6.0

@export_group("Layout & Dimensions")
@export var corridor_width: float = 6.0
@export var corridor_height: float = 3.5
@export var floor_height: float = 4.0
@export var floor_thickness: float = 0.5
@export var wall_thickness: float = 0.6
@export var stairwell_south_offset: float = 2.0
@export var total_corridor_end_margin: float = 1.5

@export_group("North Block Layout")
@export var side_corridor_z_start: float = 4.0
@export var side_corridor_z_end: float = 10.0
@export var side_corridor_depth: float = 5.0
@export var elev_shaft_depth: float = 5.0
@export var maint_room_depth: float = 5.0
@export var north_block_light_y_offset: float = 0.75
@export var elev_light_z_offset: float = 0.5

@export_subgroup("Double Rooms Position")
@export var double_room_x: float = -7.0
@export var double_room_start_z: float = 5.0
@export var double_room_wall_len: float = 5.0

@export_subgroup("Single Rooms Position")
@export var single_room_x: float = 5.75
@export var single_room_start_z: float = 1.0
@export var single_room_wall_len: float = 3.0

@export_group("Doors & Openings")
@export var room_y_offset: float = 0.0
@export var room_door_width: float = 1.0
@export var room_door_height: float = 2.2
@export var room_door_z_offset: float = 0.5
@export var room_door_opening_width: float = 1.0
@export var util_door_width: float = 1.4
@export var util_door_height: float = 2.2
@export var util_door_scale: float = 1.15
@export var door_hole_width_margin: float = 0.4
@export var maint_door_hole_width_margin: float = 0.8
@export var room_hole_margin: float = 0.2

@export_group("Map & Ad Decals")
@export var map_decal_size: Vector2 = Vector2(2.0, 2.0)
@export var map_decal_y_pos: float = 2.0
@export var map_decal_wall_offset: float = 0.01

@export_group("Textures")
@export var floor_number: int = 4
@export var carpet_color: Color = Color.WHITE
@export var map_texture: Texture2D
@export var ad_texture: Texture2D
@export var light_omni_range: float = 8.0

@export_group("Room Suffixes")
@export var double_room_suffixes: Array[String] = ["01", "02", "03", "05", "06", "08"]
@export var single_room_suffixes: Array[String] = ["10", "11", "12", "13", "15", "16", "17", "20", "21"]

@export_group("Entities Spawn")
@export var player_spawn_pos: Vector3 = Vector3(0.0, 2.0, 4.0)
@export var enemies_spawn_z_offset: float = 10.0
@export var patrol_point_step: float = 20.0
@export var patrol_end_margin: float = 5.0
@export var patrol_fallback_z: float = -5.0

# endregion

# region Preloaded Scenes

var double_room_scene = preload("res://scenes/levels/hotel_siberia/rooms/double_room.tscn")
var double_room_large_scene = preload("res://scenes/levels/hotel_siberia/rooms/double_room_large.tscn")
var single_room_scene = preload("res://scenes/levels/hotel_siberia/rooms/single_room.tscn")
var stairwell_scene = preload("res://scenes/levels/hotel_siberia/stairwell_north.tscn")
var elevator_shaft_scene = preload("res://scenes/levels/hotel_siberia/blocks/elevator_shaft.tscn")
var maintenance_room_scene = preload("res://scenes/levels/hotel_siberia/blocks/maintenance_room.tscn")

# endregion

# region Virtual Methods

func _generate_level() -> void:
	pass

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
	light.omni_range = light_omni_range
	parent.add_child(light)
	light.owner = get_tree().edited_scene_root
	return light

# endregion

# region Utilities

func _clear_generated_nodes() -> void:
	var nodes_to_remove = []
	for child in get_children():
		if child.name.begins_with("GeneratedFloor"):
			nodes_to_remove.append(child)
			
	for child in nodes_to_remove:
		remove_child(child)
		child.queue_free()

# endregion
