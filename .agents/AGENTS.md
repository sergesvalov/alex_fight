# Hotel Level Generator Guide

This file provides architectural guidelines and debugging instructions for AI agents working on the hotel level generator in this project.

> [!IMPORTANT]
> **Keep this file honest.** When you change level geometry, edit or delete the section describing it in the *same* commit — never append a new section on top of a stale one. Past confusion on the North Stairs block happened because an old single-floor door design and the current multi-floor design were both documented here at once, contradicting each other. If a section's numbers don't match the current `.tscn`, delete the section — don't leave it "for reference."

> [!IMPORTANT]
> **Trust the user's bug report like it came from a senior engineer - then go verify it, don't substitute your own guess for it.** Incident (2026-08-23): the user reported the elevator doorway looked square/wrong ("проём"). The agent diagnosed it as a flashlight specular highlight ("блик") and fixed the light instead of checking the actual doorway geometry first. The glare fix was real and worth keeping, but it wasn't what the user reported, and the user had to repeat themselves before the actual bug (the door hole's CSGBox3D size not matching what was authored - see `elevator_shaft.tscn`/`elevator_controller.gd::_log_shaft_geometry()`) got investigated. When the user names a specific symptom ("there's a gap", "it's square", "the door doesn't open"), start by checking the geometry/state THEY named against the actual `.tscn`/runtime values (logs, `_log_shaft_geometry()`-style dumps) before reaching for an adjacent, more familiar explanation - even a plausible-sounding one (lighting, materials) can be a distraction from the literal thing reported.

## Architecture & Responsibilities

1. **Master Generator (`hotel_level_generator.gd`)**:
   - Acts as the central director. It dynamically builds global boundary walls, floors, ceilings, and special corridor blockers (like the South Stairs wall).
   - Instantiates pre-built room CSG blocks directly into the level.

2. **Self-Contained CSG Rooms**:
   - Rooms are instantiated from `blocks/double_room.tscn` and `blocks/single_room.tscn`.
   - Rooms **DO** contain their own front walls (facing the corridor) and door holes, built using `CSGCombiner3D`.
   - Double rooms have an East wall. Single rooms have a West wall.
   - Single rooms intentionally lack an East wall because they align flush with the global building East wall.

3. **Mirroring and Orientations**:
   - Hotel plumbing is often shared between adjacent rooms.
   - We achieve this by mirroring specific rooms along the `Z` axis (`scale.z = -1.0`).
   - For example, Double Room 403 is mirrored so its WC touches Double Room 405's WC at `Z = 0.0`.
   - Single Rooms 411, 413, 416, and 417 are mirrored to ensure their WCs align back-to-back with neighboring single rooms, or cross-corridor with double rooms.
   - **Elevator Shaft (`elevator_shaft.tscn`)**: Mirrored along the Z axis (`scale.z = -1.0`) to correctly orient its interior (panel, lights) while keeping the doorway (`ElevatorDoorHole`) on the South face (local Z=0.1) pointing towards the horizontal corridor.

## Hotel Level Geometry Map (Modular Grid)

### Модульная сетка (The 5-Meter Module Grid)

Весь чертеж построен на строгой модульной сетке, где базовый шаг по оси Z (вдоль коридора) равен **5.0 метрам**.
1. **Двухместные номера слева (DBL)**: Занимают ровно 2 модуля по высоте (10.0м). Номера идут сплошным блоком без зазоров (401, 402, 403, 405, 406, 408). Всего 6 номеров = 60.0м.
2. **Одноместные номера справа (SNG)**: Занимают ровно 1 модуль по высоте (5.0м). Каждые два одноместных номера идеально выравниваются с одним двухместным слева. Всего 9 номеров (410-421) = 45.0м.
3. **Северная лестница и Лифт**: Занимают 1 модуль по высоте (5.0м). При этом Лифт широкий (занимает большую часть правого крыла), а Техническое помещение — узкое.
4. **Горизонтальный коридор**: Занимает 1 модуль по высоте (5.0м). Он тянется от номера 401 направо, проходит под широким Лифтом и упирается в дверь узкого Технического помещения.
5. **Техническое помещение**: Занимает 2 модуля по высоте (10.0м). Это узкая полоса вдоль правой внешней стены.
6. **Южная лестница**: Занимает 1 модуль по высоте (5.0м). Она занимает центральную часть (под вертикальным коридором) и правую часть здания (под номером 421).
7. **Номер 408**: Расположен строго у южной стены. Его верхняя половина (5.0м) граничит с вертикальным коридором, а нижняя половина (5.0м) граничит с самой коробкой Южной лестницы. Вход на лестницу расположен строго по центру коридора, чуть ниже номера 421.

