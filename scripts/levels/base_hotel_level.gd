# scripts/levels/hotel_level.gd
extends Node3D

# The level script is now clean and handles level-specific mechanics.
# Enemy spawning is handled by the EnemySpawner node.
# Mouse capture is handled by MouseManager autoload.

var exit_door_scene = preload("res://entities/props/exit_door.tscn")
var rumble_sound = preload("res://assets/audio/sfx/door_open.wav")

func _ready() -> void:
    GameStateManager.all_tapes_collected.connect(_on_all_tapes_collected)
    
    var rooms = []
    var hotel_geo = $NavigationRegion3D/HotelGeometry
    for child in hotel_geo.get_children():
        if child.name.begins_with("DoubleRoom") or child.name.begins_with("SingleRoom"):
            rooms.append(child)
            
    if GameStateManager.entered_from_stairs:
        GameStateManager.entered_from_stairs = false
        var player = get_node_or_null("Player")
        if player:
            player.global_position = GameStateManager.stair_spawn_position
            player.rotation = GameStateManager.stair_spawn_rotation
            
    if GameStateManager.entered_from_outer_door:
        GameStateManager.entered_from_outer_door = false
        if rooms.size() > 0:
            var target_room = rooms.pick_random()
            var is_double = target_room.name.begins_with("DoubleRoom")
            
            # Spawn door behind player
            _spawn_exit_door(target_room, true)
            
            # Place player in front of the door
            var player = null
            if has_node("Player"):
                player = get_node("Player")
            
            if player:
                if is_double:
                    # Player at X=-3.0 (facing +X into room)
                    player.global_position = target_room.global_position + Vector3(-3.0, 2.0, 0.0)
                    player.rotation.y = -PI/2 # Face +X
                else:
                    # Player at X=2.0 (facing -X into room)
                    player.global_position = target_room.global_position + Vector3(2.0, 2.0, 0.0)
                    player.rotation.y = PI/2 # Face -X

    if GameStateManager.current_floor == 3:
        # Randomize tapes and Cerberus spawn
        var available_rooms = rooms.duplicate()
        available_rooms.shuffle()
        
        var tapes = []
        for i in range(1, 4):
            var tape_path = "InteractableObjects/VhsTape_" + str(i)
            if has_node(tape_path):
                tapes.append(get_node(tape_path))
                
        for tape in tapes:
            if available_rooms.size() > 0:
                var r = available_rooms.pop_back()
                var is_double = r.name.begins_with("DoubleRoom")
                var local_pos = Vector3(0.5, 0.87, 4.5) if is_double else Vector3(2.0, 0.87, -2.5)
                tape.global_position = r.to_global(local_pos)
                tape.global_rotation = r.global_rotation
                
        if has_node("Enemies/Cerberus") and available_rooms.size() > 0:
            var r = available_rooms.pop_back()
            get_node("Enemies/Cerberus").global_position = r.global_position + Vector3(0, 1.0, 0)
            
        # Specific floor logic should be handled by extending scripts
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

func _spawn_exit_door(room: Node3D, silent: bool = false) -> void:
    var is_double = room.name.begins_with("DoubleRoom")
    var wall_name = "WallW" if is_double else "WallE"
    var wall = room.get_node(wall_name)
    
    var hole = CSGBox3D.new()
    hole.operation = CSGShape3D.OPERATION_SUBTRACTION
    
    # 2. Spawn the exit door
    var door = exit_door_scene.instantiate()
    room.add_child(door)
    if is_double:
        # Facing +X, door spans Z from 0 to -1
        var basis = Basis.from_euler(Vector3(0, PI/2, 0))
        door.transform = Transform3D(basis, Vector3(-4.0, 0.25, 0.0))
        hole.size = Vector3(2.0, 2.5, 1.0)
        hole.position = Vector3(0, -0.75, -0.5)
    else:
        # Facing -X, door spans Z from 0 to +1
        var basis = Basis.from_euler(Vector3(0, -PI/2, 0))
        door.transform = Transform3D(basis, Vector3(3.0, 0.25, 0.0))
        hole.size = Vector3(2.0, 2.5, 1.0)
        hole.position = Vector3(0, -0.75, 0.5)
        
    wall.add_child(hole)
        
    # 3. Play rumble sound
    var audio = AudioStreamPlayer3D.new()
    audio.stream = rumble_sound
    audio.pitch_scale = 0.3
    audio.volume_db = 15.0
    door.add_child(audio)
    if not silent:
        audio.play()
