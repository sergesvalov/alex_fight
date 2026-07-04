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

Это абсолютная, математически идеальная карта гостиницы (Северный блок), полностью восстановленная по всем частям чертежа. 

### Модульная сетка (The 5-Meter Module Grid)

Весь чертеж построен на строгой модульной сетке, где базовый шаг по оси Z (вдоль коридора) равен **5.0 метрам**.
1. **Двухместные номера слева (DBL)**: Занимают ровно 2 модуля по высоте (10.0м). Номера идут сплошным блоком без зазоров (401, 402, 403, 405, 406, 408). Всего 6 номеров = 60.0м.
2. **Одноместные номера справа (SNG)**: Занимают ровно 1 модуль по высоте (5.0м). Каждые два одноместных номера идеально выравниваются с одним двухместным слева. Всего 9 номеров (410-421) = 45.0м.
3. **Северная лестница и Лифт**: Занимают 1 модуль по высоте (5.0м). При этом Лифт широкий (занимает большую часть правого крыла), а Техническое помещение — узкое.
4. **Горизонтальный коридор**: Занимает 1 модуль по высоте (5.0м). Он тянется от номера 401 направо, проходит под широким Лифтом и упирается в дверь узкого Технического помещения.
5. **Техническое помещение**: Занимает 2 модуля по высоте (10.0м). Это узкая полоса вдоль правой внешней стены.
6. **Южная лестница**: Занимает 1 модуль по высоте (5.0м). Она занимает правую часть здания (от левой стены коридора до правой внешней стены), закрывая коридор и правый ряд номеров снизу.
7. **Номер 408**: Расположен строго у южной стены. Его верхняя половина (5.0м) граничит с вертикальным коридором (там же находится вход в лестницу), а нижняя половина (5.0м) граничит с самой коробкой Южной лестницы.

### Псевдографическая карта (Масштаб: 1 строка = 5.0м по оси Z)

```text
Z (North)
  +-----------------------+---------------+-----------------------+-------+
  |                       |  NORTH STAIRS |       ELEVATOR        | MAINT |
  |                       |  (Z = 5.0m)   |       (Z = 5.0m)      |       |
  |          401          +-------D-------+-----------------------+ ROOM  |
  |         (DBL)         |                                       |       |
  |      (Z = 10.0m)      |        HORIZ CORRIDOR (Z = 5.0m)      D (10m) |
  +-----------------------+               +-----------------------+-------+
  |                       |               |                               |
  |                       D               D              410              |
  |          402          |   VERTICAL    |          (SNG)(5.0m)          |
  |         (DBL)         |   CORRIDOR    +-------------------------------+
  |      (Z = 10.0m)      |   (Z = 45m)   |                               |
  +-----------------------+               D              411              |
  |                       |               |          (SNG)(5.0m)          |
  |                       D               +-------------------------------+
  |          403          |               |                               |
  |         (DBL)         |               D              412              |
  |      (Z = 10.0m)      |               |          (SNG)(5.0m)          |
  +-----------------------+               +-------------------------------+
  |                       |               |                               |
  |                       D               D              413              |
  |          405          |               |          (SNG)(5.0m)          |
  |         (DBL)         |               +-------------------------------+
  |      (Z = 10.0m)      |               |                               |
  +-----------------------+               D              415              |
  |                       |               |          (SNG)(5.0m)          |
  |                       D               +-------------------------------+
  |          406          |               |                               |
  |         (DBL)         |               D              416              |
  |      (Z = 10.0m)      |               |          (SNG)(5.0m)          |
  +-----------------------+               +-------------------------------+
  |                       |               |                               |
  |                       D               D              417              |
  |          408          |               |          (SNG)(5.0m)          |
  |         (DBL)         |               +-------------------------------+
  |      (Z = 10.0m)      |               |                               |
  |                       |               D              420              |
  |                       |               |          (SNG)(5.0m)          |
  |                       +-------D-------+-------------------------------+
  |                       |               |                               |
  +-----------------------+               D              421              |
  |                                       |          (SNG)(5.0m)          |
  |             SOUTH STAIRS              +-------------------------------+
  |              (Z = 5.0m)                                               |
  +-----------------------------------------------------------------------+ Z (South)
```

