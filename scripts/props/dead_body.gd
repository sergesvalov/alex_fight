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

	var mesh_inst := get_node_or_null("MeshInstance3D")
	if not mesh_inst:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _generate_body_texture()
	mat.roughness = 0.85
	mesh_inst.material_override = mat

# Procedurally generated (Image/ImageTexture, no external asset) - a flat solid-red capsule
# reads as a placeholder, not a body. This paints pale skin at both ends (head, hands/feet)
# with a dark worn coat and darker trousers along the middle, plus a dried-blood stain patch
# over the chest - since CapsuleMesh's V texture coordinate runs along its full length
# (including both end caps), a texture banded along the vertical (Y) axis wraps sensibly onto
# it lying on its side.
func _generate_body_texture() -> ImageTexture:
	var w = 32
	var h = 64
	var img = Image.create_empty(w, h, false, Image.FORMAT_RGB8)

	var rng = RandomNumberGenerator.new()
	rng.seed = body_id + 1

	var skin = Color(0.6, 0.48, 0.4)
	var clothing = CLOTHING_PALETTE[body_id % CLOTHING_PALETTE.size()]
	var clothing_dark = Color(clothing.r * 0.55, clothing.g * 0.55, clothing.b * 0.55)

	for y in range(h):
		var t = float(y) / float(h - 1) # 0 = one end (head/hands), 1 = other end (feet)
		var base: Color
		if t < 0.12 or t > 0.94:
			base = skin
		elif t < 0.55:
			base = clothing
		else:
			base = clothing_dark
		for x in range(w):
			var n = rng.randf_range(-0.03, 0.03)
			img.set_pixel(x, y, Color(base.r + n, base.g + n, base.b + n))

	# Dried-blood stain over the chest area - dark reddish-brown, not bright red, so it reads
	# as grim rather than cartoonish.
	var stain = Color(0.22, 0.05, 0.04)
	var stain_cx = w * 0.5
	var stain_cy = h * 0.3
	var stain_r = w * 0.4
	for y in range(h):
		for x in range(w):
			var dx = x - stain_cx
			var dy = (y - stain_cy) * 0.6
			if dx * dx + dy * dy < stain_r * stain_r:
				var n = rng.randf_range(-0.03, 0.03)
				img.set_pixel(x, y, Color(stain.r + n, stain.g + n, stain.b + n))

	return ImageTexture.create_from_image(img)