### Псевдографическая карта (Масштаб: 1 строка = 5.0м по оси Z)

```text
Z (North)
  +-----------------------+---------------+-----------------------+-------+
  |                       |  NORTH STAIRS |       ELEVATOR        | MAINT |
  |                       |  (Z = 5.0m)   |       (Z = 5.0m)      |       |
  |          401          +-------D-------+-----------D-----------+ ROOM  |
  |         (DBL)         |                                       |       |
  |      (Z = 10.0m)      |        HORIZ CORRIDOR (Z = 5.0m)      D (10m) |
  +-----------------------+               +-----------------------+-------+
  |                       |               |                               |
  |                       D               D              410              |
  |          402          |   VERTICAL    |          (SNG)(5.0m)          |
  |         (DBL)         |   CORRIDOR    +-------------------------------+
  |      (Z = 10.0m)      |   (Z = 45m)   |                               |
  |                       |               D              411              |
  +-----------------------+               |          (SNG)(5.0m)          |
  |                       |               +-------------------------------+
  |                       D               |                               |
  |          403          |               D              412              |
  |         (DBL)         |               |          (SNG)(5.0m)          |
  |      (Z = 10.0m)      |               +-------------------------------+
  |                       |               |                               |
  +-----------------------+               D              413              |
  |                       |               |          (SNG)(5.0m)          |
  |                       D               +-------------------------------+
  |          405          |               |                               |
  |         (DBL)         |               D              415              |
  |      (Z = 10.0m)      |               |          (SNG)(5.0m)          |
  |                       |               +-------------------------------+
  +-----------------------+               |                               |
  |                       |               D              416              |
  |                       D               |          (SNG)(5.0m)          |
  |          406          |               +-------------------------------+
  |         (DBL)         |               |                               |
  |      (Z = 10.0m)      |               D              417              |
  |                       |               |          (SNG)(5.0m)          |
  +-----------------------+               +-------------------------------+
  |                       |               |                               |
  |                       D               D              420              |
  |          408          |               |          (SNG)(5.0m)          |
  |         (DBL)         |               +-------------------------------+
  |      (Z = 10.0m)      |               |                               |
  |                       |       ▼       D              421              |
  |                       |               |          (SNG)(5.0m)          |
  |                       +-------D-------+-------------------------------+
  |                       |                                               |
  |                       |                 SOUTH STAIRS                  |
  |                       |                  (Z = 5.0m)                   |
  +-----------------------+-----------------------------------------------+ Z (South)
```

### Object Descriptions
- **#**: Walls (Solid CSGBox3D structures defining the rooms and corridors).
- **.**: Floor/Ceiling areas.
- **B**: Bed. A large interactable furniture object where characters can rest or hide.
- **W**: Wardrobe. A tall wooden storage unit.
- **T**: Table. A standard desk/table.
- **C**: Chair. An interactable physics object.
- **D**: Door. The interactive doors placed at room entrances and WCs.

## Level Instancing & 10 Floors (Added July 2026)
- The game now has 10 individual Godot scenes for each floor (`scenes/levels/hotel_siberia/hotel_level_1.tscn` to `hotel_level_10.tscn`).
- Each scene inherits from `base_hotel_level.tscn` but modifies its `HotelGeometry` properties in the inspector to customize:
  - `floor_number`: Determines the elevator panel display.
  - `carpet_color`: Sets a unique visual theme for the floor.
  - `map_texture`: Replaces the floor map image on the wall.
  - `empty_box_mode`: (Only used on Level 1). If `true`, the generator skips all internal walls and rooms, creating only an empty concrete parallel-piped.
