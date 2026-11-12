class_name DeceptionManager
extends GameSystem
## DeceptionManager — the stateful deception engine.
##
## Every lie becomes a Claim in the ledger and is remembered for the whole
## run. Other systems report what the player visibly does as *facts*
## (`observe("video_meeting")`); each fact is checked against every claim
## that is still in force. A fact a claim cannot survive is a contradiction:
## suspicion rises, the witness loses trust, and a follow-up confrontation is
## scheduled in which the player has to explain themselves.
##
## Claim categories, their evidence, contradicting facts and follow-ups are
## data (resources/deception/*.tres). Nothing here is random text generation:
## the same state always produces the same options and odds.

signal claim_added(claim: Claim)
signal claim_changed(claim: Claim)
signal contradiction(claim: Claim, fact: String)

## What the player can visibly do, as far as colleagues can tell.
const FACTS := {
	"online_status": "your status shows Available",
	"desk_message": "a message sent from your work computer",
	"phone_message": "a message sent from your phone",
	"social_post": "cheerful activity in a group channel",
	"video_meeting": "joining a call on camera",
	"phone_meeting": "joining a call from your phone",
	"ticket_activity": "progress showing up on a ticket",
	"auto_message": "a message sent by one of your gadgets",
	"auto_report": "a report sent by one of your gadgets",
	"router_on": "IT can ping your router",
	"calendar_free": "your calendar is empty at that time",
	"no_incident": "nobody else knows about any incident",
	"team_denies": "the other team has never heard of it",
	"no_form": "no paperwork was ever filed",
}
## Short advice shown in the ledger for each contradicting fact.
const AVOID := {
	"online_status": "appear Available (leave the desk, stop MouseMover)",
	"desk_message": "send anything from your work computer",
	"social_post": "react or chat in group channels",
	"video_meeting": "join a call on camera",
	"phone_meeting": "join a call from your phone",
	"ticket_activity": "touch your tickets",
	"auto_message": "let the Chatbot Team answer for you",
	"auto_report": "let a gadget send a report",
	"phone_message": "answer from your phone",
}
## Facts the player needs a moment to stop producing after telling the lie.
const GRACE := {"online_status": 9}
const DEFAULT_GRACE := 2
const BURN_AFTER := 3            ## uses of one category before it backfires on its own

var claims: Array[Claim] = []    ## the ledger: every claim this run, oldest first
var _checked := {}               ## claim id -> true once its verification ran


func _ready() -> void:
	Game.time.minute_passed.connect(_on_minute)
	Game.time.timer_fired.connect(_on_timer)


func setup_run() -> void:
	Db.load_all()
	claims = []
	_checked = {}


func save_state() -> Dictionary:
	var list: Array = []
	for c in claims:
		list.append(c.to_dict())
	return {"claims": list, "checked": _checked}


func load_state(d: Dictionary) -> void:
	claims = []
	for cd in d.get("claims", []):
		claims.append(Claim.from_dict(cd))
	_checked = d.get("checked", {})


# ---------------------------------------------------------------------------
# Reading the ledger
# ---------------------------------------------------------------------------

func def(type: String) -> Dictionary:
	return Db.claims.get(type, {})


func claim(id: String) -> Claim:
	for c in claims:
		if c.id == id:
			return c
	return null


func live_claims() -> Array[Claim]:
	var now := Game.time.now()
	var out: Array[Claim] = []
	for c in claims:
		if c.is_live(now):
			out.append(c)
	return out


func live(type: String) -> Claim:
	for c in live_claims():
		if c.type == type:
			return c
	return null


func uses(type: String) -> int:
	var n := 0
	for c in claims:
		if c.type == type:
			n += 1
	return n


func burned(type: String) -> bool:
	return uses(type) >= BURN_AFTER


func successful() -> int:
	## Stories that were believed and never came back to bite.
	var n := 0
	for c in claims:
		if c.status in [Claim.EXPIRED, Claim.VERIFIED, Claim.PATCHED]:
			n += 1
	return n


