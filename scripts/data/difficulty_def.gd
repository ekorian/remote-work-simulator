class_name DifficultyDef
extends DataDef
## Balancing for one difficulty level.

@export var display_name := ""
@export var tag := ""
@export var color := Color.WHITE
@export_multiline var desc := ""
@export var susp := 1.0                ## multiplier on every suspicion gain
@export var work_hp := 8.0             ## health lost per legitimate work action
@export var lethal := false            ## any legitimate work action ends the run
@export var recover := 1.0             ## multiplier on health/energy restoration
@export var window := 1.0              ## multiplier on reaction windows
@export var gadget_fail := 1.0         ## multiplier on gadget failure chances
@export var event_rate := 1.0          ## how often colleagues interrupt
@export var boss_check := 1.0          ## how often the manager checks on you
@export var cost := 1.0                ## multiplier on shop prices
@export var cred := 0                  ## flat bonus/penalty to lies
@export var stress := 1.0              ## meeting fatigue and desk drain
@export var score := 1.0               ## final score multiplier