- The `hotel_level_generator.gd` now runs immediately inside `_ready()` regardless of `Engine.is_editor_hint()`. This ensures geometry is always available at runtime.
- **P.T. Non-Euclidean Loop (corrected 2026-08-22 - the paragraph this replaces was wrong on both counts)**: `seamless_teleporter.gd` does not exist in this codebase (removed as dead code, never wired to any node) and never implemented the loop. All 10 floors DO physically coexist simultaneously in one scene, stacked at different Y offsets computed in `_generate_level()` (`y_offset = (i - floor_number) * y_step`, see `hotel_level_generator.gd`) - nothing is loaded/unloaded per floor. The "infinite loop" illusion comes entirely from stairs/elevator logic teleporting the player's Y position between these already-built floors (north_stairs' door-based teleport, the south stairs dog-leg ramps, and `elevator_controller.gd`'s button sequence all rely on this - see MECHANICS.md). Per-floor lighting (`_set_lit_floor()`) exists specifically because all floors' lights would otherwise be lit at once.
- **Stairs are gated by a persistent floor RANGE, not per-floor tape collection (updated 2026-08-23)**: because both stair blocks physically connect floor N's stairwell straight into floor N+1's corridor (see above), an `Area3D` (`stairs_gate.gd`) sits in every stairwell doorway - South Stairs' `SouthStairsDoor`, North Stairs' `DoorEast`/`DoorWest` - one per floor, tagged with that floor's number. Crossing a gate whose floor number differs from `GameStateManager.current_floor` bounces the player straight back (Y-shift by one floor-to-floor height) unless that floor number falls inside `GameStateManager.[unlocked_floor_min, unlocked_floor_max]` ("FLOOR ACCESS" section of `GameStateManager.gd`), in which case the hop is allowed and `current_floor` updates. Collecting all 3 tapes on the floor you're currently standing on does **not** by itself widen this range - completing a floor instead spawns a one-time secret exit door through a random room's outer wall (`hotel_level_generator.gd::_create_exit_portal()`), and only actually stepping through it (currently always landing on floor 3) calls `GameStateManager.unlock_floor()` and permanently adds that floor to the range. The elevator (`elevator_controller.gd`) is gated by the same range too (added 2026-08-23) - `request_floor()` (called by both the physical buttons and the 2D on-screen floor display, see MECHANICS.md section 10) redirects a press for any floor outside `[unlocked_floor_min, unlocked_floor_max]` to `HUB_FLOOR` (4) instead, rather than ignoring it - the door still cycles, it just always delivers somewhere safe. It keeps `current_floor` in sync on every successful trip, since `stairs_gate.gd` depends on that value staying accurate regardless of how the player got to a floor - but it never calls `unlock_floor()` itself, only the secret exit door does.

Floor 4 additionally has its own permanent corridor-splitting barrier (`corridor_barrier.gd`, only ever created there) that keeps the elevator/North Stairs unreachable until floor 4's own 3 tapes are collected - completing them switches the barrier off for good AND immediately unlocks floor 5 (no door to find, unlike floor 3). Both this and the secret exit door fire from the same one-time `_on_all_tapes_collected()` handler, deliberately pairing two different "everyday nightmare" tropes: a door leading who-knows-where, and a corridor that never actually gets you to the end no matter how far you walk. See MECHANICS.md sections 10, 11, 13 and 14.

## North Stairs Block Map (`blocks/north_stairs.tscn`)

Верифицировано против текущего `north_stairs.tscn` (2026-08): единая `StairsSouthWall` высотой 4.5м, никакой надставки поверх неё.

Блок инстанциируется генератором: `inst.position = Vector3(1.05, 0, -30.0)`. Преобразование координат: `global = local + inst.position`.

### Ключевые координаты (глобальные)

