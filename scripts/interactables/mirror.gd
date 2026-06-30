extends Node3D

var has_triggered = false

func _on_area_3d_body_entered(body: Node3D) -> void:
    if not has_triggered and body.is_in_group("player"):
        has_triggered = true
        var thought = "Это... мое лицо? На рубашке приколот бейдж: «АЛЕКС».\nЯ помню, как стрелять из лазера, но абсолютно не помню, как я здесь очутился."
        if DialogSystem.has_method("show_thought"):
            DialogSystem.show_thought(thought, 8.0)

@onready var viewport: SubViewport = $SubViewport
@onready var mirror_cam: Camera3D = $SubViewport/Camera3D
@onready var surface: MeshInstance3D = $Surface

var player_cam: Camera3D = null

func _ready() -> void:
    # Assign the viewport texture to the surface material
    var mat = StandardMaterial3D.new()
    mat.albedo_texture = viewport.get_texture()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    
    # Flip UV x because it's a mirror
    mat.uv1_scale = Vector3(-1, 1, 1)
    
    surface.material_override = mat

func _process(_delta: float) -> void:
    if not player_cam:
        var p = get_tree().get_first_node_in_group("player")
        if p and p.has_node("CameraRig/Camera3D"):
            player_cam = p.get_node("CameraRig/Camera3D")
    
    if player_cam:
        # Calculate mirrored transform
        var cam_global = player_cam.global_transform
        
        # We need the camera relative to the mirror
        var local_cam = global_transform.affine_inverse() * cam_global
        
        # Mirror across Z axis (mirror plane is XY, normal is +Z)
        var mirrored_local = local_cam
        mirrored_local.origin.z = -mirrored_local.origin.z
        
        # Mirror the basis vectors
        mirrored_local.basis.x.z = -mirrored_local.basis.x.z
        mirrored_local.basis.y.z = -mirrored_local.basis.y.z
        mirrored_local.basis.z.x = -mirrored_local.basis.z.x
        mirrored_local.basis.z.y = -mirrored_local.basis.z.y
        
        mirror_cam.global_transform = global_transform * mirrored_local
        # Ensure cull mask sees the player (Layer 2)
        mirror_cam.cull_mask = player_cam.cull_mask | 2
