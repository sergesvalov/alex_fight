extends Node

@export var player_height: float = 1.8
@export var floor_ceiling_height: float = 3.5

const BASE_PLAYER_HEIGHT: float = 1.8
const BASE_FLOOR_CEILING_HEIGHT: float = 3.5

func get_player_scale() -> float:
	return player_height / BASE_PLAYER_HEIGHT

func get_floor_scale() -> float:
	return floor_ceiling_height / BASE_FLOOR_CEILING_HEIGHT

func apply_dynamic_scale(root: Node3D) -> void:
	var p_scale = get_player_scale()
	var f_scale = get_floor_scale()
	
	if is_equal_approx(p_scale, 1.0) and is_equal_approx(f_scale, 1.0):
		return # No scaling needed
		
	var light_y = floor_ceiling_height - 0.75
	var queue = [root]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		for child in current.get_children():
			if not child is Node3D:
				continue
				
			queue.push_back(child)
			
			var is_prop = false
			if child.is_in_group("props"):
				is_prop = true
			else:
				var cname = child.name.to_lower()
				if ("door" in cname and not "hole" in cname) or "bed" in cname or "table" in cname or "chair" in cname or "wardrobe" in cname:
					is_prop = true
					
			if is_prop:
				child.position.x *= f_scale
				child.position.z *= f_scale
				# Keep position.y the same (0, on the floor)
				child.scale = Vector3(p_scale, p_scale, p_scale)
				queue.pop_back() # Don't descend into prop children
				continue
				
			if child is OmniLight3D:
				child.position.x *= f_scale
				child.position.z *= f_scale
				child.position.y = light_y
				continue
				
			if child is Label3D:
				child.position.x *= f_scale
				child.position.z *= f_scale
				child.position.y = floor_ceiling_height - 1.3
				continue
				
			if child is CSGBox3D:
				if child.operation == CSGBox3D.OPERATION_SUBTRACTION and "Hole" in child.name:
					child.position.x *= f_scale
					child.position.z *= f_scale
					child.size *= p_scale
					if current is Node3D:
						child.position.y = (child.size.y / 2.0) - current.position.y
				else:
					child.position *= f_scale
					child.size *= f_scale
				continue
				
			if child is OccluderInstance3D:
				child.position *= f_scale
				if child.occluder and child.occluder is BoxOccluder3D:
					child.occluder = child.occluder.duplicate()
					child.occluder.size *= f_scale
				continue
			
			if child is CollisionShape3D:
				child.position *= f_scale
				if child.shape and child.shape is BoxShape3D:
					child.shape = child.shape.duplicate()
					child.shape.size *= f_scale
				continue
				
			# Generic Node3D (like CSGCombiner3D rooms, marker points, etc.)
			# We scale their position so the grid expands!
			child.position.x *= f_scale
			child.position.z *= f_scale
			# Don't scale Y position of generic nodes to prevent floor from drifting, 
			# unless it's a specific floor offset, but normally rooms are at Y=0.
			if child.position.y > 0.1:
				child.position.y *= f_scale