func caught() -> int:
	var n := 0
	for c in claims:
		if c.status in [Claim.CONTRADICTED, Claim.EXPOSED]:
			n += 1
	return n


func forbidden_now() -> Array:
	## Facts that would currently expose a live claim (for HUD warnings).
	var out: Array = []
	for c in live_claims():
		for f in c.contradicted_by:
			if not f in out:
				out.append(f)
	return out


# ---------------------------------------------------------------------------
# Credibility
# ---------------------------------------------------------------------------

func chance(base: float, tags: Array = [], listener: String = "") -> float:
	## Percent chance (5..95) that a bluff lands, given everything known.
	if not Game.active:
		return 50.0
	var c := base + float(Game.diff().cred)
	c -= Game.stats.get_value("susp") * 0.22
	c += (Game.stats.get_value("ill") - 45.0) * 0.18
	c += Game.npcs.trust(listener if listener != "" else Game.npcs.boss_id())
	if Game.stats.has_buff("wired"):
		c -= 16.0
	elif Game.stats.has_buff("jitter"):
		c -= 8.0
	if Game.stats.has_buff("jargon"):
		c += 12.0 if "jargon" in tags else 6.0
	if Game.stats.get_value("energy") < 20.0:
		c -= 10.0
	if "video" in tags:
		match Game.home.outfit:
			"shirt":
				c += 9.0
			"pajamas":
				c -= 10.0
		if Game.home.desk_staged():
			c += 6.0
		c += minf(float(Game.home.decor), 4.0)          # a desk with a trophy on it looks employed
	if "favor" in tags:
		c += float(Game.economy.favors) * 6.0
	return clampf(c, 5.0, 95.0)


func roll(base: float, tags: Array = [], listener: String = "") -> bool:
	return Game.chance(chance(base, tags, listener))


func evidence_for(type: String) -> Array:
	## Ids of the supporting evidence that is true right now.
	var out: Array = []
	for ev in def(type).get("evidence", {}):
		if has_evidence(str(ev)):
			out.append(str(ev))
	return out


func has_evidence(ev: String) -> bool:
	match ev:
		"router_off":
			return not Game.home.router_on()
		"laptop_updating":
			return Game.home.laptop_updating()
		"doctor_note":
			return int(Game.home.things.get("notes", 0)) > 0
		"calendar_block":
			return Game.comms.calendar_block_now()
		"incident_active":
			return Game.time.now() < int(Game.flags.get("incident_until", -1))
		"outage_reported":
			return Game.time.now() < int(Game.flags.get("isp_until", -1))
		"form_filed":
			return Game.flag("cr_day_%d" % Game.time.day) or Game.flag("fax_form")
		"family_alibi":
			return Game.flag("nana_alibi")
		"clarification_open":
			for t in Game.work.open_tasks():
				if bool(t.clarified):
					return true
			return false
		"printer_jam":
			return bool(Game.home.things.get("jam", false))
		"high_illusion":
			return Game.stats.get_value("ill") >= 60.0
	return false


const EVIDENCE_TEXT := {
	"router_off": "router unplugged", "laptop_updating": "laptop really updating", "doctor_note": "doctor's note",
	"calendar_block": "calendar block", "incident_active": "a real incident is on", "outage_reported": "IT reported outages",
	"form_filed": "Form 27-B on file", "clarification_open": "clarification pending", "printer_jam": "jammed printer",
	"high_illusion": "you look busy", "family_alibi": "a grandmother who will swear to it",
}


func verifying() -> bool:
	## From midweek the manager checks what he is told.
	return Game.flag("verify_mode") or Game.npcs.escalation >= 2


func conflict_with(type: String, listener: String) -> Claim:
	## A live claim this listener knows about that cannot be true together with `type`.
	var d := def(type)
	for c in live_claims():
		if not Game.npcs.knows(listener, c.id):
			continue
		if c.type in d.get("conflicts", []) or type in def(c.type).get("conflicts", []):
			return c
	return null


