# scripts/levels/hotel_level.gd
extends Node3D

var cerberus_scene = preload("res://entities/enemies/cerberus/cerberus.tscn")
@onready var enemies_node = $Enemies

func _ready():
    GameStateManager.enemy_spawned.connect(_on_enemy_spawned)
    
    # Десктоп-релиз мыши по ESC
    if OS.get_name() in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
        pass

func _input(event):
    if event.is_action_pressed("ui_cancel"):
        if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        else:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_enemy_spawned():
    var cerberus = cerberus_scene.instantiate()
    enemies_node.add_child(cerberus)
    # Точка спавна на выходе из ресепшена
    cerberus.global_position = Vector3(0, 1, -15) 
