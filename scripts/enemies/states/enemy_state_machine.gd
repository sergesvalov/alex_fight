class_name EnemyStateMachine
extends RefCounted

var current_state_name: String = ""
var current_state: EnemyState = null
var states: Dictionary = {}
var ai

func _init(p_ai):
	ai = p_ai

func add_state(state_name: String, state: EnemyState) -> void:
	states[state_name] = state

func change_state(state_name: String) -> void:
	if not states.has(state_name):
		push_error("EnemyStateMachine: State '" + state_name + "' not found.")
		return
	if current_state_name == state_name:
		return
		
	var prev_state = current_state_name
	
	if current_state != null:
		current_state.exit()
		
	current_state_name = state_name
	current_state = states[state_name]
	
	print("[EnemyAI] ", ai.name, " state ", prev_state, " -> ", state_name, " pos=", ai.global_position)
	
	current_state.enter()

func physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_process(delta)
