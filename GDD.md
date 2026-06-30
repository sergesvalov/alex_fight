# 📋 Game Design Document & Technical Architecture
## «ALEX FIGHT» — 3D-шутер | Godot 4.7 | Android

> **Версия документа:** 1.0  
> **Платформа:** Android (Vulkan Mobile)  
> **Движок:** Godot 4.7  
> **Жанр:** Коридорный 3D-шутер / Survival Horror  
> **Сеттинг:** Ретрофутуризм, Сибирь, Зима

---

## 1. 🎮 Игровой Цикл и Нарратив

### 1.1 Концепция и Сеттинг

Заброшенная провинциальная гостиница «Сибирь» в глухом сибирском городке. Снежная буря отрезала все пути. Герой — **полицейский без имени** — приходит в себя в одном из номеров. Память стёрта. В руках шотган с несколькими патронами.

**Ретрофутуристическая эстетика:**
- Оборудование 80-х с голографическими дисплеями
- CRT-мониторы, транслирующие помехи
- Кассетные проигрыватели с голо-проекцией
- Люминесцентные лампы, мигающие в такт тревожным событиям
- Смешение советской архитектуры с нео-технологиями
- P.T.-подобная неевклидова геометрия (бесконечные лестницы)

---

### 1.2 Core Gameplay Loop (Игровой Цикл)

```
┌─────────────────────────────────────────────┐
│           МИНУТА ИГРОВОГО ВРЕМЕНИ           │
│                                             │
│  [0:00] Исследование коридора               │
│    ↓ Найти предмет / записку / кассету      │
│  [0:20] Нарративный момент                  │
│    ↓ Голопроекция кассеты / текст / звук    │
│  [0:35] Угроза                              │
│    ↓ Монстр атакует / звук / тень           │
│  [0:45] Боевой контакт или Побег            │
│    ↓ Выстрел / Sprint / укрытие             │
│  [0:55] Ресурс / Прогресс                   │
│    ↓ Патроны / Ключ-карта / Выход           │
└─────────────────────────────────────────────┘
```

**Три кита геймплея:**

| Действие | Доля времени | Механика |
|---|---|---|
| 🔍 Исследование | 50% | Ходьба, осмотр объектов |
| 📼 Нарратив | 20% | Голо-кассеты, текстовые записки на CRT |
| 🔫 Стрельба | 30% | Лазерный пистолет, перегрев оружия, давление |

---

### 1.3 Нарративный Дизайн (Narrative Integration)

Сюжет подаётся **ненавязчиво**, не останавливая геймплей:

#### Три Видеокассеты (Ключевые Нарративные Точки)

**📼 Кассета #1 — "Личность"** *(номер 101)*
- Голопроекция: Судебное заседание, герой в зале суда
- Текст: *«Александр Нечаев. Уволен за превышение полномочий. 2031 год»*
- Геймплей: Найти в тумбочке первого номера

**📼 Кассета #2 — "Инцидент"** *(коридор 2-го этажа)*
- Голопроекция: Ночной лес, силуэт существа
- Текст: *«Они пришли из тайги. Гостиница — карантинная зона. Все мертвы»*
- Геймплей: Лежит рядом с телом охранника

**📼 Кассета #3 — "Выход"** *(ресепшен)*
- Голопроекция: Карта гостиницы с отмеченным выходом
- Текст: *«Боковая дверь. Код: 1987. Но ОНО охраняет выход»*
- Геймплей: Активирует финальный триггер — появление Цербера

#### Правила нарративного дизайна:
- Голопроекция длится **максимум 8 секунд** — игрок может прервать её движением
- Текст выводится **поверх HUD**, не блокируя обзор
- Во время просмотра кассеты герой остаётся уязвимым — напряжение сохраняется
- Записки на CRT-мониторах читаются в **режиме осмотра** (камера приближается)

---

### 1.4 Структура Уровня — Гостиница «Сибирь»

```
[СТАРТОВАЯ ТОЧКА: Номер 208]
        ↓
[Коридор 2-го этажа] → Кассета #1 (Номер 101)
        ↓
[Лестница]
        ↓
[Коридор 1-го этажа] → Кассета #2 (Охранник)
        ↓
[Ресепшен / Холл] → Кассета #3 + Код двери
        ↓
[ФИНАЛЬНАЯ АРЕНА: Вестибюль] ← МОНСТР-ЦЕРБЕР
        ↓
[ВЫХОД / Конец главы]
```

