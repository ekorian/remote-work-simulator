class_name DialogueDef
extends DataDef
## The script of a meeting or call: fixed beats plus a pool to draw from.

@export var beats: Array = []          ## [{who, text, choices, silence, no_excuse, if, voice}]
@export var pool: Array = []           ## ids of other dialogues whose beats may be added
@export var pick := 0                  ## how many to draw from the pool
@export var after: Dictionary = {}     ## consequences of sitting through all of it
