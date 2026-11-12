extends Node
## Deception — excuse ledger, credibility maths and contradiction checks.
##
## Every lie the player tells is logged. Reusing a story wears it out, some
## stories are checked later against the real state of the apartment (is the
## router actually unplugged?), and contradictions come back at the Friday review.

const EXCUSES := {
	"internet": {
		"label": "My internet just died.",
		"base": 58, "cover": 45, "verify": 12, "cat": "outage",
		"hint": "Todd WILL check with IT in ~12 min. The router must really be unplugged.",
		"accepted": "Ugh, again? Fine. Ping me the second you're back.",
		"rejected": "Your status has been green for an hour. Try again.",
	},
	"power": {
		"label": "Power cut on my whole street.",
		"base": 46, "cover": 60, "verify": 15, "cat": "outage",
		"hint": "Verified like an outage: the router must be off when IT looks.",
		"accepted": "Yikes. Keep me posted. Do you have a... generator?",
		"rejected": "A power cut. While you're typing to me. On your computer.",
	},
	"laptop": {
		"label": "My laptop is installing 114 mandatory updates.",
		"base": 52, "cover": 35, "cat": "it",
		"hint": "Much stronger if the company laptop really is updating.",
		"accepted": "IT strikes again. OK, shout when it's done.",
		"rejected": "IT says nothing was pushed to your machine today.",
	},
	"sick": {
		"label": "I think it was the gas-station sushi.",
		"base": 50, "cover": 75, "cat": "health",
		"hint": "A printed doctor's note makes this nearly bulletproof (uses the note).",
		"accepted": "Say no more. Please. Say no more. Feel better.",
		"rejected": "You were 'sick' and posting memes in #general ten minutes ago.",
	},
	"dentist": {
		"label": "Dentist appointment. It's in my calendar.",
		"base": 44, "cover": 60, "cat": "appointment",
		"hint": "Much stronger if a calendar block actually covers this time.",
		"accepted": "Right, I see it in the calendar. Floss, I guess.",
		"rejected": "I'm looking at your calendar. It is empty. Like this excuse.",
	},
	"client": {
		"label": "I'm double-booked with a client call.",
		"base": 48, "cover": 40, "cat": "appointment",
		"hint": "Much stronger if a calendar block actually covers this time.",
		"accepted": "Client first! Love the hustle.",
		"rejected": "Which client? We don't let you talk to clients.",
	},
	"family": {
		"label": "Family thing. I'd rather not get into it.",
		"base": 46, "cover": 50, "cat": "personal",
		"hint": "Works once. Gets dramatically worse every time you reuse it.",
		"accepted": "Of course, of course. Family comes first. (After Q3.)",
		"rejected": "That's the third family thing this week. How big is this family?",
	},
	"focus": {
		"label": "I'm heads-down in deep work, can this wait?",
		"base": 50, "cover": 30, "cat": "focus",
		"hint": "Stronger the higher your Productivity Illusion is.",
		"accepted": "Love to see it. Stay in the zone.",
		"rejected": "Deep work on WHAT? Your last commit was in March.",
	},
	"pet": {
		"label": "My cat walked on the keyboard and deployed something.",
		"base": 36, "cover": 25, "cat": "chaos",
		"hint": "A long shot. Occasionally Todd just respects the audacity.",
		"accepted": "...Honestly that explains last Tuesday. Carry on.",
		"rejected": "You told HR you're allergic to cats.",
	},
}

const REUSE_PENALTY := 17.0


func chance(base: float, tags: Array = [], excuse_id: String = "") -> float:
	## Percent chance (5..95) that a lie lands, given everything the boss knows.
	if not Game.active:
		return 50.0
	var c := base + float(Game.diff().cred)
	c -= Game.get_stat("susp") * 0.22
	c += (Game.get_stat("ill") - 45.0) * 0.18
	if Game.has_buff("wired"):
		c -= 16.0
	elif Game.has_buff("jitter"):
		c -= 8.0
	if Game.has_buff("jargon"):
		c += 12.0 if "jargon" in tags else 6.0
	if Game.get_stat("energy") < 20.0:
		c -= 10.0
	if "video" in tags:
		match str(Game.s.outfit):
			"shirt":
				c += 9.0
			"pajamas":
				c -= 10.0
		if Interact.desk_staged():
			c += 6.0
	if "favor" in tags:
		c += float(Game.s.favor) * 6.0
	if excuse_id != "":
		c -= REUSE_PENALTY * float(uses(excuse_id))
		c += evidence_bonus(excuse_id)
		if Game.has_buff("inspired"):
			c += 10.0
	return clampf(c, 5.0, 95.0)


func roll(base: float, tags: Array = [], excuse_id: String = "") -> bool:
	return Game.chance(chance(base, tags, excuse_id))


func odds_word(pct: float) -> String:
	if pct >= 80.0:
		return "Safe"
	if pct >= 62.0:
		return "Likely"
	if pct >= 45.0:
		return "Coin flip"
	if pct >= 28.0:
		return "Risky"
	return "Desperate"


