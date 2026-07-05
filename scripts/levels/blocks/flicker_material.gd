extends MeshInstance3D

var timer: float = 0.0
var next_flicker: float = 0.1
var is_on: bool = true
var mat: StandardMaterial3D

func _ready() -> void:
	# Material is assigned to the mesh itself by the generator
	if mesh and mesh.get_surface_count() > 0:
		mat = mesh.surface_get_material(0)
	
	# Fallback if generator sets material_override
	if not mat and material_override:
		mat = material_override

func _process(delta: float) -> void:
	if not mat: return
	
	timer += delta
	if timer >= next_flicker:
		timer = 0.0
		
		# Random chance for a long pause or short flicker
		if randf() > 0.8:
			is_on = not is_on
		
		if is_on:
			mat.emission_energy_multiplier = randf_range(0.7, 1.2)
			next_flicker = randf_range(0.1, 0.4)
		else:
			mat.emission_energy_multiplier = randf_range(0.0, 0.2)
			next_flicker = randf_range(0.05, 0.15)
