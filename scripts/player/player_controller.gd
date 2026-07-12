# scripts/player/player_controller.gd
class_name PlayerController
extends CharacterBody3D

@onready var movement: PlayerMovement = $PlayerMovement
@onready var camera_comp: PlayerCamera = $PlayerCamera
@onready var interaction: PlayerInteraction = $PlayerInteraction
@onready var weapon: PlayerWeapon = $PlayerWeapon

var is_vr: bool = false

func _ready() -> void:
    var xr_interface = XRServer.find_interface("OpenXR")
    if xr_interface and (xr_interface.is_initialized() or xr_interface.initialize()):
        print("OpenXR initialized successfully")
        get_viewport().use_xr = true
        is_vr = true
        
        # Setup VR cameras
        var xr_cam = $XROrigin3D/XRCamera3D
        xr_cam.current = true
        xr_cam.cull_mask = $CameraRig/Camera3D.cull_mask
        $CameraRig/Camera3D.current = false
        
        # Move WeaponHolder to RightController
        var weapon_holder = $CameraRig/Camera3D/WeaponHolder
        weapon_holder.get_parent().remove_child(weapon_holder)
        var right_hand = $XROrigin3D/RightController
        right_hand.add_child(weapon_holder)
        weapon_holder.position = Vector3.ZERO
        # Optional: rotate weapon so it aligns with the VR controller's natural pointing angle
        # Usually, an X rotation of roughly -40 to -60 degrees helps it feel like a gun in hand.
        # But for now, we'll zero it out and see if the user likes it.
        weapon_holder.rotation = Vector3(deg_to_rad(-45), 0, 0)
        
        # Connect VR controller buttons
        right_hand.button_pressed.connect(_on_right_controller_button_pressed)
        $XROrigin3D/LeftController.button_pressed.connect(_on_left_controller_button_pressed)
        
        # Move Flashlight to XRCamera3D
        var flashlight = $CameraRig/Camera3D/Flashlight
        flashlight.get_parent().remove_child(flashlight)
        $XROrigin3D/XRCamera3D.add_child(flashlight)
        
        # Setup VR HUD
        call_deferred("_setup_vr_hud")

    # Scale player to match config
    var p_scale = GlobalConfig.get_player_scale()
    var col_shape = get_node_or_null("CollisionShape3D")
    if col_shape and col_shape.shape is CapsuleShape3D:
        var new_shape = col_shape.shape.duplicate()
        new_shape.height *= p_scale
        new_shape.radius *= p_scale
        col_shape.shape = new_shape
        col_shape.position.y *= p_scale
        
    var cam_rig = get_node_or_null("CameraRig")
    if cam_rig:
        cam_rig.position.y *= p_scale

    var hud = null
    if get_tree().current_scene:
        hud = get_tree().current_scene.find_child("HUD", true, false)
    if not hud:
        hud = get_node_or_null("../HUD")
        
    if hud:
        var left = hud.find_child("LeftJoystick", true, false)
        var right_zone = hud.find_child("RightZone", true, false)
        if left: 
            left.input_vector_changed.connect(_on_left_joystick_changed)
            if is_vr: left.hide()
        if right_zone: 
            right_zone.swipe_dragged.connect(_on_right_swipe_dragged)
            if is_vr: right_zone.hide()
        
        var interact_btn = hud.find_child("InteractButton", true, false)
        if interact_btn:
            interaction.interact_btn = interact_btn
            interact_btn.pressed.connect(interaction.try_interact)
            if is_vr: interact_btn.hide()

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
    if Input.is_action_just_pressed("shoot") and camera_comp.is_desktop and not is_vr:
        weapon.shoot()
        
    if is_vr:
        var left_hand = get_node_or_null("XROrigin3D/LeftController")
        if left_hand and left_hand.get_tracker_name() != "":
            movement.set_move_input(left_hand.get_vector2("primary"))
            
        var right_hand = get_node_or_null("XROrigin3D/RightController")
        if right_hand and right_hand.get_tracker_name() != "":
            var right_joy = right_hand.get_vector2("primary")
            if abs(right_joy.x) > 0.1:
                rotate_y(-right_joy.x * 2.5 * delta)
        
    movement.process_movement(delta)

func _on_left_joystick_changed(vector: Vector2) -> void:
    movement.set_move_input(vector)

func _on_right_swipe_dragged(relative: Vector2) -> void:
    camera_comp.process_swipe(relative)

func _on_right_controller_button_pressed(button_name: String) -> void:
    if button_name == "trigger_click":
        weapon.shoot()
    elif button_name in ["ax_button", "primary_click", "grip_click", "b_button", "secondary_click"]:
        interaction.try_interact()

func _on_left_controller_button_pressed(button_name: String) -> void:
    if button_name in ["ax_button", "primary_click", "menu_button", "y_button", "secondary_click"]:
        var hud_node = null
        if get_tree().current_scene:
            hud_node = get_tree().current_scene.find_child("HUD", true, false)
        if not hud_node: hud_node = get_node_or_null("../HUD")
        if hud_node:
            var inv_ui = hud_node.find_child("InventoryUI", true, false)
            if inv_ui and inv_ui.has_method("open"):
                inv_ui.open()

# Helper methods to maintain compatibility with external calls (like vhs_tape.gd calling collect_tape or cerberus_ai)
func collect_tape() -> void:
    interaction.collect_tape()

func _setup_vr_hud() -> void:
    var hud = null
    if get_tree().current_scene:
        hud = get_tree().current_scene.find_child("HUD", true, false)
    if not hud:
        hud = get_node_or_null("../HUD")
        
    if hud:
        var vp = SubViewport.new()
        vp.transparent_bg = true
        vp.size = Vector2i(1280, 720)
        vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        var hud_parent = hud.get_parent()
        hud_parent.remove_child(hud)
        vp.add_child(hud)
        hud_parent.add_child(vp)
        
        var quad = MeshInstance3D.new()
        var mesh = QuadMesh.new()
        mesh.size = Vector2(0.8, 0.45)
        var mat = StandardMaterial3D.new()
        mat.albedo_texture = vp.get_texture()
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mesh.material = mat
        quad.mesh = mesh
        
        $XROrigin3D/XRCamera3D.add_child(quad)
        quad.position = Vector3(0, -0.2, -0.6)
