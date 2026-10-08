# scripts/levels/csg_baker.gd
# Every room, stairwell, elevator shaft and piece of furniture in the hotel is authored as CSG,
# and the generator stamps out ten floors of them - roughly 1500 CSG trees, each of which the
# engine would otherwise boolean-compute on its own in the first frame even though there are
# only about a dozen distinct shapes among them. That was about half of the level's load time.
#
# This computes each distinct shape once and swaps every instance's CSG tree for a plain
# MeshInstance3D + StaticBody3D sharing that one result. The .tscn files stay CSG, so they are
# still edited the same way - only the nodes the running game ends up with change.
#
# No class_name - hotel_level_generator.gd preloads this file instead, so it works straight
# after a checkout without the editor having rebuilt its global class cache first.
extends RefCounted

# "<scene file>::<path to the CSG root inside it>" -> {"mesh": ArrayMesh, "shape": Shape3D}
static var _cache: Dictionary = {}

# `inst` is a freshly instantiated scene that is NOT in the tree yet. `tree_host` is any node
# that is - a shape seen for the first time has to sit in the tree for a moment to be computed.
static func bake(inst: Node, tree_host: Node) -> void:
	var roots: Array = []
	_find_root_shapes(inst, roots)
	for csg in roots:
		# A scripted CSG node is somebody's logic, not just geometry - leave it alone.
		if csg.get_script() != null:
			continue
		var key: String = _key_for(csg, inst)
		if not _cache.has(key):
			_cache[key] = _compute(csg, tree_host)
		var baked: Dictionary = _cache[key]
		if baked.is_empty():
			continue # nothing came out of it (see _compute) - keep the live CSG node
		_replace(csg, baked)

static func _find_root_shapes(node: Node, out: Array) -> void:
	if node is CSGShape3D:
		out.append(node) # its CSG children are part of this one tree, not roots of their own
		return
	for child in node.get_children():
		_find_root_shapes(child, out)

static func _key_for(csg: Node, inst: Node) -> String:
	if csg.scene_file_path != "":
		return csg.scene_file_path # the CSG node IS a scene's root (bed.tscn, table.tscn, ...)
	var scene_root: Node = csg.owner if csg.owner != null else inst
	return scene_root.scene_file_path + "::" + str(scene_root.get_path_to(csg))

static func _compute(csg: CSGShape3D, tree_host: Node) -> Dictionary:
	# A throwaway copy holding only the CSG nodes - anything else under it (the elevator panel's
	# buttons, for one) has scripts that must not run from a temporary node.
	var probe: CSGShape3D = csg.duplicate()
	_strip_non_csg(probe)
	probe.transform = Transform3D.IDENTITY
	tree_host.add_child(probe)
	probe._update_shape()
	var meshes: Array = probe.get_meshes()
	var mesh: ArrayMesh = meshes[1] as ArrayMesh if meshes.size() >= 2 else null
	var result: Dictionary = {}
	if mesh != null and mesh.get_surface_count() > 0:
		result = {"mesh": mesh, "shape": mesh.create_trimesh_shape()}
	tree_host.remove_child(probe)
	probe.free()
	return result

static func _strip_non_csg(node: Node) -> void:
	for child in node.get_children():
		if child is CSGShape3D:
			_strip_non_csg(child)
		else:
			node.remove_child(child)
			child.free()

static func _replace(csg: CSGShape3D, baked: Dictionary) -> void:
	var parent: Node = csg.get_parent()
	if parent == null:
		return # csg is the instance's own root - the caller can't have its root swapped out

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = csg.name
	mesh_inst.transform = csg.transform
	mesh_inst.visible = csg.visible
	mesh_inst.layers = csg.layers
	mesh_inst.mesh = baked["mesh"]
	for group in csg.get_groups():
		mesh_inst.add_to_group(group)

	if csg.use_collision and baked["shape"] != null:
		var body := StaticBody3D.new()
		body.name = "BakedCollision"
		body.collision_layer = csg.collision_layer
		body.collision_mask = csg.collision_mask
		var coll := CollisionShape3D.new()
		coll.shape = baked["shape"]
		body.add_child(coll)
		mesh_inst.add_child(body)

	# Whatever hangs off the CSG node that isn't itself CSG (the elevator panel's buttons and
	# display) has to keep living at the same path.
	for child in csg.get_children():
		if not child is CSGShape3D:
			csg.remove_child(child)
			child.owner = null # its owner was the scene root, which the new parent isn't under yet
			mesh_inst.add_child(child)

	var index: int = csg.get_index()
	parent.remove_child(csg)
	csg.free()
	parent.add_child(mesh_inst)
	parent.move_child(mesh_inst, index)
