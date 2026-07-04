# Hotel Level Generator Guide

This file provides architectural guidelines and debugging instructions for AI agents working on the hotel level generator in this project.

## Architecture & Responsibilities

1. **Static Rooms vs. Dynamic Walls**:
   - Rooms (SingleRoom, DoubleRoom) are instanced from static .tscn files. They DO NOT have front walls (walls facing the corridor).
   - The front walls and the holes for the doors are generated dynamically by hotel_level_generator_geometry.gd using CSGBox3D.
   
2. **Scaling Logic (GlobalConfig.gd)**:
   - The level is scaled dynamically based on player_height (p_scale) and floor_ceiling_height (f_scale).
   - GlobalConfig.gd has a room_layouts dictionary. This dictionary uses an anchor system to position furniture relative to the room bounds.
   - For doors (MainDoor, WCDoor), anchor_x and anchor_z are set to 0. This means their local coordinates simply scale by f_scale. This guarantees they perfectly align with the dynamically generated corridor walls and holes (which are also scaled by f_scale).
   - Furniture uses anchors (e.g. anchor_x = 1) to maintain its exact distance from the walls (scaled by p_scale to avoid clipping into the expanding walls).

## Debugging Workflow

If you modify the generation logic, math offsets, or scaling, you must verify that the doors still perfectly align with the holes.

How to verify:
1. Run the test suite using Godot headless mode.
2. The test suite automatically runs the debug_geometry.gd script.
3. If you want to use the script directly in your own code or tests, you can call:
   ar mismatches = DebugGeometry.print_room_alignments(generated_floor_node)
   This will print all Door AABBs and Hole AABBs, and report any mismatches greater than 5cm.

WARNING: NEVER blindly multiply door positions by f_scale if they are already anchored or if the generator does not multiply its offsets. Always consult hotel_level_generator.gd to see which base variables (like wall_thickness or room_door_z_offset) are scaled, and ensure the local door logic matches!