---

## 2. 🏗️ Архитектура Проекта в Godot 4.7

### 2.1 Структура Папок Проекта

```
res://
├── scenes/
│   ├── main/
│   │   ├── main_menu.tscn
│   │   └── loading_screen.tscn
│   ├── levels/
│   │   └── hotel_siberia/
│   │       ├── hotel_level.tscn          # Главная сцена уровня
│   │       ├── hotel_geometry.tscn       # Геометрия (MeshInstance3D)
│   │       └── hotel_nav.tscn            # NavMesh
│   ├── entities/
│   │   ├── player/
│   │   │   ├── player.tscn
│   │   │   └── player_camera.tscn
│   │   ├── enemies/
│   │   │   └── cerberus/
│   │   │       └── cerberus.tscn
│   │   └── interactables/
│   │       ├── vhs_tape.tscn             # Кассета
│   │       └── crt_monitor.tscn          # Монитор с запиской
│   ├── hud/
│   │   ├── hud.tscn
│   │   └── mobile_controls.tscn
│   └── fx/
│       ├── holo_projection.tscn          # Голопроекция кассеты
│       └── muzzle_flash.tscn
├── scripts/
│   ├── autoloads/        ← EventBus, GameStateManager, DialogSystem, MouseManager
│   ├── player/           ← Контроллер игрока (player_controller.gd)
│   ├── weapons/          ← Оружие (laser_pistol.gd)
│   ├── enemies/
│   │   ├── enemy_base.gd
│   │   └── cerberus_ai.gd
│   ├── interactables/
│   │   ├── vhs_tape.gd
│   │   └── interactable_base.gd
│   └── ui/
│       ├── hud_controller.gd
│       └── mobile_input.gd
├── assets/
│   ├── meshes/
│   ├── textures/
│   ├── audio/
│   │   ├── sfx/
│   │   └── music/
│   └── fonts/
├── shaders/
│   ├── hologram.gdshader
│   ├── crt_screen.gdshader
│   └── retro_fog.gdshader
└── project.godot
```

---

### 2.2 Дерево Сцен (Scene Hierarchy)

#### 🎬 hotel_level.tscn — Главная сцена уровня

```
HotelLevel (Node3D)
├── WorldEnvironment               ← Fog, Sky, глобальное освещение
├── DirectionalLight3D             ← Лунный свет сквозь окна
├── HotelGeometry (Node3D)
│   ├── StaticBody3D + MeshInstance3D  ← Стены, пол, потолок
│   ├── OccluderInstance3D         ← Оккультер для оптимизации
│   └── NavigationRegion3D         ← NavMesh для врагов
├── InteractableObjects (Node3D)
│   ├── VhsTape_1 (Area3D)         ← Кассета #1
│   ├── VhsTape_2 (Area3D)
│   ├── VhsTape_3 (Area3D)
│   └── ExitDoor (Area3D)          ← Дверь выхода
├── Enemies (Node3D)
│   └── Cerberus (CharacterBody3D) ← Появляется по триггеру
├── LightSources (Node3D)
│   ├── OmniLight3D [множество]    ← Люминесцентные лампы
│   └── SpotLight3D [множество]    ← Направленные прожекторы
├── Player (CharacterBody3D)       ← instanced из player.tscn
└── HUD (CanvasLayer)              ← instanced из hud.tscn
```

#### 👤 player.tscn — Игрок

```
Player (CharacterBody3D)
├── CollisionShape3D (CapsuleShape3D)
├── CameraRig (Node3D)
│   └── Camera3D
│       └── WeaponHolder (Node3D)
│           └── LaserPistol (Node3D)
│               ├── MeshInstance3D
│               └── MuzzlePoint (Marker3D)   ← Точка выстрела
├── RayCast3D                       ← Для проверки взаимодействия
├── AnimationPlayer
└── AudioStreamPlayer3D             ← Шаги, дыхание
```

#### 👾 cerberus.tscn — Враг

```
Cerberus (CharacterBody3D)
├── CollisionShape3D
├── MeshInstance3D                  ← 3D-модель
├── AnimationPlayer
├── NavigationAgent3D               ← Навигация по NavMesh
├── RayCast3D                       ← Линия видимости к игроку
├── DetectionArea (Area3D)          ← Зона обнаружения (слух)
│   └── CollisionShape3D (SphereShape3D, radius=15)
└── AudioStreamPlayer3D
```

