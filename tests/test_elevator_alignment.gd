extends Node

# Updated 2026-08-24 for the two-panel door (sliding_door_pair.gd) - checks BOTH panels
# against the hole instead of one "AnimatableBody3D/MeshInstance3D", since the old single-panel
# layout this replaced no longer exists (see elevator_door.tscn's own history).
func _ready() -> void:
	print("--- ELEVATOR DOOR ALIGNMENT TEST ---")

	var shaft = load("res://scenes/levels/hotel_siberia/blocks/elevator_shaft.tscn").instantiate()
	var door = load("res://entities/props/elevator_door.tscn").instantiate()

	# Simulate generator logic
	shaft.add_child(door)
	door.position = Vector3(0, 0, 0.1)

	var hole = shaft.get_node("ElevatorGeometry/ElevatorDoorHole")
	var hole_pos = hole.position # Local to ElevatorGeometry
	var hole_size = hole.size

	var hole_left = hole_pos.x - hole_size.x / 2
	var hole_right = hole_pos.x + hole_size.x / 2
	var hole_bottom = hole_pos.y - hole_size.y / 2
	var hole_top = hole_pos.y + hole_size.y / 2

	print("HOLE: pos = ", hole_pos, " size = ", hole_size)
	print("HOLE BOUNDS (X): ", hole_left, " to ", hole_right)
	print("HOLE BOUNDS (Y): ", hole_bottom, " to ", hole_top)

	var pair = door.get_node("AnimatableBody3D")
	var panels = {"LEFT": pair.get_node("LeftPanel"), "RIGHT": pair.get_node("RightPanel")}
	var bounds := {}

	for panel_name in panels:
		var panel: Node3D = panels[panel_name]
		var mesh_inst: MeshInstance3D = panel.get_node("MeshInstance3D")

		var world_x = door.position.x + panel.position.x + mesh_inst.position.x
		var world_y = door.position.y + panel.position.y + mesh_inst.position.y

		var w = mesh_inst.mesh.size.x
		var h = mesh_inst.mesh.size.y

		var b = {
			"left": world_x - w / 2, "right": world_x + w / 2,
			"bottom": world_y - h / 2, "top": world_y + h / 2,
		}
		bounds[panel_name] = b
		print(panel_name, " PANEL WORLD: pos = (", world_x, ", ", world_y,
			") size = (", w, ", ", h, ")")
		print(panel_name, " BOUNDS (X): ", b["left"], " to ", b["right"])
		print(panel_name, " BOUNDS (Y): ", b["bottom"], " to ", b["top"])

	# Combined footprint (both panels closed) must fully cover the hole, with no gap.
	var combined_left = min(bounds["LEFT"]["left"], bounds["RIGHT"]["left"])
	var combined_right = max(bounds["LEFT"]["right"], bounds["RIGHT"]["right"])
	var covers_hole = combined_left <= hole_left and combined_right >= hole_right \
		and bounds["LEFT"]["bottom"] <= hole_bottom and bounds["LEFT"]["top"] >= hole_top \
		and bounds["RIGHT"]["bottom"] <= hole_bottom and bounds["RIGHT"]["top"] >= hole_top
	# Panels must not overlap the car's own side walls (X = +-2.25, half-thickness 0.1) when open -
	# same "vanished behind the hotel wall" failure this whole redesign exists to avoid.
	var west_wall = shaft.get_node("ElevatorGeometry/ElevatorWestWall")
	var east_wall = shaft.get_node("ElevatorGeometry/ElevatorEastWall")
	var west_inner = west_wall.position.x + west_wall.size.x / 2
	var east_inner = east_wall.position.x - east_wall.size.x / 2

	# The panel's FAR edge (away from center, toward its own side wall) is the one at risk of
	# punching through when open - the near edge just retreats toward center and is never in
	# danger, so it's the far edge that actually has to be checked here.
	var pair_script: SlidingDoorPair = pair
	var open_offset_x = pair_script.open_offset.x
	var left_open_far_edge = bounds["LEFT"]["left"] - open_offset_x
	var right_open_far_edge = bounds["RIGHT"]["right"] + open_offset_x
	var clears_when_open = left_open_far_edge >= west_inner and right_open_far_edge <= east_inner

	print("\nCLOSED FOOTPRINT COVERS HOLE: ", covers_hole)
	print("OPEN PANELS STAY CLEAR OF CAR SIDE WALLS: ", clears_when_open,
		" (west_inner=", west_inner, ", east_inner=", east_inner, ")")

	if not covers_hole or not clears_when_open:
		print("❌ ELEVATOR DOOR ALIGNMENT TEST FAILED")
		get_tree().quit(1)
		return

	print("✅ ELEVATOR DOOR ALIGNMENT TEST PASSED")
	get_tree().quit(0)
