class_name EnemyState
extends RefCounted

var ai # Typed as EnemyAI in derived classes to avoid cyclic type issues in base, or we can just use dynamic typing.

func _init(p_ai):
	ai = p_ai

func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_process(delta: float) -> void:
	pass
