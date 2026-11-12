class_name GameSystem
extends Node
## Base class for a simulation system owned by the GameManager.
##
## Systems hold their own runtime state as members, expose signals for
## changes, and implement these hooks. They never reference scenes or UI.

func setup_run() -> void:
	## A new run starts: reset all state.
	pass


func new_day() -> void:
	## A new workday starts (not called for Monday; setup_run covers it).
	pass


func save_state() -> Dictionary:
	return {}


func load_state(_d: Dictionary) -> void:
	pass
