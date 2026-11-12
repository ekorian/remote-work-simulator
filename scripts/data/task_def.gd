class_name TaskDef
extends DataDef
## A ticket that can be assigned to the player.

@export var key := ""
@export var title := ""
@export var desc := ""
@export_range(1, 4) var prio := 2
@export var effort := 2                ## real work sessions it would take
@export var due_day := 1               ## days from assignment
@export var due_t := 1000              ## minute of that day
