extends Node

# Configuration for room furniture positioning to keep them relative to walls when scaling
var room_layouts = {
	"SingleRoom": {
		"bounds": Vector3(7.0, 3.5, 6.0),
		"props": {
			"MainDoor": {"pos": Vector3(-3.0, 0.0, -0.25), "anchor_x": 0, "anchor_z": 0},
			"WCDoor": {"pos": Vector3(-2.2, 0.0, -0.25), "anchor_x": 0, "anchor_z": 0},
			"Bed": {"pos": Vector3(2.0, 0.0, 2.0), "anchor_x": 1, "anchor_z": 1},
			"Table": {"pos": Vector3(2.0, 0.0, -2.5), "anchor_x": 1, "anchor_z": -1},
			"Chair1": {"pos": Vector3(2.0, 0.0, -1.8), "anchor_x": 1, "anchor_z": -1},
			"RoomLabel": {"pos": Vector3(-3.0, 2.2, 0.5), "anchor_x": 0, "anchor_z": 0}
		}
	},
	"DoubleRoom": {
		"bounds": Vector3(8.9, 3.5, 10.0),
		"props": {
			"MainDoor": {"pos": Vector3(4.25, 0.0, 0.5), "anchor_x": 0, "anchor_z": 0},
			"WCDoor": {"pos": Vector3(1.55, 0.0, -3.6), "anchor_x": 0, "anchor_z": 0},
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
						
						# X Axis anchor
						if ax == 1:
							var orig_dist = (bounds.x / 2.0) - orig_pos.x
							new_pos.x = (bounds.x / 2.0) * f_scale - orig_dist * p_scale
						elif ax == -1:
							var orig_dist = orig_pos.x - (-(bounds.x / 2.0))
							new_pos.x = -(bounds.x / 2.0) * f_scale + orig_dist * p_scale
						else:
							new_pos.x = orig_pos.x * f_scale
							
						# Z Axis anchor
						if az == 1:
							var orig_dist = (bounds.z / 2.0) - orig_pos.z
							new_pos.z = (bounds.z / 2.0) * f_scale - orig_dist * p_scale
						elif az == -1:
							var orig_dist = orig_pos.z - (-(bounds.z / 2.0))
							new_pos.z = -(bounds.z / 2.0) * f_scale + orig_dist * p_scale
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
