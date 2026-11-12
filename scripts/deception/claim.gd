class_name Claim
extends RefCounted
## One lie the player has told. Claims are remembered for the whole run;
## while a claim is active, facts about what the player does are checked
## against it.

const ACTIVE := "active"            ## believed and still in force
const REJECTED := "rejected"        ## never believed
const EXPIRED := "expired"          ## ran its course without incident
const VERIFIED := "verified"        ## someone checked, and it held up
const CONTRADICTED := "contradicted"   ## caught; waiting for an explanation
const PATCHED := "patched"          ## caught, but talked your way out
const EXPOSED := "exposed"          ## caught, and the explanation failed

const STATUS_TEXT := {
	"active": "ACTIVE", "rejected": "NOT BELIEVED", "expired": "HELD UP", "verified": "VERIFIED",
	"contradicted": "CONTRADICTED", "patched": "TALKED OUT OF IT", "exposed": "EXPOSED",
}

var id := ""
var type := ""                      ## ClaimDef id
var subject := ""                   ## the detail you must stay consistent about
var told_to := ""                   ## npc id
var about := ""                     ## what it was an excuse for
var context := "chat"
var made_at := 0                    ## absolute minute
var expires_at := 0
var witnesses: Array = []           ## npc ids who heard it
var contradicted_by: Array = []     ## fact types that would expose it
var evidence: Array = []            ## supporting evidence present when it was told
var risk := 0                       ## 0..100: how likely someone is to check
var status := ACTIVE
var contradiction := ""             ## the fact type that exposed it
var task := ""                      ## ticket it was attached to, if any
var settled := false                ## its outcome has been counted in the statistics


func is_active() -> bool:
	return status == ACTIVE or status == VERIFIED


func is_live(now: int) -> bool:
	return is_active() and now < expires_at


func to_dict() -> Dictionary:
	return {
		"id": id, "type": type, "subject": subject, "told_to": told_to, "about": about, "context": context,
		"made_at": made_at, "expires_at": expires_at, "witnesses": witnesses, "contradicted_by": contradicted_by,
		"evidence": evidence, "risk": risk, "status": status, "contradiction": contradiction, "task": task, "settled": settled,
	}


static func from_dict(d: Dictionary) -> Claim:
	var c := Claim.new()
	for k in d:
		c.set(k, d[k])
	return c
