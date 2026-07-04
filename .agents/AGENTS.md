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
This is the ideal hotel map (Northern Block), based on the exact architectural layout provided in the reference screenshot and mathematically verified.

### Текстовая расшифровка (Textual Decoding)

Геометрия северного блока строго подчиняется следующим идеальным математическим правилам:
1. **Номер 401**: Находится в самом левом верхнем углу карты.
2. **Идеальные пропорции 401**: Размер номера 401 в длину коридора (по оси Z) в точности равен размеру расстояния от стены возле лестницы сложенному с таким же расстоянием от стены лестницы вдоль по коридору.
   - Это означает, что номер 401 состоит из двух равных половин (по длине): верхняя половина примыкает к Северной лестнице, а нижняя половина примыкает к горизонтальному коридору.
   - Высота Лестницы (Z-глубина) = Ширине Горизонтального Коридора.
3. **Г-образный перекресток**: Горизонтальный коридор "LEVEL 4" идет **только направо** строго от номера 401. Налево он не уходит, так как там находится монолитная стена номера 401.
4. **Выравнивание стен**:
   - Нижняя стена номера 401 идеально совпадает с верхней стеной номера 410 (и является нижней границей горизонтального коридора).
   - Правая стена номера 401 является левой границей как Северной лестницы, так и вертикального коридора.
5. **Техническое помещение**: Находится в правом верхнем углу. Оно занимает всю высоту от внешней северной стены вплоть до стены номера 410 (то есть его длина равна длине Лифта + ширина горизонтального коридора). Вход в него находится строго по центру горизонтального коридора.
6. **Ширина правого крыла**: Ширина Технического помещения вместе с шириной Лифта математически равна ширине одиночного номера (410).

### Псевдографическая карта (Pseudographic Map)

```text
Z (North)
  +-----------------------+---------------+-------+---------------+
  |                       |               |       |               |
  |                       |  NORTH STAIRS | ELEV  |  MAINTENANCE  |
  |          401          |               |       |     ROOM      |
  |         (DBL)         +-------D-------+---D---+               |
  |                       |                       |               |
  | [Size = 2 x H_corr]   D  HORIZONTAL CORRIDOR  D [Size=2xH_cor]|
  |                       |      "LEVEL 4"        |               |
  +-----------------------+               +-------+---------------+
  |                       |               |                       |
  |          402          D   VERTICAL    D          410          |
  |         (DBL)         |   CORRIDOR    |         (SNG)         |
  |                       |               |                       |
  +-----------------------+               +-----------------------+
  |                       |               |                       |
  |          403          D               D          411          |
  |         (DBL)         |               |         (SNG)         |
  |                       |               |                       |
                          V               V
                        (South)
```

