# Hotel Level Generator Guide

This file provides architectural guidelines and debugging instructions for AI agents working on the hotel level generator in this project.

## Architecture & Responsibilities (NEW GENERATOR)

The previous architecture relied on external scripts drawing corridor walls dynamically while rooms lacked front walls. **This is NO LONGER TRUE.**

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

## Hotel Level Geometry Maps

Это абсолютная, математически идеальная карта гостиницы (Северный блок), полностью восстановленная по всем частям чертежа. 

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









## North Stairs Block Map (`blocks/north_stairs.tscn`)

Блок инстанциируется генератором: `inst.position = Vector3(1.05, 0, -30.0)`.

Преобразование координат: `global = local + inst.position`

### Ключевые координаты (глобальные)

| Элемент | Global X | Global Z | Y | Примечание |
|---------|----------|----------|---|------------|
| StairsEastWall | +4.65..+4.85 | -30.0..-25.1 | 0..4.5 | Восточная стена |
| StairsWestWall | -2.75..-2.55 | -30.0..-25.1 | 0..4.5 | Западная стена |
| StairsSouthWall | -2.75..+4.85 | -25.2..-25.1 | 0..4.5 | Южная стена (основная) |
| StairsSouthWallTop | -2.75..+4.85 | -25.2..-25.1 | 4.5..7.0 | Надставка над западной дверью |
| DoorHoleEast | +3.25..+4.45 | -25.2..-25.1 | 0..2.2 | **Нижний вход** |
| DoorHoleWest | -2.45..-1.15 | -25.2..-25.1 | 4.5..6.7 | **Верхний выход** |
| NELanding | +1.25..+3.65 | -30.0..-27.6 | **1.5** (сурф.) | Промежуточная площадка восток |
| NWLanding | -3.65..-1.25 | -30.0..-27.6 | **3.0** (сурф.) | Промежуточная площадка запад |

### Три пролёта лестницы

| Пролёт | Ось | Y нижний | Y верхний | Где |
|--------|-----|----------|-----------|-----|
| **EastFlight** | Z = -30.0..-27.6 | 0.0 (пол, у сев. стены) | 1.5 (NE Landing) | X = +3.25..+4.45 |
| **NorthFlight** | Z = -27.6..-25.2 | 1.5 (NE, восток) | 3.0 (NW, запад) | X = -1.25..+1.25 |
| **WestFlight** | Z = -30.0..-27.6 | 3.0 (NW Landing) | 4.5 (у сев. стены) | X = -4.45..-3.25 |

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
             (Y=4.5..6.7)                        (Y=0..2.2)
              upper exit                         lower entry
         global X: -1.75                              +3.85
