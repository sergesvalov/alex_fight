class_name HotelProgression
extends RefCounted

# What collecting a floor's tapes unlocks. The generator connects
# GameStateManager.all_tapes_collected to this; it fires every time any floor's 3 tapes are all
# in (see GameStateManager.collect_tape()). Each reward has its own one-time guard, because
# they happen on different floors - floor 4, the starting floor, has no corridor gating at all:
#   1. The first time EVER any floor's tapes complete (in practice always floor 4, the only floor
#      unlocked at game start) - punches a doorway through a random room's OUTER wall on that
#      floor and connects it to a random room on floor 3 (_create_exit_portal()), an unmarked
#      door to an unknown room, permanently widening the stairs-access range to include floor 3
#      once actually walked through (secret_portal.gd calls GameStateManager.unlock_floor()).
#      Gated by secret_portal_active so it only ever happens once.
#   2. The first time floor 3's OWN tapes complete - floor 3's corridor-splitting barrier
#      (HotelTrapBuilder.add_floor3_corridor_barrier(), corridor_barrier.gd) switches off outright, and floor 5
#      unlocks immediately - no need to walk anywhere first, collecting the tapes is the whole
#      trigger. Gated separately by floor3_corridor_unlocked, since by the time floor 3 is even
#      reachable, secret_portal_active from event 1 is already true and would otherwise skip this.
static func on_all_tapes_collected(generator: HotelLevelGenerator) -> void:
	if not GameStateManager.secret_portal_active:
		GameStateManager.secret_portal_active = true

		var is_double = randi() % 2 == 0
		var layout = HotelConstants.DOUBLE_ROOM_LAYOUT if is_double else HotelConstants.SINGLE_ROOM_LAYOUT
		var keys = layout.keys()

		GameStateManager.secret_portal_floor = GameStateManager.current_floor
		GameStateManager.secret_portal_is_double = is_double
		GameStateManager.secret_portal_room_num = keys[randi() % keys.size()]
		GameStateManager.secret_portal_target = HotelPortalSpawner.pick_random_floor3_target(generator)
		GameStateManager.secret_portal_target_floor = 3

		HotelPortalSpawner.create_exit_portal(generator)
		# What just happened, in Alex's own words - the tape's text no longer has to say it.
		DialogSystem.trigger_alex_line("floor4_done")

	if GameStateManager.current_floor == 3 and not GameStateManager.floor3_corridor_unlocked:
		GameStateManager.floor3_corridor_unlocked = true
		GameStateManager.unlock_floor(5)
		DialogSystem.trigger_alex_line("floor3_done")

	# 3. Floor 5's own tapes - its room-shuffling trap (room_shuffle_trap.gd) switches off, the
	#    sealed room's door opens normally again, and floor 6 unlocks.
	if GameStateManager.current_floor == 5 and not GameStateManager.floor5_rooms_unlocked:
		GameStateManager.floor5_rooms_unlocked = true
		if is_instance_valid(generator._sealed_room_door):
			generator._sealed_room_door.locked_from_corridor = false
		GameStateManager.unlock_floor(6)
		DialogSystem.trigger_alex_line("floor5_done")

	# 4. Floor 6's own tapes - its sleepers (sleeper_cerberus.gd) switch off for good, and
	#    floor 7 unlocks.
	if GameStateManager.current_floor == 6 and not GameStateManager.floor6_sleepers_off:
		GameStateManager.floor6_sleepers_off = true
		GameStateManager.unlock_floor(7)
		DialogSystem.trigger_alex_line("floor6_done")

	# 5. Floor 7's own tapes - its blackouts (blackout_trap.gd) stop for good, floor 8 unlocks.
	if GameStateManager.current_floor == 7 and not GameStateManager.floor7_lights_steady:
		GameStateManager.floor7_lights_steady = true
		GameStateManager.unlock_floor(8)
		DialogSystem.trigger_alex_line("floor7_done")

	# 6. Floor 8's own tapes - its name doors (name_door_trap.gd) let anyone through, and the
	#    elevator can go DOWN to floor 2. Floors are unlocked as one contiguous range, so this
	#    is the one place the range grows downward - floor 2 sits right under the open floor 3.
	if GameStateManager.current_floor == 8 and not GameStateManager.floor8_named:
		GameStateManager.floor8_named = true
		GameStateManager.unlock_floor(2)
		DialogSystem.trigger_alex_line("floor8_done")

	# 7. Floor 2's own tapes - "that night" stops repeating: its sleepers and blackouts (the
	#    floor 6 and floor 7 traps together) switch off, and floor 9 unlocks.
	if GameStateManager.current_floor == 2 and not GameStateManager.floor2_done:
		GameStateManager.floor2_done = true
		GameStateManager.unlock_floor(9)
		DialogSystem.trigger_alex_line("floor2_done")

	# 8. Floor 9's tapes stop its sweeping units (sweep_camera_trap.gd) and unlock floor 10;
	#    floor 10's stop its advancing edge (edge_wall_trap.gd).
	#    Floor 10 is the top of the route (4-3-5-6-7-8-2-9-10) and its tapes also open the roof,
	#    where the lift machine room holds the code that sends the elevator to floor 1
	#    (roof_code_plate.gd).
	if GameStateManager.current_floor == 9 and not GameStateManager.floor9_cameras_off:
		GameStateManager.floor9_cameras_off = true
		GameStateManager.unlock_floor(10)
		DialogSystem.trigger_alex_line("floor9_done")
	if GameStateManager.current_floor == 10 and not GameStateManager.floor10_edge_stopped:
		GameStateManager.floor10_edge_stopped = true
		# The roof is "floor 11" to the stair gates (HotelRoofBuilder.build_roof_structures()) - this is what
		# lets the player through the doors at the top of both stairwells.
		GameStateManager.unlock_floor(HotelRoofBuilder.ROOF_FLOOR_INDEX)
		DialogSystem.trigger_alex_line("floor10_done")
