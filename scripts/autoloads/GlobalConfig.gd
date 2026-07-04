extends Node

# Configuration for room furniture positioning to keep them relative to walls when scaling
var room_layouts = {
	"SingleRoom": {
		"bounds": Vector3(7.0, 3.5, 6.0),
		"bounds_pos_x": 2.9,
		"bounds_neg_x": -2.75,
		"bounds_pos_z": 2.4,
		"bounds_neg_z": -2.4,
		"props": {
			"Bed": {"pos": Vector3(2.0, 0.0, 2.0), "anchor_x": 1, "anchor_z": 1},
			"Table": {"pos": Vector3(2.0, 0.0, -2.5), "anchor_x": 1, "anchor_z": -1},
			"Chair1": {"pos": Vector3(2.0, 0.0, -1.8), "anchor_x": 1, "anchor_z": -1},
			"RoomLabel": {"pos": Vector3(-2.8, 2.2, 0.5), "anchor_x": 0, "anchor_z": 0}
		}
	},
	"DoubleRoom": {
		"bounds": Vector3(8.9, 3.5, 10.0),
		"bounds_pos_x": 4.0,
		"bounds_neg_x": -3.15,
		"bounds_pos_z": 4.4,
		"bounds_neg_z": -4.4,
		"props": {
			"Bed1": {"pos": Vector3(-2.5, 0.0, -2.0), "anchor_x": -1, "anchor_z": 0},
			"Bed2": {"pos": Vector3(-2.5, 0.0, 2.0), "anchor_x": -1, "anchor_z": 0},
			"Table1": {"pos": Vector3(-1.5, 0.0, 4.5), "anchor_x": 0, "anchor_z": 1},
			"Chair1": {"pos": Vector3(-1.5, 0.0, 3.7), "anchor_x": 0, "anchor_z": 1},
			"Table2": {"pos": Vector3(0.5, 0.0, 4.5), "anchor_x": 0, "anchor_z": 1},
			"Chair2": {"pos": Vector3(0.5, 0.0, 3.7), "anchor_x": 0, "anchor_z": 1},
			"Wardrobe": {"pos": Vector3(2.5, 0.0, 4.5), "anchor_x": 1, "anchor_z": 1},
			"RoomLabel": {"pos": Vector3(4.56, 2.2, 0.6), "anchor_x": 0, "anchor_z": 0}
		}
	}
}

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
				var new_pos = child.position
				var r_type = ""
				if root.name.begins_with("SingleRoom"):
					r_type = "SingleRoom"
				elif root.name.begins_with("DoubleRoom"):
					r_type = "DoubleRoom"
					
				var handled_by_anchor = false
				if r_type != "" and room_layouts.has(r_type):
					var props = room_layouts[r_type]["props"]
					var bounds = room_layouts[r_type]["bounds"]
					var cname = child.name
					if props.has(cname):
						var layout = props[cname]
						var orig_pos = layout["pos"]
						var ax = layout["anchor_x"]
						var az = layout["anchor_z"]
						
						var bound_pos_x = bounds.x / 2.0
						var bound_neg_x = -bounds.x / 2.0
						if room_layouts[r_type].has("bounds_pos_x"):
							bound_pos_x = room_layouts[r_type]["bounds_pos_x"]
						if room_layouts[r_type].has("bounds_neg_x"):
							bound_neg_x = room_layouts[r_type]["bounds_neg_x"]
							
						# X Axis anchor
						if ax == 1:
							var orig_dist = bound_pos_x - orig_pos.x
							new_pos.x = bound_pos_x * f_scale - orig_dist * p_scale
						elif ax == -1:
							var orig_dist = orig_pos.x - bound_neg_x
							new_pos.x = bound_neg_x * f_scale + orig_dist * p_scale
						else:
							new_pos.x = orig_pos.x * f_scale
							
						var bound_pos_z = bounds.z / 2.0
						var bound_neg_z = -bounds.z / 2.0
						if room_layouts[r_type].has("bounds_pos_z"):
							bound_pos_z = room_layouts[r_type]["bounds_pos_z"]
						if room_layouts[r_type].has("bounds_neg_z"):
							bound_neg_z = room_layouts[r_type]["bounds_neg_z"]
							
						# Z Axis anchor
						if az == 1:
							var orig_dist = bound_pos_z - orig_pos.z
							new_pos.z = bound_pos_z * f_scale - orig_dist * p_scale
						elif az == -1:
							var orig_dist = orig_pos.z - bound_neg_z
							new_pos.z = bound_neg_z * f_scale + orig_dist * p_scale
						else:
							new_pos.z = orig_pos.z * f_scale
							
						handled_by_anchor = true
				
				if not handled_by_anchor:
					new_pos.x *= f_scale
					new_pos.z *= f_scale
					
				child.position = new_pos
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