```

### Вид сбоку — профиль высот (по центральной линии)

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

> [!NOTE]
> **Дверь Western (верхний выход)**: В коммите `6ee1310` ошибочно стояла на Y=0..2.2 (как входная). Правильная позиция: center Y=5.6, size Y=2.2 → дыра Y=4.5..6.7. Требует `StairsSouthWallTop` (надставку стены Y=4.5..7.0).

> [!WARNING]
> **Вырез в полу**: Генератор НЕ создаёт пол в X=[-2.55..+4.65], Z=[-30..-25.2]. Блок должен своими стенами замкнуть этот проём. `inst.position.X=1.05` центрирует блок (local X=[-3.7..+3.7]) в зоне дыры (global X=[-2.65..+4.75]).



Блок инстанциируется генератором: `inst.position = Vector3(1.05, 0, -30.0)`.

## Actual Geometry Maps



### Map at Floor Level (Y=0.0)
```text






























    #####################
       BBBBBBBB         #
       BBBBBBBB         #
       BBBBBBBB         #
       BBBBBBBB         #
       BBBBBBBB         #
              #         #
              #         #
              #         #
              ####DDD####
                        #
                        #
                        #
                        #
                        #
                        #
         CC  CC         D
        TCC TCC     WWW D
        TTT TTT     WWW #
    ####TTT#TTT#####WWW##
    #####################              #################
       BBBBBBBB         #              ##   #
       BBBBBBBB         #              ##   #
       BBBBBBBB         #              ##   #
       BBBBBBBB         #              ##DDD#
       BBBBBBBB         #              ##DDD#
              #         #              D
              #         #              D
              #         #              ##
              ####DDD####              #################
                        #              #################
                        #              ##
                        #              D
                        #              D
                        #              ##DDD#
                        #              ##DDD#
         CC  CC         D              ##   #
        TCC TCC     WWW D              ##   #
        TTT TTT     WWW #              ##   #
    ####TTT#TTT#####WWW##              #################
    ####TTT#TTT#####WWW##              #################
        TTT TTT     WWW #              ##   #
        TCC TCC     WWW D              ##   #
         CC  CC         D              ##   #
                        #              ##DDD#
                        #              ##DDD#
                        #              D
                        #              D
                        #              ##
                        #              #################
              ####DDD####              #################
              #         #              ##
              #         #              D
              #         #              D
       BBBBBBBB         #              ##DDD#
       BBBBBBBB         #              ##DDD#
       BBBBBBBB         #              ##   #
       BBBBBBBB         #              ##   #
       BBBBBBBB         #              ##   #
    #####################              #################
    #####################              #################
       BBBBBBBB         #              ##   #
       BBBBBBBB         #              ##   #
       BBBBBBBB         #              ##   #
       BBBBBBBB         #              ##DDD#
       BBBBBBBB         #              ##DDD#
              #         #              D
              #         #              D
              #         #              ##
              ####DDD####              #################
                        #              #################
                        #              ##
                        #              D
                        #              D
                        #              ##DDD#
                        #              ##DDD#
         CC  CC         D              ##   #
        TCC TCC     WWW D              ##   #
        TTT TTT     WWW #              ##   #
    ####TTT#TTT#####WWW##              #################
    #####################              #################
       BBBBBBBB         #              ##
       BBBBBBBB         #              D
       BBBBBBBB         #              D
       BBBBBBBB         #              ##DDD#
       BBBBBBBB         #              ##DDD#
              #         #              ##   #
              #         #              ##   #
              #         #              ##   #
              ####DDD####              #################
                        #              #################
                        #              ##   #
                        #              ##   #
                        #              ##   #
                        #              ##DDD#
                        #              ##DDD#
         CC  CC         D              D
        TCC TCC     WWW D              D
        TTT TTT     WWW #              ##
    ####TTT#TTT#####WWW##              #################
    ####TTT#TTT#####WWW##              #################
        TTT TTT     WWW #              ##   #
        TCC TCC     WWW D              ##   #
         CC  CC         D              ##   #
                        #              ##DDD#
                        #              ##DDD#
                        #              D
                        #              D
                        #              ##
                        #              #################
              ####DDD####
              #         #
              #         #
              #         #
       BBBBBBBB         #
       BBBBBBBB         #
       BBBBBBBB         #
       BBBBBBBB         #
       BBBBBBBB         #
    #####################








































