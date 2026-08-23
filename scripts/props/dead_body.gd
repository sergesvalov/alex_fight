extends StaticBody3D

# Which clothing/stain variant to use - lets the handful of corpses placed around the hotel
# look distinct instead of identical copies. Purely cosmetic seed, not a game-state id.
@export var body_id: int = 0

# Clothing colors to pick from (dark, worn civilian coats - fits the Soviet-institutional look),
# picked by body_id so different corpses don't look identical.
const CLOTHING_PALETTE: Array[Color] = [
	Color(0.14, 0.14, 0.16), # charcoal coat
	Color(0.16, 0.13, 0.10), # worn brown coat
	Color(0.12, 0.15, 0.14), # faded olive coat
]

func _ready() -> void:
	# Scale corpse to match player height (base height is 1.8)
	var c_scale = GlobalConfig.player_height / 1.8
	scale = Vector3(c_scale, c_scale, c_scale)

	var rng = RandomNumberGenerator.new()
	rng.seed = body_id + 1

	var skin = Color(0.6, 0.48, 0.4)
	var clothing = CLOTHING_PALETTE[body_id % CLOTHING_PALETTE.size()]
	var clothing_dark = Color(clothing.r * 0.55, clothing.g * 0.55, clothing.b * 0.55)

	var skin_mat = _noisy_material(skin, rng)
	var clothing_mat = _noisy_material(clothing, rng)
	var dark_mat = _noisy_material(clothing_dark, rng)
	# Only the torso gets the blood stain - putting it on every part would look like the corpse
	# was dyed red rather than actually wounded somewhere specific.
	var torso_mat = _stained_material(clothing, rng)

	_apply("Head", skin_mat)
	_apply("Torso", torso_mat)
	_apply("Hips", clothing_mat)
	_apply("LegL", dark_mat)
	_apply("LegR", dark_mat)
	_apply("ArmL", clothing_mat)
	_apply("ArmR", clothing_mat)

func _apply(node_name: String, mat: Material) -> void:
	var node := get_node_or_null(node_name)
	if node:
		node.material_override = mat

# Procedurally generated (Image/ImageTexture, no external asset, same approach as vhs_tape.gd) -
# a small noise texture tiled over each body part so it doesn't read as a flat solid color.
func _noisy_material(base: Color, rng: RandomNumberGenerator) -> StandardMaterial3D:
	var size = 16
	var img = Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	for y in range(size):
		for x in range(size):
			var n = rng.randf_range(-0.035, 0.035)
			img.set_pixel(x, y, Color(base.r + n, base.g + n, base.b + n))

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.uv1_scale = Vector3(2, 2, 2)
	mat.roughness = 0.85
	return mat

# Same noise as _noisy_material(), plus a dried-blood patch (dark reddish-brown, not bright red,
# so it reads as grim rather than cartoonish) roughly where a torso wound would be.
func _stained_material(base: Color, rng: RandomNumberGenerator) -> StandardMaterial3D:
	var size = 24
	var img = Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	for y in range(size):
		for x in range(size):
			var n = rng.randf_range(-0.035, 0.035)
			img.set_pixel(x, y, Color(base.r + n, base.g + n, base.b + n))

	var stain = Color(0.22, 0.05, 0.04)
	var cx = size * 0.55
	var cy = size * 0.4
	var radius = size * 0.3
	for y in range(size):
		for x in range(size):
			var dx = x - cx
			var dy = y - cy
			if dx * dx + dy * dy < radius * radius:
				var n = rng.randf_range(-0.03, 0.03)
				img.set_pixel(x, y, Color(stain.r + n, stain.g + n, stain.b + n))

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.uv1_scale = Vector3(1.5, 1.5, 1.5)
	mat.roughness = 0.85
	return mat