#### 📺 hud.tscn — HUD и Мобильное Управление

```
HUD (CanvasLayer)
├── GameHUD (Control)
│   ├── AmmoCounter (HBoxContainer)
│   │   ├── BulletIcon (TextureRect)
│   │   ├── ShotsLabel (Label)        ← "2/2"
│   │   └── AmmoLabel (Label)         ← "× 18"
│   ├── HealthBar (ProgressBar)
│   ├── InteractPrompt (Label)        ← "Нажмите для взаимодействия"
│   └── NarrativeText (RichTextLabel) ← Всплывающий текст кассет
└── MobileControls (Control)
    ├── LeftJoystick (Control)        ← Движение
    ├── RightJoystick (Control)       ← Обзор камеры
    ├── FireButton (TouchScreenButton)
    ├── InteractButton (TouchScreenButton)
    └── SprintButton (TouchScreenButton)
```

---

### 2.3 Синглтоны (Autoloads)

Зарегистрировать в **Project → Project Settings → Autoloads:**

#### `GameStateManager.gd`

```gdscript
# autoloads/GameStateManager.gd
extends Node

signal state_changed(new_state: GameState)
signal tape_collected(tape_id: int)
signal enemy_spawned

enum GameState {
    EXPLORING,      # Исследование
    READING,        # Просмотр кассеты / записки
    COMBAT,         # Боевой контакт
    DEAD,
    WIN
}

var current_state: GameState = GameState.EXPLORING
var tapes_found: Array[int] = []         # [0, 1, 2] — ID найденных кассет
var exit_code_known: bool = false
var cerberus_spawned: bool = false

func change_state(new_state: GameState) -> void:
    current_state = new_state
    state_changed.emit(new_state)

func collect_tape(tape_id: int) -> void:
    if tape_id not in tapes_found:
        tapes_found.append(tape_id)
        tape_collected.emit(tape_id)
        # Кассета #3 даёт код выхода
        if tape_id == 2:
            exit_code_known = true
        # После кассеты #3 — спауним Цербера
        if tapes_found.size() == 3 and not cerberus_spawned:
            cerberus_spawned = true
            enemy_spawned.emit()
```

#### `MouseManager.gd`

```gdscript
# autoloads/MouseManager.gd
extends Node

var target_look: Vector2 = Vector2.ZERO

# Отвечает за глобальную обработку относительного сенсорного ввода для управления камерой.
```

#### `DialogSystem.gd`

```gdscript
# autoloads/DialogSystem.gd
extends Node

signal narrative_started(tape_id: int)
signal narrative_ended

var is_playing: bool = false
var holo_scene: PackedScene = preload("res://scenes/fx/holo_projection.tscn")

# Данные кассет
const TAPE_DATA: Array[Dictionary] = [
    {
        "id": 0,
        "title": "Личность",
        "text": "Александр Нечаев. Уволен за превышение полномочий. 2031 год.",
        "duration": 7.0
    },
    {
        "id": 1,
        "title": "Инцидент",
        "text": "Они пришли из тайги. Гостиница — карантинная зона. Все мертвы.",
        "duration": 7.0
    },
    {
        "id": 2,
        "title": "Выход",
        "text": "Боковая дверь. Код: 1987. Но ОНО охраняет выход.",
        "duration": 8.0
    }
]

func play_tape(tape_id: int, spawn_position: Vector3) -> void:
    if is_playing:
        return
    is_playing = true
    GameStateManager.change_state(GameStateManager.GameState.READING)
    narrative_started.emit(tape_id)
    
    # Спаунить голограмму
    var holo_instance = holo_scene.instantiate()
    get_tree().current_scene.add_child(holo_instance)
    holo_instance.global_position = spawn_position
    holo_instance.set_tape_data(TAPE_DATA[tape_id])
    
    # Автоматически завершить через duration
    await get_tree().create_timer(TAPE_DATA[tape_id]["duration"]).timeout
    end_narrative()

func end_narrative() -> void:
    is_playing = false
    GameStateManager.change_state(GameStateManager.GameState.EXPLORING)
    narrative_ended.emit()
```

#### `AudioManager.gd`

