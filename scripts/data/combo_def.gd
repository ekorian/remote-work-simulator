class_name ComboDef
extends DataDef
## A synergy between gadgets that are running at the same time.

@export var display_name := ""
@export var needs: Array = []          ## gadget ids that must all be working
@export var text := ""
@export var effects: Dictionary = {}   ## named modifiers read by the systems
