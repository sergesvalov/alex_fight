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
2. The test suite automatically runs the debug_geometry.gd script. It also validates that entity spawning does not silently fail or crash.
3. If you want to use the script directly in your own code or tests, you can call:
    var mismatches = DebugGeometry.print_room_alignments(generated_floor_node)
   This will print all Door AABBs and Hole AABBs, and report any mismatches greater than 5cm on both X and Z axes, as well as floating doors.

WARNING: NEVER blindly multiply door positions by f_scale if they are already anchored or if the generator does not multiply its offsets. Always consult hotel_level_generator.gd to see which base variables (like wall_thickness or room_door_z_offset) are scaled, and ensure the local door logic matches!

## Hotel Level Geometry Maps

The following pseudographics show the 4th-floor layout in 3 different horizontal cross-sections, verifying the parallelepiped bounding box and doorway alignment.

### Level 1: Floor Level (Y = 0)
Shows all rooms, corridor, doorways (D), and stairs/elevators.

```text
Z = -69.5 (North)
+-------+-------+-------+-------+
|       | NORTH |       |       |
| EMPTY | STAIRS| ELEV  | EMPTY |
|       +---D---+---D---+       |
+-------+...............+-------+ Z = -58.0
|       |...............|       |
| EMPTY |...............| EMPTY | Z = -50.5
|       |...............+-------+
|       |...............D MAINT |
+-------+-------+.......+-------+ Z = -47.5
|       |...............D  410  |
|  401  D...............|       |
| (DBL) |...............+-------+
|       |...............D  411  |
+-------+...............|       |
|       |...............+-------+
|  402  D...............D  412  |
| (DBL) |...............|       |
|       |...............+-------+
|       |...............D  413  |
+-------+...............|       |
|       |...............+-------+
|  403  D...............D  415  |
| (DBL) |...............|       |
+-------+.......+.......+-------+
|       |.......|.......D  416  |
|  405  D.......|.......|       |
| (DBL) |.......+.......+-------+
|       |...............D  417  |
+-------+...............|       |
|       |...............+-------+
|  406  D...............D  420  |
| (DBL) |...............|       |
|       |...............+-------+
|       |...............D  421  |
+-------+...............|       |
|       |...............+-------+ Z = 10.0
|  408  D...............|       |
| (DBL) |...............| EMPTY |
|       |...+-STAIRS+...| SPACE | Z = 13.05
+-------+   | SOUTH |   +-------+
|           D       |           |
| EMPTY     |       |   EMPTY   |
| SPACE     |       |   SPACE   |
+-----------+-------+-----------+ Z = 24.55 (South)
```

### Level 2: Above Door Lintel (Y = 2.5)
Shows the geometry exactly 1 pixel above the door holes. Notice that all doorways (D) are replaced by solid walls (| or -), proving there are no holes extending upwards.

```text
Z = -69.5 (North)
+-------+-------+-------+-------+
|       | NORTH |       |       |
| EMPTY | STAIRS| ELEV  | EMPTY |
|       +-------+-------+       |
+-------+               +-------+ Z = -58.0
|       |               |       |
| EMPTY |               | EMPTY | Z = -50.5
|       |               +-------+
|       |               | MAINT |
+-------+-------+       +-------+ Z = -47.5
|       |               |  410  |
|  401  |               |       |
| (DBL) |               +-------+
|       |               |  411  |
+-------+               |       |
|       |               +-------+
|  402  |               |  412  |
| (DBL) |   CORRIDOR    |       |
|       |               +-------+
|       |               |  413  |
+-------+               |       |
|       |               +-------+
|  403  |               |  415  |
| (DBL) |               |       |
+-------+       +       +-------+
|       |       |       |  416  |
|  405  |       |       |       |
| (DBL) |       +       +-------+
|       |               |  417  |
+-------+               |       |
|       |               +-------+
|  406  |               |  420  |
| (DBL) |               |       |
|       |               +-------+
|       |               |  421  |
+-------+               |       |
|       |               +-------+ Z = 10.0
|  408  |               |       |
| (DBL) |               | EMPTY |
|       |   +-STAIRS+   | SPACE | Z = 13.05
+-------+   | SOUTH |   +-------+
|           |       |           |
| EMPTY     |       |   EMPTY   |
| SPACE     |       |   SPACE   |
+-----------+-------+-----------+ Z = 24.55 (South)
```

### Level 3: Ceiling Joint (Y = 3.5)
Shows the geometry where the walls meet the ceiling. It is identical to Level 2, proving the monolithic nature of the upper walls with zero gaps.

```text
Z = -69.5 (North)
+-------+-------+-------+-------+
|       | NORTH |       |       |
| EMPTY | STAIRS| ELEV  | EMPTY |
|       +-------+-------+       |
+-------+               +-------+ Z = -58.0
|       |               |       |
| EMPTY |               | EMPTY | Z = -50.5
|       |               +-------+
|       |               | MAINT |
+-------+-------+       +-------+ Z = -47.5
|       |               |  410  |
|  401  |               |       |
| (DBL) |               +-------+
|       |               |  411  |
+-------+               |       |
|       |               +-------+
|  402  |               |  412  |
| (DBL) |   CORRIDOR    |       |
|       |               +-------+
|       |               |  413  |
+-------+               |       |
|       |               +-------+
|  403  |               |  415  |
| (DBL) |               |       |
+-------+       +       +-------+
|       |       |       |  416  |
|  405  |       |       |       |
| (DBL) |       +       +-------+
|       |               |  417  |
+-------+               |       |
|       |               +-------+
|  406  |               |  420  |
| (DBL) |               |       |
|       |               +-------+
|       |               |  421  |
+-------+               |       |
|       |               +-------+ Z = 10.0
|  408  |               |       |
| (DBL) |               | EMPTY |
|       |   +-STAIRS+   | SPACE | Z = 13.05
+-------+   | SOUTH |   +-------+
|           |       |           |
| EMPTY     |       |   EMPTY   |
| SPACE     |       |   SPACE   |
+-----------+-------+-----------+ Z = 24.55 (South)
```