```gdscript
# autoloads/AudioManager.gd
extends Node

var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer

const MUSIC = {
    "menu": preload("res://assets/audio/music/menu_theme.ogg"),
    "hotel_ambient": preload("res://assets/audio/music/hotel_ambient.ogg"),
    "combat": preload("res://assets/audio/music/combat_tense.ogg"),
}

func play_music(track_name: String, fade_duration: float = 1.0) -> void:
    # Плавная смена треков через Tween
    var tween = create_tween()
    tween.tween_property(music_player, "volume_db", -80, fade_duration)
    await tween.finished
    music_player.stream = MUSIC[track_name]
    music_player.play()
    tween = create_tween()
    tween.tween_property(music_player, "volume_db", 0, fade_duration)

func play_sfx(sfx: AudioStream, position: Vector3 = Vector3.ZERO) -> void:
    var player = AudioStreamPlayer3D.new()
    add_child(player)
    player.stream = sfx
    player.global_position = position
    player.play()
    player.finished.connect(player.queue_free)
```

---

## 3. 📱 Управление (Mobile UI/UX)

### 3.1 Архитектура Сенсорного Управления

```
MobileControls (Control — anchors: FULL RECT)
├── LeftZone (Control — left half of screen)
│   └── LeftJoystick (custom Control)    ← Движение WASD
└── RightZone (Control — right half of screen)
    ├── RightJoystick (custom Control)   ← Обзор камеры
    ├── FireButton (TouchScreenButton)   ← Нижний правый угол
    ├── InteractButton (TouchScreenButton) ← Центр правой зоны
    └── SprintButton (TouchScreenButton) ← Над FireButton
```

**Принцип: Левая половина = движение, Правая = всё остальное**

---

### 3.2 Виртуальный Джойстик (GDScript)

```gdscript
# scripts/ui/virtual_joystick.gd
class_name VirtualJoystick
extends Control

signal input_vector_changed(vector: Vector2)

@export var dead_zone: float = 0.15
@export var max_radius: float = 60.0
@export var joystick_mode: JoystickMode = JoystickMode.DYNAMIC

enum JoystickMode {
    FIXED,     # Фиксированный центр
    DYNAMIC    # Центр появляется там, где нажали
}

var touch_index: int = -1
var base_position: Vector2 = Vector2.ZERO
var stick_position: Vector2 = Vector2.ZERO
var current_vector: Vector2 = Vector2.ZERO

@onready var base_circle: TextureRect = $BaseCircle
@onready var stick_circle: TextureRect = $StickCircle

func _ready() -> void:
    base_circle.hide()
    stick_circle.hide()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        _handle_touch(event)
    elif event is InputEventScreenDrag:
        _handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
    if event.pressed and touch_index == -1:
        if _is_in_zone(event.position):
            touch_index = event.index
            base_position = event.position if joystick_mode == JoystickMode.DYNAMIC else get_rect().get_center()
            base_circle.global_position = base_position - base_circle.size / 2
            base_circle.show()
            stick_circle.show()
    elif not event.pressed and event.index == touch_index:
        _release()

func _handle_drag(event: InputEventScreenDrag) -> void:
    if event.index != touch_index:
        return
    var offset: Vector2 = event.position - base_position
    var clamped: Vector2 = offset.limit_length(max_radius)
    stick_position = base_position + clamped
    stick_circle.global_position = stick_position - stick_circle.size / 2
    
    current_vector = clamped / max_radius
    if current_vector.length() < dead_zone:
        current_vector = Vector2.ZERO
    input_vector_changed.emit(current_vector)

func _release() -> void:
    touch_index = -1
    current_vector = Vector2.ZERO
    base_circle.hide()
    stick_circle.hide()
    input_vector_changed.emit(Vector2.ZERO)

func _is_in_zone(pos: Vector2) -> bool:
    return get_global_rect().has_point(pos)
```

---

### 3.3 Контроллер Игрока с Мобильным Вводом

