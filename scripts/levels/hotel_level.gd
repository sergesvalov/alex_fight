# scripts/levels/hotel_level.gd
extends Node3D

# The level script is now clean and handles level-specific mechanics.
# Enemy spawning is handled by the EnemySpawner node.
# Mouse capture is handled by MouseManager autoload.

var exit_door_scene = preload("res://entities/props/exit_door.tscn")
var rumble_sound = preload("res://assets/audio/sfx/door_open.wav")

func _ready() -> void:
    GameStateManager.all_tapes_collected.connect(_on_all_tapes_collected)

func _on_all_tapes_collected() -> void:
    # Pick a random room
    var rooms = []
    var hotel_geo = $NavigationRegion3D/HotelGeometry
    for child in hotel_geo.get_children():
        if child.name.begins_with("DoubleRoom") or child.name.begins_with("SingleRoom"):
            rooms.append(child)
            
    if rooms.size() > 0:
        var chosen_room = rooms.pick_random()
        _spawn_exit_door(chosen_room)

func _spawn_exit_door(room: Node3D) -> void:
    var is_double = room.name.begins_with("DoubleRoom")
    var wall_name = "WallW" if is_double else "WallE"
    var wall = room.get_node(wall_name)
    
    # 1. Create a hole in the wall using CSGBox3D with subtraction
    var hole = CSGBox3D.new()
    hole.operation = CSGShape3D.OPERATION_SUBTRACTION
    hole.size = Vector3(2, 2.5, 1.2)
    hole.position = Vector3(0, -0.75, 0.0)
    wall.add_child(hole)
    
    # 2. Spawn the exit door
    var door = exit_door_scene.instantiate()
    room.add_child(door)
    if is_double:
        # Facing +X
        var basis = Basis(Vector3(0, 1, 0), PI/2)
        door.transform = Transform3D(basis, Vector3(-4.0, 0.25, 0.0))
    else:
        # Facing -X
        var basis = Basis(Vector3(0, 1, 0), -PI/2)
        door.transform = Transform3D(basis, Vector3(3.0, 0.25, 0.0))
        
    # 3. Play rumble sound
    var audio = AudioStreamPlayer3D.new()
    audio.stream = rumble_sound
    audio.pitch_scale = 0.3
    audio.volume_db = 15.0
    door.add_child(audio)
    audio.play()
