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

3. **Mirroring for Shared Plumbing**:
   - Hotel plumbing is often shared between adjacent rooms. 
   - We achieve this by mirroring specific rooms along the `Z` axis (`scale.z = -1.0`).
   - For example, Double Room 403 is mirrored so its WC touches Double Room 405's WC at `Z = 0.0`.
   - Single Rooms 411, 413, 416, and 417 are mirrored to ensure their WCs align back-to-back with neighboring single rooms, or cross-corridor with double rooms.

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
  |          401          +-------D-------+-----------------------+ ROOM  |
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