```gdscript
# scripts/player/player_controller.gd
class_name PlayerController
extends CharacterBody3D

# === Параметры ===
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var camera_sensitivity: float = 0.003    # Для тач-управления
@export var gravity: float = 9.8
@export var jump_height: float = 0.0             # Без прыжков в шутере

# === Узлы ===
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var ray_interact: RayCast3D = $RayCast3D
@onready var weapon: Node3D = $CameraRig/Camera3D/WeaponHolder/Shotgun
@onready var left_joystick: VirtualJoystick = %LeftJoystick
@onready var right_joystick: VirtualJoystick = %RightJoystick

# === Состояние ===
var move_input: Vector2 = Vector2.ZERO
var look_input: Vector2 = Vector2.ZERO
var is_sprinting: bool = false
var camera_x_rotation: float = 0.0
const CAMERA_X_LIMIT: float = PI / 2.5

func _ready() -> void:
    left_joystick.input_vector_changed.connect(_on_left_joystick_changed)
    right_joystick.input_vector_changed.connect(_on_right_joystick_changed)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # На десктопе для теста

func _on_left_joystick_changed(vector: Vector2) -> void:
    move_input = vector

func _on_right_joystick_changed(vector: Vector2) -> void:
    look_input = vector

func _physics_process(delta: float) -> void:
    if GameStateManager.current_state == GameStateManager.GameState.READING:
        return  # Заморозить управление во время чтения
    
    _apply_gravity(delta)
    _apply_movement(delta)
    _apply_look(delta)
    move_and_slide()

func _apply_movement(delta: float) -> void:
    var speed: float = sprint_speed if is_sprinting else walk_speed
    var direction: Vector3 = (
        transform.basis.x * move_input.x +
        transform.basis.z * move_input.y
    ).normalized()
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed

func _apply_look(delta: float) -> void:
    # Поворот тела по горизонтали
    rotate_y(-look_input.x * camera_sensitivity * 60 * delta)
    # Наклон камеры по вертикали
    camera_x_rotation -= look_input.y * camera_sensitivity * 60 * delta
    camera_x_rotation = clamp(camera_x_rotation, -CAMERA_X_LIMIT, CAMERA_X_LIMIT)
    camera_rig.rotation.x = camera_x_rotation

func _apply_gravity(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta

func try_interact() -> void:
    if ray_interact.is_colliding():
        var collider = ray_interact.get_collider()
        if collider.has_method("interact"):
            collider.interact(self)
```

---

### 3.4 Система Автоприцеливания (Aim Assist)

```gdscript
# scripts/player/aim_assist.gd
extends Node

@export var assist_radius_screen: float = 80.0  # Пиксели на экране
@export var assist_strength: float = 0.35        # 0 = нет, 1 = полный snap

@onready var camera: Camera3D = get_parent()

func get_aim_target() -> Node3D:
    var enemies = get_tree().get_nodes_in_group("enemies")
    var best_enemy: Node3D = null
    var best_distance: float = assist_radius_screen
    var screen_center: Vector2 = get_viewport().get_visible_rect().size / 2
    
    for enemy in enemies:
        if not is_instance_valid(enemy):
            continue
        # Проверяем, виден ли враг камерой
        var screen_pos: Vector2 = camera.unproject_position(enemy.global_position)
        var dist: float = screen_pos.distance_to(screen_center)
        if dist < best_distance:
            best_distance = dist
            best_enemy = enemy
    
    return best_enemy

func apply_assist(aim_direction: Vector3) -> Vector3:
    var target = get_aim_target()
    if not target:
        return aim_direction
    
    var to_target: Vector3 = (target.global_position - camera.global_position).normalized()
    return aim_direction.lerp(to_target, assist_strength)
```

---

## 4. 🤖 Логика ИИ Противников — Цербер

### 4.1 Конечный Автомат (State Machine)

```
┌─────────┐  вошёл в зону  ┌──────────┐  увидел  ┌───────┐
│  IDLE   │ ─────────────→ │  PATROL  │ ────────→ │ CHASE │
└─────────┘                └──────────┘           └───────┘
     ↑                           ↑  потерял            │
     │                           │  игрока              │ близко
     └───────────────────────────┘              ┌───────┘
                                                ↓
                                           ┌────────┐
                                           │ ATTACK │
                                           └────────┘
                                                │
                                     игрок убит / отбежал
                                                ↓
                                           ┌────────┐
                                           │ RETURN │ (возврат на точку)
                                           └────────┘
```

### 4.2 Скрипт Цербера