func odds_color(pct: float) -> Color:
	if pct >= 62.0:
		return Color("5ad17a")
	if pct >= 45.0:
		return Color("ffd166")
	if pct >= 28.0:
		return Color("ff8c5a")
	return Color("ff5d73")


func uses(excuse_id: String) -> int:
	var n := 0
	for e in Game.s.ledger:
		if str(e.id) == excuse_id:
			n += 1
	return n


func has_evidence(excuse_id: String) -> bool:
	match excuse_id:
		"internet", "power":
			return not Interact.router_on()
		"laptop":
			return Interact.laptop_updating()
		"sick":
			return int(Game.s.things.get("notes", 0)) > 0
		"dentist", "client":
			return Corp.calendar_block_now()
		"focus":
			return Game.get_stat("ill") >= 60.0
	return false


func evidence_bonus(excuse_id: String) -> float:
	if not has_evidence(excuse_id):
		return 0.0
	match excuse_id:
		"internet":
			return 20.0
		"power":
			return 16.0
		"laptop":
			return 32.0
		"sick":
			return 38.0
		"dentist", "client":
			return 34.0
		"focus":
			return 16.0
	return 0.0


func burned(excuse_id: String) -> bool:
	## Used so often that claiming it again is itself a contradiction.
	return uses(excuse_id) >= 3


func options(context: String = "chat") -> Array:
	## Excuse choices for a prompt: [{id, label, chance, hint, uses, evidence}]
	var out: Array = []
	for id in EXCUSES:
		var e: Dictionary = EXCUSES[id]
		var tags: Array = ["video"] if context == "video" else []
		out.append({
			"id": id, "label": e.label, "hint": e.hint,
			"chance": chance(float(e.base), tags, id),
			"uses": uses(id), "evidence": has_evidence(id), "burned": burned(id),
		})
	return out


func attempt(excuse_id: String, context: String = "chat", what: String = "") -> Dictionary:
	## Tell the lie. Returns {ok, say, contradiction, cover}.
	var e: Dictionary = EXCUSES[excuse_id]
	var res := {"ok": false, "say": "", "contradiction": false, "cover": 0, "id": excuse_id}
	Game.bump("excuses")
	if burned(excuse_id):
		res.contradiction = true
		res.say = "That's the fourth time this week. I'm starting a spreadsheet about you."
		_log(excuse_id, false, what)
		_contradiction("Worn-out excuse: \"%s\"" % e.label, 9.0)
		return res
	var tags: Array = ["video"] if context == "video" else []
	var ok := roll(float(e.base), tags, excuse_id)
	var had_evidence := has_evidence(excuse_id)
	if Game.has_buff("inspired"):
		Game.remove_buff("inspired")
	if excuse_id == "sick" and had_evidence:
		Game.s.things.notes = int(Game.s.things.notes) - 1
		Bus.thing_changed.emit("printer")
	_log(excuse_id, ok, what)
	if ok:
		res.ok = true
		res.say = e.accepted
		res.cover = int(e.cover)
		Game.grant_cover(int(e.cover), str(e.cat))
		if e.has("verify"):
			var delay := int(round(float(e.verify) * float(Game.diff().window)))
			Director.schedule(Game.now() + delay, "verify_excuse", {"id": excuse_id})
			if not had_evidence:
				Bus.toast.emit("Todd is checking with IT. Unplug the router within %d min!" % delay, "warn")
	else:
		res.say = e.rejected
		Game.bump("excuses_failed")
	return res


func verify(excuse_id: String) -> void:
	## Called by the Director some minutes after an outage-type excuse.
	if has_evidence(excuse_id):
		Game.add("susp", -3.0, "Your story checked out")
		Bus.toast.emit("IT confirmed: your connection really is down. Story holds.", "good")
		Corp.say("todd", "IT confirms you're offline. Brutal. Hang in there.")
	else:
		_contradiction("IT checked: your connection was fine the whole time", 13.0)
		Game.s.cover.until = -1
		Corp.say("todd", "Funny thing. IT says your connection never dropped. We'll talk about this.")


func _contradiction(text: String, susp: float) -> void:
	Game.bump("contradictions")
	Game.add("susp", susp, "Contradiction")
	Bus.toast.emit("CONTRADICTION: %s" % text, "bad")
	Bus.sfx.emit("bad")


func _log(excuse_id: String, ok: bool, what: String) -> void:
	Game.s.ledger.append({"id": excuse_id, "day": int(Game.s.day), "t": int(Game.s.t), "ok": ok, "what": what})


func ledger_lines() -> Array:
	## Human-readable history for the "Alibi Notebook" UI.
	var out: Array = []
	for e in Game.s.ledger:
		var ex: Dictionary = EXCUSES.get(str(e.id), {})
		out.append({
			"when": "%s %s" % [Cfg.DAYS_SHORT[int(e.day)], Cfg.fmt_time(float(e.t))],
			"text": str(ex.get("label", e.id)), "ok": bool(e.ok), "what": str(e.what),
		})
	return out
