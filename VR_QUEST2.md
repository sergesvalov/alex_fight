# VR Адаптация Alex Fight → Oculus Quest 2

> **Статус:** Не начато (план составлен 2026-07-06)  
> **Движок:** Godot 4.7 · **Платформа:** Meta Quest 2 (Android ARM64, OpenXR)

---

## Dual-Mode: одна кодовая база → два APK

**Да, обе версии можно поддерживать одновременно** — телефонный APK и VR-сборку для Quest 2 — без форков и веток.

### Как это работает

Стратегия — **runtime-детект XR** при старте игры:

```gdscript
# player_controller.gd — _ready()
var xr_interface = XRServer.find_interface("OpenXR")
if xr_interface and xr_interface.initialize():
    get_viewport().use_xr = true
    is_vr = true           # включить VR-ветку во всех компонентах
else:
    is_vr = false          # обычный режим, всё как сейчас
```

- На **телефоне**: `find_interface("OpenXR")` вернёт `null` → запускается плоский режим, весь текущий код работает как есть
- На **Quest 2**: OpenXR инициализируется → VR-режим, активируется XR-риг

Переменная `is_vr: bool` передаётся во все компоненты (движение, камера, оружие, HUD) и переключает поведение.

### Два export preset'а в одном `export_presets.cfg`

| Preset | Для чего | Ключевые отличия |
|--------|----------|-----------------|
| `Android Phone` | Смартфон | без XR-плагина, `xr_mode=0`, APK ~меньше |
| `Android Quest 2` | Oculus | с плагином `godot_openxr_vendors`, `xr_mode=1` |

Оба билдятся из **одной и той же** кодовой базы. Разница только в export preset.

### Структура Player (dual-mode)

Вместо замены `Camera3D` на `XRCamera3D` — держать **оба узла**, активировать нужный:

```
Player (CharacterBody3D)
├── CameraRig (Node3D)             ← телефон/PC
│   └── Camera3D  [current=false]
└── XROrigin3D                     ← Quest 2
    ├── XRCamera3D [current=false]
    ├── XRController3D (left)
    └── XRController3D (right)
        └── WeaponHolder
            └── LaserPistol
```

В `_ready()` активируется либо `Camera3D.current = true`, либо `XRCamera3D.current = true` — в зависимости от `is_vr`.

### HUD (dual-mode)

```
HUD (CanvasLayer)        ← показывать только если not is_vr
VR_HUD (Node3D)          ← SubViewport-квад перед лицом, только если is_vr
```

Оба существуют в сцене, нужный показывается при старте.

---

---

## Концепция VR-версии

Коридорный шутер/хоррор идеально ложится на VR: узкие коридоры гостиницы «Сибирь» создают клаустрофобию, а P.T.-loop с бесконечными лестницами в шлеме будет ощущаться значительно страшнее. Оружие держится в правой руке физически — игрок целится рукой, а не взглядом.

Игровая логика (уровни, враги, нарратив) **не меняется**. Меняются только: Player-риг, ввод и HUD.

---

## Что нужно изменить

### 1. Настройка проекта

**`project.godot`** — добавить:
```ini
[xr]
openxr/enabled=true
openxr/default_action_map="res://openxr_action_map.tres"
```

**Плагин:** установить `Godot OpenXR Vendors` через AssetLib (или вручную в `addons/godot_openxr_vendors`). Это официальный Meta-плагин для Godot 4.

**`export_presets.cfg`** — в секцию `[preset.0.options]` добавить:
```ini
xr_features/xr_mode=1    # OpenXR
package/min_sdk=29        # Quest требует API 29+
package/target_sdk=32
```

**Создать `openxr_action_map.tres`** — маппинг действий контроллеров:
- Левый стик → `move` (движение)
- Правый триггер → `shoot` (стрельба)
- Правый стик → `aim` (опционально, поворот)

---

### 2. VR Player Rig (главное изменение)

Текущая структура `player.tscn`:
```
Player (CharacterBody3D)
└── CameraRig (Node3D)
    └── Camera3D           ← обычная камера
        └── WeaponHolder
            └── LaserPistol
```

Нужная VR-структура:
```
Player (CharacterBody3D)
└── XROrigin3D                          ← ЗАМЕНЯЕТ CameraRig
    ├── XRCamera3D                      ← ЗАМЕНЯЕТ Camera3D (трекинг головы)
    │   ├── Flashlight
    │   ├── RayCastGun                  ← для взаимодействия взглядом (опционально)
    │   └── RayCast3D
    ├── XRController3D  (left_hand)     ← левый контроллер
    └── XRController3D  (right_hand)    ← правый контроллер
        └── WeaponHolder                ← ПЕРЕНЕСТИ СЮДА
            └── LaserPistol
```

**Важно:** `XROrigin3D` — это «точка стояния» игрока. Физический `CharacterBody3D` перемещается кодом, а XROrigin следует за ним.

---

### 3. Изменения в скриптах компонентов

#### `player_camera.gd`
- В VR-режиме ручной поворот камеры **отключить** — XR-движок делает это сам через IMU шлема
- Определять режим через `XRServer.primary_interface != null`
- Сохранить мышиный fallback для PC:

```gdscript
func _ready() -> void:
    is_vr = XRServer.primary_interface != null and XRServer.primary_interface.is_initialized()
    if not is_vr:
        is_desktop = OS.get_name() in ["Windows", "macOS", "Linux", ...]
        if is_desktop:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func process_input(event: InputEvent) -> void:
    if is_vr:
        return  # XR сам вращает камеру
    # ... старая логика мыши
```

