class_name NpcDef
extends DataDef
## A person at SynerCorp. Adding a file here is all it takes to add a
## character: the NPCManager tracks relationship, mood and knowledge for
## every NpcDef it finds.

@export var display_name := ""
@export var role := ""
@export var color := Color.WHITE
@export var kind := "coworker"        ## manager | coworker | hr | it | executive | bot | player
@export var is_boss := false          ## the manager whose suspicion decides your fate
@export var thread := ""              ## chat thread they speak in ("" = their own DM)
@export var has_dm := true            ## appears in the SynerTeams contact list
@export var look: Dictionary = {}     ## appearance for the 3D character (see Character)
@export_range(0.0, 2.0) var chattiness := 1.0     ## how often they start conversations
@export_range(-20.0, 20.0) var gullibility := 0.0 ## flat bonus to lies told to them
@export var start_relationship := 50.0
@export var mood_lines: Dictionary = {}           ## mood -> [lines] used when their mood changes
@export var escalation_lines: Array = []          ## one line per escalation level (boss only)
