# scripts/player/weapon_shotgun.gd
class_name WeaponShotgun
extends Node3D

@onready var muzzle_point: Marker3D = $MuzzlePoint
@export var damage: int = 40
@export var range: float = 20.0

func _ready():
    # Создать MuzzlePoint если его нет
    if not muzzle_point:
        var marker = Marker3D.new()
        marker.name = "MuzzlePoint"
        add_child(marker)
        marker.position = Vector3(0, 0, -1)
        muzzle_point = marker

func _input(event):
    if GameStateManager.current_state != GameStateManager.GameState.COMBAT and GameStateManager.current_state != GameStateManager.GameState.EXPLORING:
        return
        
    # Временный хак для тестирования на ПК
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        fire()
    elif event.is_action_pressed("reload"):
        InventoryManager.reload()

func fire():
    if InventoryManager.spend_shot():
        # Play sound
        # AudioManager.play_sfx(preload("res://assets/audio/sfx/shotgun_fire.ogg"), global_position)
        print("BAM! (Shot fired)")
        
        # Raycast for hit
        var space_state = get_world_3d().direct_space_state
        var cam = get_viewport().get_camera_3d()
        if cam:
            var from = cam.global_position
            var to = from - cam.global_transform.basis.z * range
            var query = PhysicsRayQueryParameters3D.create(from, to)
            query.collision_mask = 2 | 4 # Слой врагов и геометрии
            
            var result = space_state.intersect_ray(query)
            if result:
                if result.collider.has_method("take_damage"):
                    result.collider.take_damage(damage)
                    print("Hit target!")
    else:
        print("Click! (Out of ammo)")
