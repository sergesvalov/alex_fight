extends SceneTree
func _init():
    var scene = load('res://scenes/levels/hotel_siberia/blocks/north_stairs.tscn')
    var inst = scene.instantiate()
    var csg = inst.get_node('StairsGeometry')
    if csg:
        csg._update_shape()
        var meshes = csg.get_meshes()
        print('CSG Meshes length: ', meshes.size())
        if meshes.size() > 1:
            var array_mesh = meshes[1]
            if array_mesh is ArrayMesh:
                print('Faces: ', array_mesh.get_faces().size())
    else:
        print('NO CSG')
    quit()
