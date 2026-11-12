class_name EventDef
extends DataDef
## A workplace event: a message, mail, meeting, call or system notice,
## with the conditions under which the EventDirector may fire it.

@export var title := ""
@export var kind := "chat"             ## chat | mail | meeting | call | task | say | system
@export var from := "martin"
@export var thread := ""
@export_multiline var text := ""
@export var subject := ""              ## mail subject
@export_multiline var body := ""       ## mail body
@export var choices: Array = []        ## see docs/ARCHITECTURE.md "Choice format"
@export var expire: Dictionary = {}    ## consequences when ignored
@export var facts: Array = []          ## facts this event makes visible (checked against live claims)
@export var window := 25               ## minutes to respond
@export var routine := false           ## low stakes: chatbots may answer it
@export var no_excuse := false         ## excuses are not offered
# --- when it happens ---
@export var schedule: Array = []       ## fixed slots: [{day, at}]
@export var pool := ""                 ## random filler pool: boss | peer | call | weird
@export var trigger := ""              ## "state": checked every minute; "call_join": when a call starts
@export var conditions: Dictionary = {}
@export var cooldown := 0              ## minutes before it can fire again (0 = once per day)
@export var once := false              ## at most once per run
@export var difficulty: Dictionary = {}   ## difficulty id -> {skip, window, chance}
@export var task := ""                 ## ticket id to assign (kind "task")
@export var action := ""               ## handler name for kind "system"
@export var args: Dictionary = {}
@export var meeting: Dictionary = {}   ## {dur, script, mandatory, no_dodge, who, cast, private, ask, voice (audio only), voice_id, casual}
@export var tip := ""                  ## what a well-informed friend would warn you about: scan | call | screen
