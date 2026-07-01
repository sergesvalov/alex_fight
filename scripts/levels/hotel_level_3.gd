extends "res://scripts/levels/base_hotel_level.gd"

func _ready() -> void:
    super._ready()
    
    # 1. Change carpet color to red
    var floor_mat = StandardMaterial3D.new()
    var original_tex = preload("res://assets/textures/hotel_carpet.jpg")
    floor_mat.albedo_texture = original_tex
    floor_mat.albedo_color = Color(0.6, 0.2, 0.2, 1)
    floor_mat.uv1_scale = Vector3(10, 10, 10)
    
    # Apply to corridor
    if has_node("NavigationRegion3D/HotelGeometry/CorridorFloor/MeshInstance3D"):
        var cf = get_node("NavigationRegion3D/HotelGeometry/CorridorFloor/MeshInstance3D")
        cf.set_surface_override_material(0, floor_mat)
            
    # Apply to rooms
    var hotel_geo = $NavigationRegion3D/HotelGeometry
    for r in hotel_geo.get_children():
        if (r.name.begins_with("DoubleRoom") or r.name.begins_with("SingleRoom")) and r.has_node("Floor"):
            r.get_node("Floor").material = floor_mat
            
    # 2. Change room labels (4xx -> 3xx)
    for child in hotel_geo.get_children():
        if child.name.begins_with("RoomLabel_"):
            if child is Label3D:
                if child.text.begins_with("4"):
                    child.text = "3" + child.text.substr(1)
                    
    # 3. Swap the map texture
    var map_node = hotel_geo.get_node_or_null("MapDecal")
    if map_node and map_node is MeshInstance3D:
        var map_mat = StandardMaterial3D.new()
        map_mat.albedo_texture = preload("res://assets/textures/hotel_map_3.jpg")
        map_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        map_node.set_surface_override_material(0, map_mat)