```

### Map at 1 Meter (Y=1.0)
```text






























    #####################
              #         #
              #         #
              #         #
              #         #
              #         #
              #         #
              #         #
              #         #
              ####DDD####
                        #
                        #
                        #
                        #
                        #
                        #
                        D
                    WWW D
                    WWW #
    ################WWW##
    #####################              #################
              #         #              ##   #
              #         #              ##   #
              #         #              ##   #
              #         #              ##DDD#
              #         #              ##DDD#
              #         #              D
              #         #              D
              #         #              ##
              ####DDD####              #################
                        #              #################
                        #              ##
                        #              D
                        #              D
                        #              ##DDD#
                        #              ##DDD#
                        D              ##   #
                    WWW D              ##   #
                    WWW #              ##   #
    ################WWW##              #################
    ################WWW##              #################
                    WWW #              ##   #
                    WWW D              ##   #
                        D              ##   #
                        #              ##DDD#
                        #              ##DDD#
                        #              D
                        #              D
                        #              ##
                        #              #################
              ####DDD####              #################
              #         #              ##
              #         #              D
              #         #              D
              #         #              ##DDD#
              #         #              ##DDD#
              #         #              ##   #
              #         #              ##   #
              #         #              ##   #
    #####################              #################
    #####################              #################
              #         #              ##   #
              #         #              ##   #
              #         #              ##   #
              #         #              ##DDD#
              #         #              ##DDD#
              #         #              D
              #         #              D
              #         #              ##
              ####DDD####              #################
                        #              #################
                        #              ##
                        #              D
                        #              D
                        #              ##DDD#
                        #              ##DDD#
                        D              ##   #
                    WWW D              ##   #
                    WWW #              ##   #
    ################WWW##              #################
    #####################              #################
              #         #              ##
              #         #              D
              #         #              D
              #         #              ##DDD#
              #         #              ##DDD#
              #         #              ##   #
              #         #              ##   #
              #         #              ##   #
              ####DDD####              #################
                        #              #################
                        #              ##   #
                        #              ##   #
                        #              ##   #
                        #              ##DDD#
                        #              ##DDD#
                        D              D
                    WWW D              D
                    WWW #              ##
    ################WWW##              #################
    ################WWW##              #################
                    WWW #              ##   #
                    WWW D              ##   #
                        D              ##   #
                        #              ##DDD#
                        #              ##DDD#
                        #              D
                        #              D
                        #              ##
                        #              #################
              ####DDD####
              #         #
              #         #
              #         #
              #         #
              #         #
              #         #
              #         #
              #         #
    #####################








































```

### Map at Wall/Ceiling intersection (Y=4.0)
```text






























    #####################
              #         #
              #         #
              #         #
              #         #
              #         #
              #         #
              #         #
              #         #
              ###########
                        #
                        #
                        #
                        #
                        #
                        #
                        #
                        #
                        #
    #####################
    #####################              #################
              #         #              ##   #
              #         #              ##   #
              #         #              ##   #
              #         #              ######
              #         #              ######
              #         #              ##
              #         #              ##
              #         #              ##
              ###########              #################
                        #              #################
                        #              ##
                        #              ##
                        #              ##
                        #              ######
                        #              ######
                        #              ##   #
                        #              ##   #
                        #              ##   #
    #####################              #################
    #####################              #################
                        #              ##   #
                        #              ##   #
                        #              ##   #
                        #              ######
                        #              ######
                        #              ##
                        #              ##
                        #              ##
                        #              #################
              ###########              #################
              #         #              ##
              #         #              ##
              #         #              ##
              #         #              ######
              #         #              ######
              #         #              ##   #
              #         #              ##   #
              #         #              ##   #
    #####################              #################
    #####################              #################
              #         #              ##   #
              #         #              ##   #
              #         #              ##   #
              #         #              ######
              #         #              ######
              #         #              ##
              #         #              ##
              #         #              ##
              ###########              #################
                        #              #################
                        #              ##
                        #              ##
                        #              ##
                        #              ######
                        #              ######
                        #              ##   #
                        #              ##   #
                        #              ##   #
    #####################              #################
    #####################              #################
              #         #              ##
              #         #              ##
              #         #              ##
              #         #              ######
              #         #              ######
              #         #              ##   #
              #         #              ##   #
              #         #              ##   #
              ###########              #################
                        #              #################
                        #              ##   #
                        #              ##   #
                        #              ##   #
                        #              ######
                        #              ######
                        #              ##
                        #              ##
                        #              ##
    #####################              #################
    #####################              #################
                        #              ##   #
                        #              ##   #
                        #              ##   #
                        #              ######
                        #              ######
                        #              ##
                        #              ##
                        #              ##
                        #              #################
              ###########
              #         #
              #         #
              #         #
              #         #
              #         #
              #         #
              #         #
              #         #
    #####################








































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
- **P.T. Non-Euclidean Loop**: The game deliberately loads only ONE floor at a time to save resources. When traveling up or down stairs, `seamless_teleporter.gd` loops the player locally and changes the scene. The 10 floors DO NOT physically exist stacked on top of each other in the game.

