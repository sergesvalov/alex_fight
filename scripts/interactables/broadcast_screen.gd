# scripts/interactables/broadcast_screen.gd
# The glowing black-and-white face on the wall of every floor's corridor
# (hotel_level_generator.gd, "PropagandaScreen"): the hotel's internal broadcast, the one thing in
# the building still transmitting. The man is Gromov, the head of the works downstairs, and what
# plays is his recorded address to the staff - one line per floor
# (narrative_lines.json "broadcasts"), calm orders at first, coming apart the further the hero gets.
# Each line also says, in the hotel's own voice, what the rule of that floor is.
#
# The hero knows the face but not from where, until floor 8 gives him his own name back - then
# he remembers who he came here for. When the installation is stopped (the third console in the
# laboratory) every screen in the hotel goes dark.
#
# This Area3D sits on the screen as its child; the interact ray calls interact().
extends Area3D

var floor_num: int = 0

const LINE_SECONDS: float = 9.0
var _dark: bool = false

func _process(_delta: float) -> void:
	if not _dark and GameStateManager.lab_consoles_off >= 3:
		_go_dark()

func _go_dark() -> void:
	_dark = true
	set_process(false)
	var screen := get_parent() as MeshInstance3D
	if not screen:
		return
	screen.set_process(false) # flicker_material.gd would light it up again
	var mat := screen.mesh.material as StandardMaterial3D if screen.mesh else null
	if mat:
		mat.emission_energy_multiplier = 0.0
		mat.albedo_color = Color(0.04, 0.04, 0.04)

func interact(_player: Node) -> void:
	if _dark:
		DialogSystem.show_thought(UIStrings.get_string("broadcast_dark"), 4.0)
		return
	var line: String = DialogSystem.broadcasts.get(str(floor_num), "")
	if line == "":
		return
	print("[BroadcastScreen] floor ", floor_num, ": ", line)
	DialogSystem.show_thought(UIStrings.get_string("broadcast_format", "%s") % line, LINE_SECONDS)
	# The hero's own reaction comes after the address, not over it. Before floor 8 he only
	# knows the face; once a floor-8 tape has given him his name, he knows the man.
	var key: String = "screen_recognized" if _name_is_back() else "screen_first"
	if DialogSystem._alex_lines_fired.get(key, false):
		return
	await get_tree().create_timer(LINE_SECONDS, false).timeout
	DialogSystem.trigger_alex_line(key)

func _name_is_back() -> bool:
	for tape in GameStateManager.collected_tapes:
		if int(tape["floor"]) == 8:
			return true
	return false