func claim_chance(type: String, context: String, listener: String) -> float:
	var d := def(type)
	var tags: Array = ["video"] if context == "video" else []
	var c := chance(float(d.base), tags, listener)
	c -= float(d.reuse_penalty) * float(uses(type))
	for ev in evidence_for(type):
		c += float(d.evidence[ev])
	if Game.stats.has_buff("inspired"):
		c += 10.0
	if verifying() and evidence_for(type).is_empty():
		c -= 10.0         # "trust, but verify": stories without proof are a harder sell
	return clampf(c, 5.0, 95.0)


func options(context: String, listener: String) -> Array:
	## The excuses on offer in a situation, with everything the UI shows.
	var ctx := "meeting" if context in ["video", "phone"] else context
	var out: Array = []
	for type in Db.claims:
		var d: Dictionary = Db.claims[type]
		if not ctx in d.contexts:
			continue
		var ev_text: Array = []
		for ev in evidence_for(type):
			ev_text.append(str(EVIDENCE_TEXT.get(ev, ev)))
		var clash := conflict_with(type, listener)
		out.append({
			"id": type, "title": str(d.title), "label": str(d.line), "strength": str(d.strength), "weakness": str(d.weakness),
			"chance": claim_chance(type, context, listener), "uses": uses(type), "evidence": ev_text,
			"burned": burned(type), "conflict": "" if clash == null else str(def(clash.type).title),
		})
	return out


static func odds_word(pct: float) -> String:
	if pct >= 80.0:
		return "Safe"
	if pct >= 62.0:
		return "Likely"
	if pct >= 45.0:
		return "Coin flip"
	if pct >= 28.0:
		return "Risky"
	return "Desperate"


static func odds_color(pct: float) -> Color:
	if pct >= 62.0:
		return Color("5ad17a")
	if pct >= 45.0:
		return Color("ffd166")
	if pct >= 28.0:
		return Color("ff8c5a")
	return Color("ff5d73")


# ---------------------------------------------------------------------------
# Telling a lie
# ---------------------------------------------------------------------------

func attempt(type: String, context: String, listener: String, about: String = "", task_id: String = "", forced: bool = false) -> Dictionary:
	## Tell the lie. Returns {ok, say, claim, contradiction}.
	## `forced` skips the roll (the story was handed to you by an event).
	var d := def(type)
	var res := {"ok": false, "say": "", "claim": null, "contradiction": false, "id": type}
	if d.is_empty():
		return res
	Game.bump("excuses")
	var c := _new_claim(type, context, listener, about, task_id)
	# Worn-out stories and stories that clash with what this person already
	# heard are caught on the spot.
	var clash := conflict_with(type, listener)
	if burned(type) or clash != null:
		c.status = Claim.EXPOSED
		c.contradiction = "worn_out" if clash == null else "conflict"
		claims.append(c)
		res.claim = c
		res.contradiction = true
		if clash == null:
			res.say = "That's the fourth '%s' this week. I've started a spreadsheet about you." % str(d.title).to_lower()
		else:
			res.say = "Hang on. Earlier it was '%s'. Which is it?" % str(def(clash.type).title).to_lower()
			_set_status(clash, Claim.EXPOSED)
		_penalise(c, 9.0, "Contradictory excuse")
		claim_added.emit(c)
		return res
	var ok := forced or Game.chance(claim_chance(type, context, listener))
	if Game.stats.has_buff("inspired"):
		Game.stats.remove_buff("inspired")
	if "doctor_note" in c.evidence:
		Game.home.things.notes = int(Game.home.things.notes) - 1
		Bus.thing_changed.emit("printer")
	claims.append(c)
	res.claim = c
	Game.npcs.learn(listener, c.id)
	for w in c.witnesses:
		Game.npcs.learn(str(w), c.id)
	if not ok:
		c.status = Claim.REJECTED
		res.say = str(d.rejected)
		Game.bump("excuses_failed")
		Game.npcs.irritate(listener, 3.0)
		claim_added.emit(c)
		return res
	res.ok = true
	res.say = str(d.accepted).replace("{subject}", c.subject)
	if int(d.cover) > 0:
		Game.presence.grant_cover(int(d.cover), type)
	_apply_effect(c, d.get("effect", {}))
	_schedule_followups(c, d)
	if not c.contradicted_by.is_empty():
		var avoid: Array = []
		for f in c.contradicted_by:
			if AVOID.has(f):
				avoid.append(str(AVOID[f]))
		if not avoid.is_empty():
			Bus.toast.emit("Your story is on record for %s. Don't %s." % [Cfg.fmt_dur(float(d.duration)), avoid[0]], "warn")
	claim_added.emit(c)
	return res


