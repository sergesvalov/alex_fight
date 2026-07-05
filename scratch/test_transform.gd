extends SceneTree

func _init():
    var b = Basis(Vector3.UP, -PI/2)
    print("Basis -PI/2: ", b)
    var b2 = Basis(Vector3.UP, PI/2)
    print("Basis PI/2: ", b2)
    quit()
