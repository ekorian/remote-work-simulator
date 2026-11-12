class_name ClaimDef
extends DataDef
## A category of lie the player can tell. Each has its own strengths,
## weaknesses, evidence, contradicting actions and follow-up events.

@export var title := ""
@export var line := ""                 ## what the player says
@export var subjects: Array = []       ## details the player must stay consistent about
@export var contexts: Array = []       ## where it can be used: chat | meeting | call | ticket
@export var base := 50                 ## base chance (%) that it is believed
@export var duration := 60             ## minutes the claim stays active
@export var cover := 0                 ## minutes of excused absence it grants
@export var reuse_penalty := 17        ## credibility lost per previous use this week
@export var risk := 40                 ## base chance (%) that someone checks up on it
@export var contradicted_by: Array = []   ## fact types that expose it
@export var ticket_scoped := false     ## "ticket_activity" only counts on the ticket it was about
@export var conflicts: Array = []      ## claim types that cannot be true at the same time
@export var evidence: Dictionary = {}  ## evidence id -> credibility bonus
@export var effect: Dictionary = {}    ## extra effect when accepted (e.g. {"extend": 1440})
@export var followups: Array = []      ## [{after, kind, chance, ...}] scheduled when accepted
@export var strength := ""
@export var weakness := ""
@export var accepted := ""             ## NPC line when believed
@export var rejected := ""             ## NPC line when not believed
@export var exposed: Dictionary = {}   ## fact type -> confrontation line ("default" as fallback)
@export var recoveries: Array = []     ## choices offered when confronted
