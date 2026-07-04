# scripts/player/player_controller.gd
class_name PlayerController
extends CharacterBody3D

@onready var movement: PlayerMovement = $PlayerMovement
@onready var camera_comp: PlayerCamera = $PlayerCamera
@onready var interaction: PlayerInteraction = $PlayerInteraction
@onready var weapon: PlayerWeapon = $PlayerWeapon

func _ready() -> void:
    var hud = null
    if get_tree().current_scene:
        hud = get_tree().current_scene.find_child("HUD", true, false)
    if not hud:
        hud = get_node_or_null("../HUD")
        
    if hud:
        var left = hud.find_child("LeftJoystick", true, false)
        var right_zone = hud.find_child("RightZone", true, false)
        if left: left.input_vector_changed.connect(_on_left_joystick_changed)
        if right_zone: right_zone.swipe_dragged.connect(_on_right_swipe_dragged)
        
        var interact_btn = hud.find_child("InteractButton", true, false)
        if interact_btn:
            interaction.interact_btn = interact_btn
            interact_btn.pressed.connect(interaction.try_interact)

func _input(event: InputEvent) -> void:
    camera_comp.process_input(event)
        
    if event is InputEventScreenTouch and event.pressed and event.double_tap:
        weapon.shoot()
        
    if camera_comp.is_desktop and event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_E:
            interaction.try_interact()
        elif event.keycode == KEY_I:
            var hud = get_tree().current_scene.find_child("HUD", true, false)
            if not hud: hud = get_node_or_null("../HUD")
            if hud:
                var inv_ui = hud.find_child("InventoryUI", true, false)
                if inv_ui and inv_ui.has_method("open"):
                    inv_ui.open()
        elif event.keycode == KEY_V:
            if GameStateManager.current_state == GameStateManager.GameState.SPECTATOR:
                GameStateManager.change_state(GameStateManager.GameState.EXPLORING)
            else:
                GameStateManager.change_state(GameStateManager.GameState.SPECTATOR)

func _physics_process(delta: float) -> void:
    if Input.is_action_just_pressed("shoot") and camera_comp.is_desktop:
        weapon.shoot()
        
    movement.process_movement(delta)

func _on_left_joystick_changed(vector: Vector2) -> void:
    movement.set_move_input(vector)

func _on_right_swipe_dragged(relative: Vector2) -> void:
    camera_comp.process_swipe(relative)

# Helper methods to maintain compatibility with external calls (like vhs_tape.gd calling collect_tape or cerberus_ai)
func collect_tape() -> void:
    interaction.collect_tape()

