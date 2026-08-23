class_name PlayerInteraction
extends Node

@onready var player: CharacterBody3D = get_parent()
@onready var ray_interact: RayCast3D = get_parent().get_node("CameraRig/Camera3D/RayCast3D")
@onready var camera: Camera3D = get_parent().get_node("CameraRig/Camera3D")

var tapes_collected: int = 0
var max_tapes: int = 3

# Android's camera is locked to horizontal-only look (player_camera.gd::process_swipe() drops
# the vertical component of every swipe), so ray_interact - a fixed dead-ahead ray from the
# camera - can only ever reach whatever single interactable happens to sit at the exact height
# the player's eye level lines up with; anything higher or lower is simply unreachable by aim.
# Windows/macOS/Linux and VR keep full look control, so they never need the fallback below.
var is_android: bool = false

const PROXIMITY_RADIUS: float = 3.0
# Roughly a 120-degree forward cone (cos(60°) = 0.5) - wide enough to be forgiving without
# grabbing something behind the player just because it's the closest thing nearby.
const PROXIMITY_FORWARD_DOT: float = 0.5

func _ready() -> void:
    is_android = OS.get_name() == "Android"
    update_tapes_ui()

var interact_btn: Control = null

func _process(_delta: float) -> void:
    var can_interact = _find_interactable() != null
    if interact_btn:
        interact_btn.visible = can_interact

func try_interact() -> void:
    var target = _find_interactable()
    if target:
        target.interact(player)

# Raycast first - identical to the old behavior on every platform. Only falls back to a
# proximity search when the ray misses AND we're on Android, so Windows/macOS/Linux/VR are
# completely unaffected by anything below.
func _find_interactable() -> Node:
    if ray_interact.is_colliding():
        var collider = ray_interact.get_collider()
        if collider and collider.has_method("interact"):
            return collider
    if is_android:
        return _find_nearby_interactable()
    return null

# Picks the closest interactable within PROXIMITY_RADIUS that's roughly in front of the player -
# lets Android players interact just by standing near and facing something in general, without
# needing to aim vertically at it at all.
func _find_nearby_interactable() -> Node:
    var space_state = player.get_world_3d().direct_space_state
    var shape = SphereShape3D.new()
    shape.radius = PROXIMITY_RADIUS

    var query = PhysicsShapeQueryParameters3D.new()
    query.shape = shape
    query.transform = Transform3D(Basis(), camera.global_position)
    query.collision_mask = 4 # same layer ray_interact already checks (see player.tscn)
    query.collide_with_areas = true
    query.collide_with_bodies = true
    query.exclude = [player.get_rid()]

    var results = space_state.intersect_shape(query, 32)
    var forward = -camera.global_transform.basis.z.normalized()

    var best: Node = null
    var best_dist_sq := INF
    for result in results:
        var body = result["collider"]
        if not body or not body.has_method("interact"):
            continue
        var to_body = body.global_position - camera.global_position
        var dist_sq = to_body.length_squared()
        if dist_sq < 0.0001:
            continue
        if forward.dot(to_body.normalized()) < PROXIMITY_FORWARD_DOT:
            continue
        if dist_sq < best_dist_sq:
            best_dist_sq = dist_sq
            best = body
    return best

func collect_tape() -> void:
    tapes_collected += 1
    update_tapes_ui()

func update_tapes_ui() -> void:
    if EventBus.has_signal("tapes_collected_updated"):
        EventBus.tapes_collected_updated.emit(tapes_collected, max_tapes)