func _new_claim(type: String, context: String, listener: String, about: String, task_id: String) -> Claim:
	var d := def(type)
	var c := Claim.new()
	c.id = Game.next_id("c")
	c.type = type
	var subjects: Array = d.get("subjects", [])
	c.subject = str(Game.pick(subjects)) if not subjects.is_empty() else ""
	c.told_to = listener
	c.about = about
	c.context = context
	c.made_at = Game.time.now()
	c.expires_at = c.made_at + int(d.duration)
	c.witnesses = [listener]
	var boss := Game.npcs.boss_id()
	if context != "chat" and not boss in c.witnesses:
		c.witnesses.append(boss)          # the boss is in every meeting
	c.contradicted_by = d.get("contradicted_by", []).duplicate()
	c.evidence = evidence_for(type)
	c.risk = clampi(int(d.risk) + Game.npcs.escalation * 8 + (20 if verifying() else 0) - (10 if not c.evidence.is_empty() else 0), 0, 100)
	c.task = task_id
	if c.task == "" and bool(d.get("ticket_scoped", false)):
		c.task = str(Game.work.most_urgent_task().get("id", ""))     # the ticket being asked about
	return c


func _apply_effect(c: Claim, fx: Dictionary) -> void:
	if fx.has("extend") and c.task != "":
		Game.work.extend_deadline(c.task, int(fx.extend))
	if fx.has("ill"):
		Game.stats.add("ill", float(fx.ill), str(def(c.type).title))
	if fx.has("flag"):
		Game.set_flag(str(fx.flag))


func _schedule_followups(c: Claim, d: Dictionary) -> void:
	var win := float(Game.diff().window)
	for i in d.get("followups", []).size():
		var f: Dictionary = d.followups[i]
		var p := float(f.get("chance", 100))
		if str(f.get("kind", "")) == "verify":
			p = float(c.risk)
			if str(f.get("fact", "")) in ["router_on", "calendar_free"]:
				p = 100.0         # these are always checked; the outcome depends on the truth
		if not Game.chance(p):
			continue
		var after: Array = f.get("after", [10, 10])
		var delay := int(round(float(Game.rng.randi_range(int(after[0]), int(after[1]))) * (win if str(f.kind) == "verify" else 1.0)))
		Game.time.schedule(c.made_at + maxi(1, delay), "claim_followup", {"claim": c.id, "i": i})


# ---------------------------------------------------------------------------
# Facts and contradictions
# ---------------------------------------------------------------------------

func observe(fact: String, _data: Dictionary = {}) -> void:
	## Something the player visibly did. Check it against every live claim.
	if not Game.time.running() or Game.time.phase != "work":
		return
	var now := Game.time.now()
	for c in live_claims():
		if c.status != Claim.ACTIVE and c.status != Claim.VERIFIED:
			continue
		if not fact in c.contradicted_by:
			continue
		if now - c.made_at < int(GRACE.get(fact, DEFAULT_GRACE)):
			continue
		if fact == "ticket_activity" and bool(def(c.type).get("ticket_scoped", false)) and c.task != "" and str(_data.get("task", "")) != c.task:
			continue          # blocked on one ticket; this is a different one
		_contradict(c, fact)


