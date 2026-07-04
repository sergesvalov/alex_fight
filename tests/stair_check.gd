## Headless check script: verify stairwell entrance is clear
## Usage: godot --headless tests/stair_check.tscn
extends Node

func _ready() -> void:
	print("=== STAIRWELL ENTRANCE CHECK ===")
	var stair_scene = load("res://scenes/levels/hotel_siberia/stairwell_north.tscn")
	if not stair_scene:
		print("[FAILED] stairwell_north.tscn not found")
		get_tree().quit(1)
		return

	var stair = stair_scene.instantiate()
	add_child(stair)

	# Wait for CSG to bake
	await get_tree().physics_frame
	await get_tree().physics_frame

	var pass_all := true

	# Check that nothing blocks the entrance corridor (Z >= -0.5, Y < 4)
	# by scanning every CSGBox3D in the scene and checking if it extends into Z > -0.5
	# with a cross-section that would block corridor passage (Y 0-2, X -3 to +3)
	for child in stair.get_children():
		if child is CSGBox3D and child.name != "MainLanding":
			var origin = child.transform.origin
			var half = child.size / 2.0
			var z_min = origin.z - half.z
			var z_max = origin.z + half.z
			var y_min = origin.y - half.y
			var y_max = origin.y + half.y
			var x_min = origin.x - half.x
			var x_max = origin.x + half.x
			# Check if this box overlaps with entrance zone: Z in (-0.5, 0), Y in (0, 2.5), X in (-3, 3)
			var blocks_entrance = (
				z_max > -0.5 and z_min < 0.0 and
				y_max > 0.0 and y_min < 2.5 and
				x_max > -3.0 and x_min < 3.0
			)
			if blocks_entrance:
				print("[FAILED] Node '", child.name, "' overlaps with entrance zone!")
				print("         Pos=", origin, " Size=", child.size)
				print("         Z-range=[", z_min, ",", z_max, "]")
				pass_all = false

	if pass_all:
		print("[OK] Stairwell entrance (Z 0 to -0.5) is clear - no blocking geometry")
	
	# Also report all nodes and their Z ranges for manual inspection
	print("\n--- Node Z-ranges for manual review ---")
	for child in stair.get_children():
		if child is CSGBox3D:
			var origin = child.transform.origin
			var half = child.size / 2.0
			print("  ", child.name, ": Z [", origin.z - half.z, ", ", origin.z + half.z, "]  Y [", origin.y - half.y, ", ", origin.y + half.y, "]")

	print("================================")
	if pass_all:
		print("✅ ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("❌ SOME CHECKS FAILED")
		get_tree().quit(1)
