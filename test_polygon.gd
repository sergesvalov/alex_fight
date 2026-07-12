extends SceneTree

func _init():
	var poly = CSGPolygon3D.new()
	poly.polygon = PackedVector2Array([Vector2(0,0), Vector2(1,1), Vector2(1,0)])
	poly.depth = 1.0
	poly._update_shape()
	print("AABB: ", poly.get_aabb())
	quit()