func _contradict(c: Claim, fact: String) -> void:
	c.status = Claim.CONTRADICTED
	c.contradiction = fact
	if Game.presence.cover_cat == c.type:
		Game.presence.end_cover()
	_penalise(c, 7.0, "Contradiction: %s" % str(def(c.type).title))
	Bus.toast.emit("CONTRADICTION: you claimed '%s', then: %s." % [str(def(c.type).title).to_lower(), str(FACTS.get(fact, fact))], "bad")
	claim_changed.emit(c)
	contradiction.emit(c, fact)
	# The witness will want an explanation.
	Game.time.schedule(Game.time.now() + Game.rng.randi_range(2, 5), "claim_confront", {"claim": c.id})


func _penalise(c: Claim, susp: float, reason: String) -> void:
	Game.bump("contradictions")
	Game.stats.add("susp", susp, reason)
	Game.npcs.caught_lying(c.told_to)
	Bus.sfx.emit("bad")
	Game.time.alert()


func _set_status(c: Claim, status: String) -> void:
	if c.status == status:
		return
	c.status = status
	claim_changed.emit(c)


func resolve(claim_id: String, status: String) -> void:
	## The outcome of a confrontation: "patched" or "exposed".
	var c := claim(claim_id)
	if c == null:
		return
	_set_status(c, status)
	if status == Claim.EXPOSED:
		Game.npcs.irritate(c.told_to, 5.0)


func _on_timer(event: String, args: Dictionary) -> void:
	match event:
		"claim_followup":
			_followup(str(args.claim), int(args.i))
		"claim_confront":
			_confront(str(args.claim))


func _followup(claim_id: String, index: int) -> void:
	var c := claim(claim_id)
	if c == null:
		return
	var f: Dictionary = def(c.type).followups[index]
	match str(f.kind):
		"verify":
			if c.status != Claim.ACTIVE:
				return
			var fact := str(f.fact)
			_checked[c.id] = true
			if fact_holds(fact, c):
				_contradict(c, fact)
			else:
				_set_status(c, Claim.VERIFIED)
				Game.stats.add("susp", -3.0, "Your story checked out")
				Game.npcs.adjust(c.told_to, 1.5)
				var who := str(f.get("who", c.told_to))
				if f.has("ok_line"):
					Game.comms.say(who, str(f.ok_line))
				Bus.toast.emit("Someone checked your '%s' story. It held up." % str(def(c.type).title).to_lower(), "good")
		"event":
			# Stories that were caught do not get their polite follow-up.
			if c.status in [Claim.CONTRADICTED, Claim.EXPOSED, Claim.REJECTED]:
				return
			Game.events.fire(str(f.event), {"claim": c.id, "subject": c.subject, "task": c.task})


func fact_holds(fact: String, c: Claim) -> bool:
	## Is the contradicting fact true when somebody goes and looks?
	match fact:
		"router_on":
			return Game.home.router_on()
		"calendar_free":
			return not Game.comms.block_covers(Game.time.day, c.made_at % 1440)
		"no_incident":
			return not "incident_active" in c.evidence
		"team_denies":
			return not "clarification_open" in c.evidence
		"no_form":
			return not "form_filed" in c.evidence
		"online_status":
			return Game.presence.status in ["online", "busy"]
	return true


