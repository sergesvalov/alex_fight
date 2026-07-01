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
            if has_node("VhsTape_" + str(i)):
                tapes.append(get_node("VhsTape_" + str(i)))
                
        for tape in tapes:
            if available_rooms.size() > 0:
                var r = available_rooms.pop_back()
                tape.global_position = r.global_position + Vector3(0, 1.0, 0)
                
        if has_node("Enemies/Cerberus") and available_rooms.size() > 0:
            var r = available_rooms.pop_back()
            get_node("Enemies/Cerberus").global_position = r.global_position + Vector3(0, 1.0, 0)
            
        # Change carpet color for the 3rd floor (dark red tint)
        var floor_mat = StandardMaterial3D.new()
        var original_tex = preload("res://assets/textures/hotel_carpet.jpg")
        floor_mat.albedo_texture = original_tex
        floor_mat.albedo_color = Color(0.6, 0.2, 0.2, 1)
        floor_mat.uv1_scale = Vector3(10, 10, 10)
        
        # Apply to corridor
        if has_node("NavigationRegion3D/HotelGeometry/CorridorFloor/MeshInstance3D"):
            var cf = get_node("NavigationRegion3D/HotelGeometry/CorridorFloor/MeshInstance3D")
            # override material
            cf.set_surface_override_material(0, floor_mat)
                
        # Apply to rooms
        for r in rooms:
            if r.has_node("Floor"):
                r.get_node("Floor").material = floor_mat
            if r.has_node("Ceil"):
                # don't color ceiling red unless desired, but usually just floor
                pass

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
    if not silent:
        audio.play()
