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

Это идеальная карта гостиницы. Это северная часть.
This is the ideal hotel map (Northern Block), based on the exact architectural layout provided in the reference screenshot.

### Текстовая расшифровка (Textual Decoding)

Геометрия северного блока строго подчиняется следующим правилам выравнивания:
1. **Т-образный перекресток**: Вертикальный коридор не уходит влево. Он поднимается от номеров 401/410 и поворачивает **строго направо**, образуя горизонтальный коридор ("LEVEL 4").
2. **Левая стена коридора**: Правая стена номеров 401 и верхнего левого номера образует единую прямую линию, которая идеально совпадает с **левой стеной Северной лестницы**.
3. **Правая стена коридора**: Левая стена номеров 410, 411 и т.д. образует единую прямую линию, которая идеально совпадает с **левой стеной Лифта**.
4. **Горизонтальный коридор**: Ограничен сверху Северной лестницей и Лифтом. Ограничен снизу номерами 401 и 410. Слева он упирается в глухую стену верхнего левого номера. Справа он заканчивается дверью в Техническое помещение (Maintenance).
5. **Техническое помещение**: Находится в правой колонке, его ширина вместе с шириной Лифта математически равна ширине одиночного номера (410).

### Псевдографическая карта (Pseudographic Map)

```text
Z (North)
  +-----------------------+---------------+-------+-------+
  |                       |               |       |       |
  |     TOP-LEFT ROOM     |  NORTH STAIRS | ELEV  | EMPTY |
  |    (Inaccessible)     |               |       |       |
  +-----------------------+-------D-------+---D---+-------+
  |                       |                               |
  |     SOLID WALL        |      HORIZONTAL CORRIDOR      D MAINT
  |                       |          "LEVEL 4"            |
  +-----------------------+               +---------------+
  |                       |               |               |
  |          401          D   VERTICAL    D      410      |
  |         (DBL)         |   CORRIDOR    |     (SNG)     |
  |                       |               |               |
  +-----------------------+               +---------------+
  |                       |               |               |
  |          402          D               D      411      |
  |         (DBL)         |               |     (SNG)     |
  |                       |               |               |
                          V               V
                        (South)
```

