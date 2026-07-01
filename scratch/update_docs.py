import re

def update_readme():
    with open('README.md', 'r', encoding='utf-8') as f:
        content = f.read()
    
    old_double = re.search(r"### Сетка двойных номеров.*?```\n", content, re.DOTALL)
    if old_double:
        new_double = """### Сетка двойных номеров (левая сторона, `double_room.tscn`)

Шаг: **10.0 м** | Инстансы крепятся к точке `(−7.5, 0, Z_центр)`

| Инстанс | Z-центр | Z-диапазон | № двери |
|---------|---------|------------|---------|
| DoubleRoomL1 | `−5.0` | `0.0 .. −10.0` | 401 |
| DoubleRoomL2 | `−15.0` | `−10.0 .. −20.0` | 402 |
| DoubleRoomL3 | `−25.0` | `−20.0 .. −30.0` | 403 |
| DoubleRoomL4 | `−35.0` | `−30.0 .. −40.0` | 405 |
| DoubleRoomL5 | `−45.0` | `−40.0 .. −50.0` | 406 |
| DoubleRoomL6 | `−55.0` | `−50.0 .. −60.0` | 408 |

```
Z_L(n) = −5.0 − (n−1) × 10.0
```
"""
        content = content.replace(old_double.group(0), new_double)

    old_single = re.search(r"### Сетка одиночных номеров.*?```\n", content, re.DOTALL)
    if old_single:
        new_single = """### Сетка одиночных номеров (правая сторона, `single_room.tscn`)

Шаг: **6.0 м** | Инстансы крепятся к точке `(+6.5, 0, Z_центр)`

| Инстанс | Z-центр | Z-диапазон | № двери |
|---------|---------|------------|---------|
| SingleRoomR1 | `−3.0` | `0.0 .. −6.0` | 410 |
| SingleRoomR2 | `−9.0` | `−6.0 .. −12.0` | 411 |
| SingleRoomR3 | `−15.0` | `−12.0 .. −18.0` | 412 |
| SingleRoomR4 | `−21.0` | `−18.0 .. −24.0` | 413 |
| SingleRoomR5 | `−27.0` | `−24.0 .. −30.0` | 415 |
| SingleRoomR6 | `−33.0` | `−30.0 .. −36.0` | 416 |
| SingleRoomR7 | `−39.0` | `−36.0 .. −42.0` | 417 |
| SingleRoomR8 | `−45.0` | `−42.0 .. −48.0` | 420 |
| SingleRoomR9 | `−51.0` | `−48.0 .. −54.0` | 421 |

```
Z_R(n) = −3.0 − (n−1) × 6.0
```
"""
        content = content.replace(old_single.group(0), new_single)

    content = content.replace("Z_L(n) = -12.5 - (n-1)*12.5", "Z_L(n) = -5.0 - (n-1)*10.0")
    content = content.replace("Z_R(n) = -11.0 - (n-1)*8.0", "Z_R(n) = -3.0 - (n-1)*6.0")

    with open('README.md', 'w', encoding='utf-8') as f:
        f.write(content)

update_readme()
