class_name HotelLevelEntitySpawner
extends RefCounted

static func generate_entities(gen: Node3D, end_z: float) -> void:
	_spawn_player(gen)
	_spawn_enemies(gen, end_z)

static func _spawn_player(gen: Node3D) -> void:
	var player = gen.get_node_or_null("../../Player")
	if player:
		player.transform.origin = gen.player_spawn_pos

static func _spawn_enemies(gen: Node3D, end_z: float) -> void:
	var enemies_node = gen.get_node_or_null("../../Enemies")
	if not enemies_node:
		return
		
	var spawn_z = end_z + gen.enemies_spawn_z_offset
	if "spawn_position" in enemies_node:
		enemies_node.spawn_position = Vector3(0, 1, spawn_z)
		
	var cerberus = enemies_node.get_node_or_null("Cerberus")
	if cerberus:
		cerberus.transform.origin = Vector3(0, 1, spawn_z)
		
	var patrol_points = enemies_node.get_node_or_null("PatrolPoints")
	if patrol_points:
		var points_array = _generate_patrol_points(gen, end_z, patrol_points)
		if cerberus and "patrol_points" in cerberus:
			cerberus.patrol_points = points_array

static func _generate_patrol_points(gen: Node3D, end_z: float, patrol_points_node: Node) -> Array:
	for child in patrol_points_node.get_children():
		patrol_points_node.remove_child(child)
		child.queue_free()
		
	var points_array = []
	var current_z = -gen.patrol_point_step
	var idx = 1
	
	while current_z > end_z + gen.patrol_end_margin:
		var marker = Marker3D.new()
		marker.name = "Point" + str(idx)
		marker.transform.origin = Vector3(0, 0, current_z)
		patrol_points_node.add_child(marker)
		marker.owner = gen.get_tree().edited_scene_root
		points_array.append(NodePath("../PatrolPoints/" + str(marker.name)))
		
		current_z -= gen.patrol_point_step
		idx += 1
		
	if points_array.size() == 0:
		var marker = Marker3D.new()
		marker.name = "Point1"
		marker.transform.origin = Vector3(0, 0, min(gen.patrol_fallback_z, end_z / 2.0))
		patrol_points_node.add_child(marker)
		marker.owner = gen.get_tree().edited_scene_root
		points_array.append(NodePath("../PatrolPoints/Point1"))
		
	return points_array