## North Stairs Room Map (Coordinates)

The North Stairs room is an enclosed space located at the far North end of the vertical corridor.

**Global Coordinates (f_scale = 1.0):**
- **Center of the Room** (Approximate): `X = 1.05`, `Z = -27.5`
- **North Wall**: `Z = -30.1` (Provided by the global building `Wall_North`)
- **South Wall**: `Z = -25.1` (Provided by `StairsSouthWall`, with two door holes)
- **West Wall**: `X = -2.65` (Provided by `StairsWestWall`)
- **East Wall**: `X = 4.75` (Provided by `StairsEastWall`)
- **West Doorway**: Centered at `X = -1.75`, `Z = -25.1`, Width = `1.2m`.
- **East Doorway**: Centered at `X = 3.85`, `Z = -25.1`, Width = `1.2m`.
- **NW Landing**: 2.4m x 2.4m square, Height = 2.67m. Centered at `X = -1.35`, `Z = -28.8`.
- **NE Landing**: 2.4m x 2.4m square, Height = 1.33m. Centered at `X = 3.45`, `Z = -28.8`.
- **East Flight**: 1.2m wide (aligned with door). Rises from `Y = 0.0` at `Z = -25.2` (East Door) up to `Y = 1.33m` at `Z = -27.6` (NE Landing).
- **North Flight**: 2.4m deep. Rises from `Y = 1.33m` at `X = 2.25` (Edge of NE Landing) up to `Y = 2.67m` at `X = -0.15` (Edge of NW Landing).
- **West Flight**: 1.2m wide (aligned with door). Rises from `Y = 2.67m` at `Z = -27.6` (NW Landing) up to `Y = 4.0m` at `Z = -25.2` (West Door, Ceiling level).

**Schematic Map:**
```text
      Global North Wall (Z = -30.1)
      +-------------+-------------+-------------+
      |  NW LANDING <|| NORTH ||||<  NE LANDING |
      |  (2.4x2.4)  <|| STAIR ||||<  (2.4x2.4)  |
W     |  H = 2.67m  <|| UP TO NW|<   H = 1.33m  |     E
E     +-------------+-------------+-------------+     A
S (-2.65)| |||||||| | NORTH STAIRS| ||||||||||| |(4.75)S
T     |  | |||||||| | ROOM        | ||||||||||| |     T
      |  |WEST STAIR|             | |EAST STAIR |     |
W     |  |UP TO ROOF|             | | UP TO NE  |     W
A     |  | |||||||| |             | ||||||||||| |     A
L     |  | |||||||| |             | ||||||||||| |     L
L     |  +----------+             +-------------+     L
      |                                         |
      +----    -------------------------    ----+
       South Wall (Z = -25.1)
   West Door (X = -1.75)           East Door (X = 3.85)
           |                                |
                         VERTICAL CORRIDOR
```

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

> [!IMPORTANT]
> **Multi-Floor Wall Overlapping & Doorway Architecture**
> When dealing with looped or stacked levels (like the P.T. staircase), **NEVER** extend a block's wall height (`StairsSouthWall`) into the next floor (e.g. making it 7m tall), and **NEVER** use overlapping boxes (like `StairsSouthWallTop`). Doing so creates **non-manifold overlapping geometry**, which completely breaks Godot's CSG subtraction (`operation = 2`).
> **The Rule:** Each stair block's walls must strictly end at the floor height (4.5m). When a player climbs up from Floor N and exits at Y=4.5, they are exiting through the wall of **Floor N+1**. Therefore, `DoorHoleWest` (the upper exit) is located at the bottom (Y=1.05) of Floor N+1's block, piercing Floor N+1's wall to let the Floor N player out.
