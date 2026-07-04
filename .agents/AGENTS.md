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
1. **Номер 401**: Находится в самом левом верхнем углу карты. Все номера слева (401, 402, 403, 405, 406, 408) имеют одинаковый размер (длина 10.0м).
2. **Идеальные пропорции 401**: Размер номера 401 в длину коридора (по оси Z) в точности равен размеру расстояния от стены возле лестницы сложенному с таким же расстоянием от стены лестницы вдоль по коридору.
   - Это означает, что номер 401 по высоте (Z) идеально накрывает как Северную лестницу (5.0м), так и горизонтальный коридор (5.0м). Итого 10.0м.
3. **Г-образный перекресток**: Горизонтальный коридор "LEVEL 4" идет **только направо** строго от номера 401. Налево он не уходит, так как там находится монолитная стена номера 401.
4. **Выравнивание стен**:
   - Нижняя стена номера 401 идеально совпадает с верхней стеной номера 410 (и является нижней границей горизонтального коридора).
   - Правая стена номера 401 является левой границей как Северной лестницы, так и вертикального коридора.
5. **Техническое помещение**: Находится в правом верхнем углу. Оно зеркально отражает номер 401 по высоте, занимая ту же ширину, что и пространство справа от лифта, и тянется от северной стены вплоть до номера 410 (10.0м). Вход строго по центру горизонтального коридора.

### Псевдографическая карта (Масштаб: 1 строка = 2.0м по оси Z)

```text
Z (North)
  +-----------------------+---------------+-------+---------------+
  |                       |  NORTH STAIRS | ELEV  |               |
  |                       |  (Z = 5.0m)   |       |  MAINTENANCE  |
  |          401          +-------D-------+---D---+     ROOM      |
  |         (DBL)         |      HORIZONTAL CORRID|  (Z = 10.0m)  |
  |      (Z = 10.0m)      |      (Z = 5.0m)       D               |
  +-----------------------+               +-------+---------------+
  |                       |               |                       |
  |                       D               D          410          |
  |          402          |               |         (SNG)         |
  |         (DBL)         |               |       (Z = 6.0m)      |
  |      (Z = 10.0m)      |               +-----------------------+
  |                       D   VERTICAL    |                       |
  +-----------------------+   CORRIDOR    D          411          |
  |                       |               |         (SNG)         |
  |                       D               +-----------------------+
  |          403          |               |                       |
  |         (DBL)         |               D          412          |
  |      (Z = 10.0m)      |               |         (SNG)         |
  |                       D               +-----------------------+
  +-----------------------+               |                       |
  |                       |               D          413          |
  |                       D               |         (SNG)         |
  |          405          |               +-----------------------+
  |         (DBL)         |               |                       |
  |      (Z = 10.0m)      |               D          415          |
  |                       D               |         (SNG)         |
  +-----------------------+               +-----------------------+
  |                       |               |        (EMPTY)        |
  |                       D               +-----------------------+
  |          406          |               |                       |
  |         (DBL)         |               D          416          |
  |      (Z = 10.0m)      |               |         (SNG)         |
  |                       D               +-----------------------+
  +-----------------------+               |        (EMPTY)        |
  |                       |               +-----------------------+
  |                       D               |                       |
  |          408          |               D          417          |
  |         (DBL)         |               |         (SNG)         |
  |      (Z = 10.0m)      |               +-----------------------+
  +-----------------------+               |                       |
  |                       |               D          420          |
  |                       |               |         (SNG)         |
  |        EMPTY          |               +-----------------------+
  |        SPACE          |               |                       |
  |                       |               D          421          |
  |                       +-------D-------+         (SNG)         |
  |                       | SOUTH STAIRS  +-----------------------+
  +-----------------------+---------------+
```

