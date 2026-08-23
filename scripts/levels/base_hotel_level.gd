# scripts/levels/hotel_level.gd
extends Node3D

# The level script is now clean and handles level-specific mechanics.
# Enemy spawning is handled by the EnemySpawner node.
# Mouse capture is handled by MouseManager autoload.
# The "collect all 3 tapes" reward (secret exit door through the outer wall) is handled by
# hotel_level_generator.gd::_create_exit_portal() now, not here - this used to also spawn its own
# exit_door.tscn through a room's "WallW"/"WallE" child node, but that node hasn't existed since
# double_room.tscn/single_room.tscn were rebuilt (rooms only have their own corridor-facing wall;
# the outer wall is one shared Wall_West/Wall_East per floor, built once by the generator) - this
# was silently erroring every time all_tapes_collected fired, and its own change_scene_to_file()
# call would have blown away the whole stacked 10-floor scene the generator builds if it had ever
# actually run.

func _ready() -> void:
    var rooms = []
    var hotel_geo = $NavigationRegion3D/HotelGeometry
    for child in hotel_geo.get_children():
        if child.name.begins_with("DoubleRoom") or child.name.begins_with("SingleRoom"):
            rooms.append(child)

    if GameStateManager.current_floor == 3:
        # Tape randomization used to live here too (VhsTape_1/2/3 under InteractableObjects) -
        # removed along with those nodes, which duplicated every cassette on the level (the
        # generator's own _spawn_cassettes() now places 3 per floor, everywhere, on its own).
        var available_rooms = rooms.duplicate()
        available_rooms.shuffle()

        if has_node("Enemies/Cerberus") and available_rooms.size() > 0:
            var r = available_rooms.pop_back()
            get_node("Enemies/Cerberus").global_position = r.global_position + Vector3(0, 1.0, 0)
