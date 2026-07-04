extends StaticBody3D

func _ready() -> void:
	# Scale corpse to match player height (base height is 1.8)
	var c_scale = GlobalConfig.player_height / 1.8
	scale = Vector3(c_scale, c_scale, c_scale)