#### `player_movement.gd`
- Читать `move_input` с **левого стика** контроллера через `XRController3D`
- Направление движения — по горизонтальной проекции **XRCamera3D**, а не по `player.transform.basis`
- WASD fallback для PC остаётся:

```gdscript
# Получить направление движения в VR
func _get_vr_move_direction(input: Vector2) -> Vector3:
    var head = xr_camera  # ссылка на XRCamera3D
    var flat_basis = head.global_transform.basis
    flat_basis.y = Vector3.ZERO  # убрать наклон головы
    flat_basis = flat_basis.orthonormalized()
    return (flat_basis.x * input.x + flat_basis.z * input.y).normalized()
```

**Locomotion:** оставить smooth (стик), добавить vignette-эффект при движении для снижения укачивания. Teleport-режим разрушит хоррор-атмосферу.

#### `player_weapon.gd`
- `RayCastGun` перенести на правый контроллер (не голову) — прицеливание рукой
- Стрельба по нажатию `trigger` на правом `XRController3D`:

```gdscript
@onready var right_controller: XRController3D = get_parent().get_node("XROrigin3D/XRController3D_right")

func _ready() -> void:
    if right_controller:
        right_controller.button_pressed.connect(_on_controller_button)

func _on_controller_button(button_name: String) -> void:
    if button_name == "trigger_click":
        shoot()
```

- Отдача: tween-анимация позиции `WeaponHolder` вместо кручения `CameraRig`

#### `player_controller.gd`
- Добавить инициализацию XR в `_ready()`:

```gdscript
func _ready() -> void:
    var xr_interface = XRServer.find_interface("OpenXR")
    if xr_interface and xr_interface.initialize():
        get_viewport().use_xr = true
        # VR-режим активен
    # ... остальная инициализация
```

---

### 4. World-Space HUD

**Проблема:** `CanvasLayer` (2D HUD) не отображается в VR — он рендерится в 2D поверх экрана, а в режиме стерео экрана «нет».

**Решение:** SubViewport → текстура → QuadMesh перед лицом игрока.

```
XRCamera3D
└── VR_HUD (Node3D, позиция ~0.5м вперёд, чуть ниже центра)
    └── MeshInstance3D (QuadMesh ~0.4×0.2м)
        └── StandardMaterial3D (albedo_texture = SubViewport.get_texture())
            SubViewport (рендерит оригинальный HUD-контент)
```

- HUD-виджеты (HealthBar, HeatBar, TapeCounter) переносятся внутрь SubViewport без изменений
- SubViewport рендерится в 2D-текстуру, которая «приклеена» к камере в 3D

---

### 5. Производительность (Quest 2 ограничения)

Quest 2 — мобильный чип (Snapdragon XR2). Критичные настройки:

| Параметр | Значение | Почему |
|----------|----------|--------|
| Рендерер | `mobile` (оставить) | `forward_plus` не потянет |
| Fixed FPS | **72 fps** (фиксировать) | Стандарт Meta, нет VR-sick |
| Render Scale | `0.75` (уже стоит) | Снижает нагрузку на GPU |
| Occlusion Culling | `true` (уже стоит) | Критично для коридоров |
| Shadow quality | Отключить или `Low` | Дорого на мобиле |
| Fog | Отключить | Нет поддержки в `mobile` |

Добавить в `project.godot`:
```ini
[display]
window/vsync/vsync_mode=0   # отключить vsync, Meta управляет frame pacing

[rendering]
vrs/mode=1                  # Variable Rate Shading (Quest 2 поддерживает)
```

---

### 6. Сборка и деплой

```bash
# Сборка APK (из Godot Editor: Project → Export → Android)
# или через Jenkins:
godot --headless --export-release "Android" build/alex_fight_vr.apk

# Деплой на Quest 2 через ADB (устройство в Developer Mode):
adb install build/alex_fight_vr.apk

# Или через Meta Developer Hub (GUI)
```

Для публикации в Meta Horizon Store — отдельный процесс верификации.  
Для тестирования достаточно включить **Developer Mode** на устройстве и sideload через ADB.

---

## Что НЕ меняется

- `hotel_level_generator.gd` — уровень без изменений
- `cerberus_ai.gd` — ИИ врага не трогаем
- Все сцены уровней, блоки, нарратив, кассеты
- `EventBus`, `GameStateManager`, `AudioManager`, `SaveManager`

---

## Порядок выполнения

- [ ] Установить плагин Godot OpenXR Vendors
- [ ] Настроить `project.godot` + `openxr_action_map.tres`
- [ ] Переделать `player.tscn`: CameraRig → XROrigin3D + XRCamera3D + XRController3D×2
- [ ] Обновить `player_camera.gd` — VR/non-VR детект
- [ ] Обновить `player_movement.gd` — стик + направление по голове
- [ ] Обновить `player_weapon.gd` — правая рука + триггер
- [ ] Обновить `player_controller.gd` — инит XR интерфейса
- [ ] Создать `vr_hud.tscn` — world-space HUD через SubViewport
- [ ] Настроить `export_presets.cfg` для Meta
- [ ] Тест в XR-эмуляторе Godot (без шлема)
- [ ] Тест на реальном Quest 2

---

## Полезные ссылки

- [Godot 4 OpenXR документация](https://docs.godotengine.org/en/stable/tutorials/xr/index.html)
- [Godot OpenXR Vendors (Meta плагин)](https://github.com/GodotVR/godot_openxr_vendors)
- [Meta Quest Developer Hub](https://developer.oculus.com/meta-quest-developer-hub/)
- [Godot XR Tools (готовые компоненты)](https://github.com/GodotVR/godot-xr-tools)
