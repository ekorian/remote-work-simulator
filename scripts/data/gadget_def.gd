class_name GadgetDef
extends DataDef
## A work-avoidance device. New gadgets are added as data: the
## AutomationManager reads abilities from `levels[n].can` and never needs
## to know a gadget by name.

@export var display_name := ""
@export var blurb := ""
@export var kind := "always"           ## always (runs continuously) | use (fires when needed) | passive
@export var needs_net := false
@export var unlock_day := 0            ## first day it is sold (0 = Monday)
@export var requires: Dictionary = {}  ## gadget id -> minimum level owned
## One entry per level: {price, reliability (%), heat, text, can: [abilities], ...params}
@export var levels: Array = []
@export var fail_event := ""           ## event fired when it breaks
@export var fail_text := ""
