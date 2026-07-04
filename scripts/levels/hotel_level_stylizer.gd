class_name HotelLevelStylizer
extends RefCounted

static func apply_stylization(gen: Node3D) -> void:
	var orig_carpet = gen.carpet_color
	var orig_map = gen.map_texture
	var orig_ad = gen.ad_texture
	
	for floor_node in gen.get_children():
		if floor_node.name.begins_with("GeneratedFloor"):
			var f_num = gen.floor_number
			if floor_node.name.ends_with("_Above"):
				f_num += 1
			elif floor_node.name.ends_with("_Below"):
				f_num -= 1
				
			if f_num != gen.floor_number:
				_apply_external_styles(gen, f_num)
			else:
				gen.carpet_color = orig_carpet
				gen.map_texture = orig_map
				gen.ad_texture = orig_ad
				
			for node_name in ["CorridorFloor", "CorridorCeiling"]:
				if floor_node.has_node(node_name):
					var cf = floor_node.get_node(node_name)
					if cf is CSGBox3D:
						var material = StandardMaterial3D.new()
						material.albedo_texture = preload("res://assets/textures/hotel_carpet.jpg")
						material.albedo_color = gen.carpet_color
						material.uv1_scale = Vector3(10, 10, 10)
						cf.material = material
			
			for child in floor_node.get_children():
				if child is HotelRoom:
					child.carpet_color = gen.carpet_color
					
	gen.carpet_color = orig_carpet
	gen.map_texture = orig_map
	gen.ad_texture = orig_ad

static func get_external_floor(gen: Node3D, target_floor: int) -> int:
	var scene_path = "res://scenes/levels/hotel_siberia/hotel_level_" + str(target_floor) + ".tscn"
	if ResourceLoader.exists(scene_path):
		return target_floor
	return gen.floor_number

static func _apply_external_styles(gen: Node3D, target_floor: int) -> void:
	var scene_path = "res://scenes/levels/hotel_siberia/hotel_level_" + str(target_floor) + ".tscn"
	if ResourceLoader.exists(scene_path):
		var scene = load(scene_path)
		if scene:
			var instance = scene.instantiate()
			var other_gen = instance.find_child("HotelGeometry", true, false)
			if other_gen:
				gen.carpet_color = other_gen.carpet_color
				gen.map_texture = other_gen.map_texture
				gen.ad_texture = other_gen.ad_texture
			instance.free()
