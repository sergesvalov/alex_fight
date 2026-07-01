extends SubViewportContainer

@onready var minimap_camera: Camera3D = $SubViewport/MinimapCamera

var player: Node3D = null

func _ready() -> void:
    # Try to find the player in the tree
    var players = get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        player = players[0]
    else:
        # Fallback
        if get_tree().current_scene:
            player = get_tree().current_scene.find_child("Player", true, false)

func _process(_delta: float) -> void:
    if player and is_instance_valid(player) and minimap_camera:
        minimap_camera.global_transform.origin.x = player.global_transform.origin.x
        minimap_camera.global_transform.origin.z = player.global_transform.origin.z
        # Keep Y fixed
        minimap_camera.global_transform.origin.y = 3.9