| Элемент | Global X | Global Z | Y | Примечание |
|---------|----------|----------|---|------------|
| StairsEastWall | +4.65..+4.85 | -30.0..-25.1 | 0..4.5 | Восточная стена |
| StairsWestWall | -2.75..-2.55 | -30.0..-25.1 | 0..4.5 | Западная стена |
| StairsSouthWall | -2.75..+4.85 | -25.2..-25.1 | 0..4.5 | Южная стена, единый CSGBox3D (без надставки) |
| DoorHoleEast | +3.25..+4.45 | -25.2..-25.1 | -0.1..2.2 | Вход этого этажа (низ блока) |
| DoorHoleWest | -2.45..-1.15 | -25.2..-25.1 | -0.1..2.2 | "Выход" этого этажа — физически это дверь у пола, см. примечание ниже |
| NELanding | +1.25..+3.65 | -30.0..-27.6 | **1.5** (сурф.) | Промежуточная площадка восток |
| NWLanding | -3.65..-1.25 | -30.0..-27.6 | **3.0** (сурф.) | Промежуточная площадка запад |

### Три пролёта лестницы (физическая геометрия ступеней внутри блока)

| Пролёт | Ось | Y нижний | Y верхний | Где |
|--------|-----|----------|-----------|-----|
| **EastFlight** | Z = -30.0..-27.6 | 0.0 (пол, у сев. стены) | 1.5 (NE Landing) | X = +3.25..+4.45 |
| **NorthFlight** | Z = -27.6..-25.2 | 1.5 (NE, восток) | 3.0 (NW, запад) | X = -1.25..+1.25 |
| **WestFlight** | Z = -30.0..-27.6 | 3.0 (NW Landing) | 4.5 (у сев. стены) | X = -4.45..-3.25 |

> [!IMPORTANT]
> Ступени физически поднимаются с Y=0 до Y=4.5 внутри блока (таблица выше) — но **обе** дверные дыры в южной стене (`DoorHoleEast`, `DoorHoleWest`) вырезаны на одной и той же низкой высоте (Y≈-0.1..2.2), а не одна внизу и одна вверху. Это осознанное решение, не баг: см. правило "Multi-Floor Wall Overlapping" в разделе **Godot 4 CSG & Headless Testing Gotchas** ниже — верхний выход этого этажа физически реализован как нижняя дверь блока *следующего* этажа.

### Вид сверху — план (масштаб: 1 символ ≈ 0.5м)

```
         local X: -3.7 -2.5 -1.5 -0.5  0.0 +0.5 +1.5 +2.5 +3.7
  local Z=0.0  ████████████████████████████████████████████████  ← WallNorth (global Z=-30.0)
               ██                      │                      ██
  Z=0.5        ██  NW Landing          │       NE Landing     ██
  Z=1.0        ██  (Y=3.0 сурф.)       │       (Y=1.5 сурф.)  ██
  Z=1.2        ██  WestFlight ↑        │       EastFlight ↑   ██
               ██  (Y→4.5 у сев.)      │       (Y→0 у сев.)   ██
  Z=2.4        ██════════════════NorthFlight══════════════════ ██
               ██  Y=3.0 (запад)      /↗       Y=1.5 (восток) ██
  Z=3.0        ██     Запад         NorthFlight    Восток      ██
  Z=3.5        ██     шахт          (Z=2.4→4.8)   шахт        ██
  Z=4.0        ██     (Y=4.5)                      (Y=0)       ██
  Z=4.5        ██     плоско→дверь          плоско→дверь       ██
  Z=4.9  █████████ ██ █████████████████████████ ██ █████████████  ← WallSouth (Z=-25.1)
                    ▲                                 ▲
               DoorWest                          DoorEast
              (обе на Y≈-0.1..2.2, у пола — см. примечание выше)
         global X: -1.75                              +3.85
```

### Вид сбоку — профиль высот (по центральной линии, геометрия ступеней)

```
 Y
4.5 ══════════════════╗ WestFlight ╗                    WestFloor (flat)
    | (Y=4.5 у Z=-30) ║  подъём    ║
3.0 |                 ╚════════════╣ NWLanding ═══════╗ NorthFlight
    |                              |                   ║  спуск
1.5 |                              ╠════════════ NE ═══╝
    |                                   Landing
0.0 ╚══════════════════════════════╗ EastFlight ╗      EastFloor (flat)
    |           (Y=0 у Z=-30)      ║  подъём    ║
    N (Z=-30.0)                                   S (Z=-25.1)
```

### Правила для AI-агентов