func _confront(claim_id: String) -> void:
	var c := claim(claim_id)
	if c == null or c.status != Claim.CONTRADICTED:
		return
	var d := def(c.type)
	var lines: Dictionary = d.get("exposed", {})
	var text := str(lines.get(c.contradiction, lines.get("default", "That doesn't match what you told me earlier. Explain?")))
	var choices: Array = d.get("recoveries", []).duplicate(true)
	choices.append({"t": "Come clean. \"I made that up.\"", "a": "honest", "ok": {"susp": 6, "claim_status": "exposed", "rel": 2, "say": "...I appreciate the honesty. I'm still writing it down."}})
	var who := c.told_to if Game.npcs.has(c.told_to) else Game.npcs.boss_id()
	# One conversation at a time: wait until they are not already waiting on you.
	if Game.comms.in_call() or not Game.comms.prompt_for_thread(Game.comms.dm_thread(who)).is_empty():
		Game.time.schedule(Game.time.now() + 4, "claim_confront", {"claim": c.id})
		return
	Game.comms.add_prompt({
		"id": "confront", "from": who, "text": text.replace("{subject}", c.subject), "choices": choices,
		"window": 16, "no_excuse": true, "claim": c.id,
		"expire": {"susp": 9, "claim_status": "exposed", "say": "No answer. I'll take that as a confession."},
	})


func _on_minute() -> void:
	if not Game.time.running():
		return
	var now := Game.time.now()
	for c in claims:
		if not c.settled and c.is_active() and now >= c.expires_at:
			_settle(c)
	if Game.time.phase != "work":
		return
	# Derived facts: what your status dot is telling everyone.
	if Game.presence.status in ["online", "busy"]:
		observe("online_status")
	# Office gossip: a story told to a coworker eventually reaches the boss.
	# Friends keep it to themselves; people who dislike you pass it on faster.
	var boss := Game.npcs.boss_id()
	for c in live_claims():
		if c.told_to != boss and not Game.npcs.knows(boss, c.id) and Game.chance(1.2 * Game.social.gossip_factor(c.told_to)):
			Game.npcs.learn(boss, c.id)
			c.witnesses.append(boss)
			var clash := conflict_with(c.type, boss)
			if clash != null and clash.id != c.id:
				Game.comms.say(boss, "%s tells me it's '%s'. You told me '%s'. Interesting." % [Game.npcs.first_name(c.told_to), str(def(c.type).title).to_lower(), str(def(clash.type).title).to_lower()])
				_contradict(c, "conflict")


func _settle(c: Claim) -> void:
	## The story ran its course without being caught: a successful deception.
	c.settled = true
	if c.status == Claim.ACTIVE:
		_set_status(c, Claim.EXPIRED)
	Game.bump("lies_landed")


func close_day() -> void:
	## 17:00: nobody remembers to check what is still pending.
	for c in claims:
		if c.settled:
			continue
		if c.is_active():
			_settle(c)
			c.expires_at = mini(c.expires_at, Game.time.now())
		elif c.status == Claim.CONTRADICTED:
			c.settled = true
			_set_status(c, Claim.EXPOSED)


func describe(c: Claim) -> Dictionary:
	## Everything the ledger UI shows for one claim.
	var d := def(c.type)
	var avoid: Array = []
	for f in c.contradicted_by:
		if AVOID.has(f):
			avoid.append(str(AVOID[f]))
	var ev: Array = []
	for e in c.evidence:
		ev.append(str(EVIDENCE_TEXT.get(e, e)))
	return {
		"id": c.id, "title": str(d.get("title", c.type)), "subject": c.subject, "status": c.status,
		"status_text": str(Claim.STATUS_TEXT.get(c.status, c.status)),
		"when": "%s %s" % [Cfg.DAYS_SHORT[clampi(int(c.made_at / 1440.0), 0, 4)], Cfg.fmt_time(float(c.made_at % 1440))],
		"told_to": Game.npcs.first_name(c.told_to), "about": c.about,
		"left": maxi(0, c.expires_at - Game.time.now()) if c.is_live(Game.time.now()) else 0,
		"live": c.is_live(Game.time.now()), "avoid": avoid, "evidence": ev, "risk": c.risk,
		"contradiction": str(FACTS.get(c.contradiction, c.contradiction)),
	}