```gdscript
# scripts/enemies/cerberus_ai.gd
class_name CerberusAI
extends CharacterBody3D

# === Параметры ===
@export var idle_wait_time: float = 2.0
@export var patrol_speed: float = 3.0
@export var chase_speed: float = 6.5
@export var attack_range: float = 2.0
@export var detection_range: float = 12.0
@export var attack_damage: int = 40
@export var attack_cooldown: float = 1.5
@export var patrol_points: Array[Marker3D] = []

# === Узлы ===
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var detection_area: Area3D = $DetectionArea
@onready var ray_sight: RayCast3D = $RayCast3D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var audio: AudioStreamPlayer3D = $AudioStreamPlayer3D

# === Состояние ===
enum State { IDLE, PATROL, CHASE, ATTACK, RETURN, DEAD }
var current_state: State = State.IDLE
var player: CharacterBody3D = null
var spawn_position: Vector3
var current_patrol_index: int = 0
var attack_timer: float = 0.0
var idle_timer: float = 0.0
var gravity: float = 9.8

func _ready() -> void:
    add_to_group("enemies")
    spawn_position = global_position
    detection_area.body_entered.connect(_on_body_entered_detection)
    detection_area.body_exited.connect(_on_body_exited_detection)
    
    if patrol_points.size() > 0:
        _set_state(State.PATROL)
    else:
        _set_state(State.IDLE)

func _physics_process(delta: float) -> void:
    _apply_gravity(delta)
    attack_timer -= delta
    
    match current_state:
        State.IDLE:     _state_idle(delta)
        State.PATROL:   _state_patrol(delta)
        State.CHASE:    _state_chase(delta)
        State.ATTACK:   _state_attack(delta)
        State.RETURN:   _state_return(delta)
    
    move_and_slide()

# ── IDLE ──────────────────────────────────────────────────
func _state_idle(delta: float) -> void:
    anim.play("idle")
    idle_timer -= delta
    if idle_timer <= 0 and patrol_points.size() > 0:
        _set_state(State.PATROL)

# ── PATROL ────────────────────────────────────────────────
func _state_patrol(delta: float) -> void:
    if patrol_points.is_empty():
        _set_state(State.IDLE)
        return
    anim.play("walk")
    var target_point: Vector3 = patrol_points[current_patrol_index].global_position
    nav_agent.target_position = target_point
    _move_along_nav(patrol_speed)
    
    if global_position.distance_to(target_point) < 0.5:
        current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
        idle_timer = idle_wait_time
        _set_state(State.IDLE)

# ── CHASE ─────────────────────────────────────────────────
func _state_chase(delta: float) -> void:
    if not is_instance_valid(player):
        _set_state(State.RETURN)
        return
    anim.play("run")
    nav_agent.target_position = player.global_position
    _move_along_nav(chase_speed)
    
    # Потерял ли видимость?
    if not _has_line_of_sight():
        await get_tree().create_timer(3.0).timeout
        if not _has_line_of_sight():
            _set_state(State.RETURN)
            return
    
    # В радиусе атаки?
    if global_position.distance_to(player.global_position) <= attack_range:
        _set_state(State.ATTACK)

# ── ATTACK ────────────────────────────────────────────────
func _state_attack(_delta: float) -> void:
    if not is_instance_valid(player):
        _set_state(State.RETURN)
        return
    
    # Смотреть на игрока
    look_at(player.global_position, Vector3.UP)
    
    # Выход из атаки если игрок убежал
    if global_position.distance_to(player.global_position) > attack_range * 1.5:
        _set_state(State.CHASE)
        return
    
    if attack_timer <= 0.0:
        _perform_attack()
        attack_timer = attack_cooldown

func _perform_attack() -> void:
    anim.play("attack")
    audio.play()  # Звук рыка
    # Нанести урон
    if player.has_method("take_damage"):
        player.take_damage(attack_damage)

# ── RETURN ────────────────────────────────────────────────
func _state_return(_delta: float) -> void:
    nav_agent.target_position = spawn_position
    _move_along_nav(patrol_speed)
    if global_position.distance_to(spawn_position) < 0.5:
        player = null
        _set_state(State.IDLE)

# ── HELPERS ───────────────────────────────────────────────
func _move_along_nav(speed: float) -> void:
    var next_pos: Vector3 = nav_agent.get_next_path_position()
    var direction: Vector3 = (next_pos - global_position).normalized()
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed
    if direction != Vector3.ZERO:
        look_at(global_position + direction * Vector3(1, 0, 1), Vector3.UP)

func _apply_gravity(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta

func _has_line_of_sight() -> bool:
    if not is_instance_valid(player):
        return false
    ray_sight.target_position = ray_sight.to_local(player.global_position)
    ray_sight.force_raycast_update()
    if ray_sight.is_colliding():
        return ray_sight.get_collider() == player
    return false

func _set_state(new_state: State) -> void:
    current_state = new_state
    if new_state == State.CHASE:
        GameStateManager.change_state(GameStateManager.GameState.COMBAT)
        AudioManager.play_music("combat")

func _on_body_entered_detection(body: Node3D) -> void:
    if body.is_in_group("player") and current_state != State.ATTACK:
        player = body
        _set_state(State.CHASE)

func _on_body_exited_detection(body: Node3D) -> void:
    pass  # Проверяется через line of sight
    
func take_damage(amount: int) -> void:
    # Логика урона по врагу
    pass
```