> [!IMPORTANT]
> **Высоты**: Y=0 → 1.5 → 3.0 → 4.5. Три равных ступени по 1.5м. Полный подъём 4.5м = `corridor_height(4.0) + floor_thickness(0.5)`.

> [!NOTE]
> **Transform рамп** (-90°Y): `Transform3D(-4.37114e-08, 0, -1, 0, 1, 0, 1, 0, -4.37114e-08, ox, 0, oz)`. `polygon.x → world -Z`, `polygon.y → world Y`, `depth → world +X`. NorthFlight — identity transform, `depth → world +Z`.

> [!WARNING]
> **Вырез в полу**: Генератор НЕ создаёт пол в X=[-2.55..+4.65], Z=[-30..-25.2]. Блок должен своими стенами замкнуть этот проём. `inst.position.X=1.05` центрирует блок (local X=[-3.7..+3.7]) в зоне дыры (global X=[-2.65..+4.75]).

## Godot 4 CSG & Headless Testing Gotchas

> [!CAUTION]
> **Headless CSG Mesh Generation Delay**
> When running autotests via Jenkins (`godot --headless`), the engine uses `RendererDummy`. Because there is no active rendering pipeline, Godot **will not** automatically evaluate complex CSG boolean operations (`operation = 2` / SUBTRACTION). Tests that rely on holes cut into `CSGCombiner3D` walls will fail because the walls remain solid.
>
> **Fix:** In your test `_ready()` function, recursively iterate over all `CSGShape3D` nodes and manually call `node.get_meshes()`. This forces the engine to synchronously compute the CSG meshes and construct the updated collision shape (the `ConcavePolygonShape3D`).

> [!WARNING]
> **`intersect_point` vs `ConcavePolygonShape3D`**
> Never use `PhysicsDirectSpaceState3D.intersect_point()` to test if a point is "inside a hole" or "blocked by a CSG wall". CSG geometry generates `ConcavePolygonShape3D` (a triangle mesh). Godot's point-containment logic for concave trimeshes is highly unreliable and will frequently return false positives (reporting the point is blocked) when the point is located perfectly in the empty doorway space between two adjacent wall faces.
>
> **Fix:** Always use `intersect_ray()` (Raycasting) passing completely through the doorway opening. If the doorway is correctly subtracted, the raycast will return empty. This perfectly simulates a character walking through the door and is 100% robust.

> [!CAUTION]
> **`NavigationRegion3D.bake_navigation_mesh()` is asynchronous by default**
> It defaults to `on_thread = true` - it kicks off baking on a background thread and returns immediately, it does NOT block until the navmesh is ready. Any enemy that starts pathing (sets `NavigationAgent3D.target_position`) before baking finishes gets stuck: since the position doesn't change frame to frame, `NavigationAgent3D` never notices anything changed and never retries the query once the mesh actually becomes available - the enemy silently never moves, for the rest of the run. A fixed-delay guess ("surely N seconds is long enough") is not a fix - it can still lose the race on slower hardware or as the baked geometry grows (this project bakes all 10 floors of the hotel in one pass).
>
> **Fix:** `await` the region's own `bake_finished` signal after calling `bake_navigation_mesh()`, and only start any AI pathing once it fires (`hotel_level_generator.gd` does this, then calls `get_tree().call_group("enemies", "_on_navmesh_ready")` so every spawned enemy starts patrolling at the actual right moment regardless of how long baking took).

> [!IMPORTANT]
> **Multi-Floor Wall Overlapping & Doorway Architecture**
> When dealing with looped or stacked levels (like the P.T. staircase), **NEVER** extend a block's wall height (`StairsSouthWall`) into the next floor (e.g. making it 7m tall), and **NEVER** use overlapping boxes (like a `StairsSouthWallTop` addition). Doing so creates **non-manifold overlapping geometry**, which completely breaks Godot's CSG subtraction (`operation = 2`).
> **The Rule:** Each stair block's walls must strictly end at the floor height (4.5m). When a player climbs up from Floor N and exits at Y=4.5, they are exiting through the wall of **Floor N+1**. Therefore, `DoorHoleWest` (the upper exit) is located at the bottom (Y=1.05) of Floor N+1's block, piercing Floor N+1's wall to let the Floor N player out.