---

## 5. 📱 Мобильная Оптимизация (Vulkan Mobile)

### 5.1 Настройки Project Settings

```
# project.godot — ключевые секции

[rendering]
renderer/rendering_method = "mobile"      # Vulkan Mobile
renderer/rendering_method.mobile = "gl_compatibility"  # Fallback
environment/defaults/default_environment = "res://default_env.tres"

[rendering.limits]
global_shader_variables/buffer_size = 65536

[physics]
3d/physics_engine = "Jolt Physics"        # Godot Jolt для Android
3d/default_gravity = 9.8

[display]
window/size/viewport_width = 1280
window/size/viewport_height = 720
window/stretch/mode = "canvas_items"
window/stretch/aspect = "keep"
```

---

### 5.2 Бюджет Полигонов и Draw Calls

| Объект | Макс. полигонов | Примечание |
|---|---|---|
| Главный герой (руки+оружие) | 3 000 | Видны всегда |
| Цербер | 5 000 | LOD: 2500 на дистанции |
| Комната гостиницы (статик) | 15 000 | Baked lighting |
| Пропсы (мебель, объекты) | 500–1000 / штука | Инстансинг |
| **Итого на кадр** | **< 30 000** | Целевой бюджет |
| **Draw Calls** | **< 150** | Цель для 60 FPS |

---

### 5.3 Освещение (Baked Lighting)

```
Стратегия освещения:
├── DirectionalLight3D (1 шт.)      → Dynamic, Realtime shadows ВЫКЛ
├── OmniLight3D (лампы, 10–15 шт.) → BAKED в LightmapGI
├── SpotLight3D (акценты, 5 шт.)   → BAKED
└── RealTime Light (1–2 шт. макс)  → Только для критических эффектов
                                       (мигающие лампы, вспышки)

LightmapGI настройки:
- Quality: Medium
- Max Texture Size: 2048
- Shadowmap Atlas Size: 2048
- Use Denoiser: true
```

---

### 5.4 Настройка Godot Jolt Physics

```gdscript
# В player_controller.gd — правильная инициализация физики
# Jolt лучше работает с CapsuleShape3D для CharacterBody3D

func _ready() -> void:
    # Установить правильный слой коллизий
    collision_layer = 1   # Слой "Player"
    collision_mask = 2    # Видит слой "World"
    
    # Jolt: отключить ненужные степени свободы
    # (настраивается в Inspector для CharacterBody3D)
    floor_stop_on_slope = true
    floor_max_angle = deg_to_rad(45)
    floor_snap_length = 0.1
```

---

### 5.5 Оптимизация для Android

**Текстуры:**
- Использовать **ETC2** сжатие для Android (ASTC для современных устройств)
- Макс. размер текстуры: **1024×1024** для мира, **512×512** для пропсов
- Нормал-мапы: **512×512**

**Шейдеры:**
- Избегать `discard` в фрагментных шейдерах (дорого на тайловых GPU)
- Холограмма и CRT-эффекты — только для близких объектов (distance fade)

**Geometry Instancing:**
- Все повторяющиеся объекты (стулья, двери, лампы) через `MultiMeshInstance3D`

**Occlusion Culling:**
- Разместить `OccluderInstance3D` на каждой стене-перегородке
- Включить: **Project Settings → Rendering → Occlusion Culling → Enabled = true**

**Target Performance:**
```
Устройство цель: Android 8.0+, Adreno 530 / Mali-G71
Целевой FPS: 60 стабильных
Разрешение рендера: 720p (масштабируется до экрана)
```

---

## 6. 🎨 Визуальный Стиль — Ретрофутуризм

### 6.1 Шейдер Голограммы

```gdshader
// shaders/hologram.gdshader
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform vec4 holo_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform float scan_speed : hint_range(0.1, 5.0) = 1.5;
uniform float scan_density : hint_range(10.0, 200.0) = 80.0;
uniform float flicker_speed : hint_range(0.0, 20.0) = 8.0;
uniform float alpha : hint_range(0.0, 1.0) = 0.7;

void fragment() {
    float scan_line = sin(UV.y * scan_density + TIME * scan_speed) * 0.5 + 0.5;
    float flicker = sin(TIME * flicker_speed) * 0.05 + 0.95;
    float edge_fade = 1.0 - abs(UV.x - 0.5) * 2.0;
    
    ALBEDO = holo_color.rgb * scan_line * flicker;
    ALPHA = alpha * scan_line * edge_fade * flicker;
}
```

### 6.2 Шейдер CRT-Монитора

```gdshader
// shaders/crt_screen.gdshader
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float curvature : hint_range(0.0, 1.0) = 0.15;
uniform float scan_line_opacity : hint_range(0.0, 1.0) = 0.3;
uniform float noise_strength : hint_range(0.0, 0.1) = 0.02;

void fragment() {
    vec2 uv = UV;
    
    // CRT-кривизна
    vec2 curved = uv - 0.5;
    curved *= 1.0 + dot(curved, curved) * curvature;
    uv = curved + 0.5;
    
    // Горизонтальные полосы сканлайна
    float scan = sin(uv.y * 800.0) * scan_line_opacity;
    
    // Шум
    float noise = fract(sin(dot(uv, vec2(12.9898, 78.233)) + TIME) * 43758.5453) * noise_strength;
    
    // RGB-смещение (хроматическая аберрация)
    vec4 color;
    color.r = texture(screen_texture, uv + vec2(0.001, 0.0)).r;
    color.g = texture(screen_texture, uv).g;
    color.b = texture(screen_texture, uv - vec2(0.001, 0.0)).b;
    color.a = 1.0;
    
    COLOR = color - vec4(scan) + vec4(noise);
}
```

### 6.3 Цветовая Палитра

| Цвет | HEX | Использование |
|---|---|---|
| Холодный синий | `#1A2A4A` | Основной фон, стены |
| Голо-циан | `#00E5FF` | Голограммы, интерфейс |
| Тусклый жёлтый | `#C8A84B` | Свет ламп, тёплые акценты |
| Красный тревога | `#FF2D2D` | Здоровье, опасность |
| Снежный белый | `#E8EEF4` | Снег снаружи, блики |
| Ржавый металл | `#4A3728` | Пол, двери |

---

## 7. 🗺️ Checklist для ИИ-Агента: Порядок Создания

> [!IMPORTANT]
> Следуй этому порядку строго. Каждый пункт — независимая задача.

### Фаза 1: Основа Проекта
- [ ] Создать структуру папок по схеме из раздела 2.1
- [ ] Настроить `project.godot` (Vulkan Mobile, Jolt Physics, разрешение)
- [ ] Создать и зарегистрировать все 5 Autoloads (раздел 2.3)

### Фаза 2: Игрок
- [ ] Создать `player.tscn` с иерархией из раздела 2.2
- [ ] Написать `player_controller.gd` (движение + взаимодействие)
- [ ] Создать `virtual_joystick.gd` и `hud.tscn`
- [ ] Реализовать `weapon_shotgun.gd` (стрельба + перезарядка)

### Фаза 3: Уровень
- [ ] Создать `hotel_level.tscn` — серая-боксовая геометрия (greybox)
- [ ] Разместить NavigationRegion3D и запечь NavMesh
- [ ] Разместить точки взаимодействия (VhsTape × 3, ExitDoor)
- [ ] Настроить освещение (1 Dynamic + LightmapGI для остальных)

### Фаза 4: Враг
- [ ] Создать `cerberus.tscn` с CharacterBody3D + NavigationAgent3D
- [ ] Написать `cerberus_ai.gd` — конечный автомат (раздел 4.2)
- [ ] Настроить триггер появления (после сбора 3 кассет)

### Фаза 5: Нарратив
- [ ] Создать `vhs_tape.gd` (interactable → вызов DialogSystem)
- [ ] Создать `holo_projection.tscn` с шейдером голограммы
- [ ] Настроить поток событий: Кассета #3 → выход → Цербер

### Фаза 6: Полировка
- [ ] Добавить шейдеры (hologram.gdshader, crt_screen.gdshader)
- [ ] Настроить аудио (ambient, combat, SFX шотгана)
- [ ] Оптимизация: OccluderInstance3D, LOD, Occlusion Culling
- [ ] Тест на Android (APK export через Godot Android Build)
