class_name Social
extends GameSystem
## Social — your colleagues, and what they are good for.
##
## NPCManager keeps the numbers (relationship, mood); this system gives them
## consequences. A colleague you leave hanging may tell the manager. One you
## befriend stops telling on you and starts doing things so that you don't
## have to. Who counts as a colleague, how readily they snitch and which
## favours they offer is data on their NpcDef: nothing here names anyone.

signal tier_changed(npc: String, tier: int, up: bool)
signal snitched(npc: String, how: String)

enum Tier { HOSTILE, COLD, NEUTRAL, FRIENDLY, FRIEND }

## Friendship tiers: the relationship at which each begins, how much more or
## less likely that person is to tell on you, and how fast your stories
## travel from them to the manager.
const TIERS := [
	{"name": "Has it in for you", "at": 0.0, "snitch": 1.6, "gossip": 2.0, "color": Color("ff5d73")},
	{"name": "Cold", "at": 25.0, "snitch": 1.15, "gossip": 1.4, "color": Color("ff8c5a")},
	{"name": "Colleague", "at": 42.0, "snitch": 0.7, "gossip": 1.0, "color": Color("aaa3cc")},
	{"name": "Friendly", "at": 62.0, "snitch": 0.0, "gossip": 0.0, "color": Color("5ad1c8")},
	{"name": "Partner in crime", "at": 80.0, "snitch": 0.0, "gossip": 0.0, "color": Color("5ad17a")},
]
const SNITCH_SUSP := {"message": 5.0, "call": 6.0, "absence": 4.0}
const SNITCH_PER_DAY := 2        ## one colleague tells on you at most this often per day
const FOLLOW_UP := 40.0          ## % chance the manager then asks you about it himself
const WATCH_AFTER := 25          ## unexplained minutes before someone who dislikes you notices
const GIFT_PRICE := 45
const GIFT_REL := 8.0
const TALK_REL := 3.0
const TALK_BACKFIRE := 18.0      ## % chance small talk reminds them they wanted something
const PICKUP_REL := 1.5          ## they remember who picks up
const HYPE_AT := 615             ## minute of the day a friend with "hype" posts about you
const HYPE_ILL := 5.0
## Favour type -> the action it is classified as (see WorkSystem.DEFS).
const ACTIONS := {"ticket": "delegate_colleague", "skip_meeting": "delegate_colleague"}

var tiers: Dictionary = {}       ## npc -> tier last announced, to notice changes
var used: Dictionary = {}        ## "npc:favour" or "talk:npc" -> day it was last used
var told: Dictionary = {}        ## npc -> times they told on you today


func _ready() -> void:
	Game.npcs.relationship_changed.connect(_on_relationship)
	Game.time.minute_passed.connect(_on_minute)


func setup_run() -> void:
	Db.load_all()
	tiers = {}
	used = {}
	told = {}
	for id in colleagues():
		tiers[id] = tier(id)


func new_day() -> void:
	told = {}


func save_state() -> Dictionary:
	return {"tiers": tiers, "used": used, "told": told}


func load_state(d: Dictionary) -> void:
	setup_run()
	var saved: Dictionary = d.get("tiers", {})
	for id in saved:
		tiers[id] = int(saved[id])
	used = d.get("used", {})
	told = d.get("told", {})


# --- Who, and how close ------------------------------------------------------

func colleagues() -> Array:
	var out: Array = []
	for id in Db.npcs:
		if bool(Db.npcs[id].get("colleague", false)):
			out.append(id)
	return out


func is_colleague(id: String) -> bool:
	return bool(Game.npcs.def(id).get("colleague", false))


func tier(id: String) -> int:
	var rel := Game.npcs.relationship(id)
	var out := 0
	for i in TIERS.size():
		if rel >= float(TIERS[i].at):
			out = i
	return out


func tier_name(id: String) -> String:
	return str(TIERS[tier(id)].name)


func tier_color(id: String) -> Color:
	return TIERS[tier(id)].color


func to_next_tier(id: String) -> int:
	## Relationship points missing for the next tier (0 at the top).
	var t := tier(id)
	if t >= TIERS.size() - 1:
		return 0
	return int(ceil(float(TIERS[t + 1].at) - Game.npcs.relationship(id)))


func snitch_chance(id: String) -> float:
	## Percent chance this person tells the manager when you don't answer.
	if not is_colleague(id):
		return 0.0
	return clampf(float(Game.npcs.def(id).get("snitch", 0.0)) * float(TIERS[tier(id)].snitch) * 100.0, 0.0, 95.0)


func gossip_factor(id: String) -> float:
	## How fast a story told to this person reaches the manager (1 = normal).
	return float(TIERS[tier(id)].gossip) if is_colleague(id) else 1.0


func lines_for(id: String, key: String) -> Array:
	var own: Array = Game.npcs.def(id).get("lines", {}).get(key, [])
	return own if not own.is_empty() else Db.lines(key)


func line_for(id: String, key: String) -> String:
	var options := lines_for(id, key)
	if options.is_empty():
		return ""
	return str(Game.pick(options)).replace("{who}", Game.npcs.first_name(id))


# --- Leaving them hanging ----------------------------------------------------

func picked_up(id: String) -> void:
	if is_colleague(id):
		Game.npcs.adjust(id, PICKUP_REL)


func unanswered(id: String, how: String = "message", declined: bool = false) -> bool:
	## A colleague tried to reach you and got nothing. Returns true if they
	## went and told the manager about it.
	if not is_colleague(id) or not Game.time.running():
		return false
	Game.bump("colleagues_ignored")
	if Game.presence.covered():
		return false                # they think you are legitimately out, and leave it at that
	if how == "call":
		Game.npcs.adjust(id, -2.0 if declined else -4.0)
		Game.npcs.irritate(id, 3.0 if declined else 6.0)
		var missed := line_for(id, "missed_call")
		if missed != "":
			Game.comms.post(Game.comms.dm_thread(id), id, missed, "bad")
	var chance := snitch_chance(id) * (0.5 if declined else 1.0)      # "no" is at least an answer
	if int(told.get(id, 0)) >= SNITCH_PER_DAY or not Game.chance(chance):
		return false
	_tell_boss(id, how)
	return true


func _tell_boss(id: String, how: String) -> void:
	told[id] = int(told.get(id, 0)) + 1
	var rec := Game.npcs.record(id)
	rec["snitched"] = int(rec.get("snitched", 0)) + 1
	Game.bump("snitched")
	var boss := Game.npcs.boss_id()
	var who := Game.npcs.first_name(id)
	Game.stats.add("susp", float(SNITCH_SUSP.get(how, 5.0)), "%s told %s" % [who, Game.npcs.boss_name()])
	if not Game.time.running():
		return
	Game.npcs.irritate(boss, 3.0)
	var what := "you've been away from your desk" if how == "absence" else ("you didn't pick up" if how == "call" else "you didn't answer")
	Bus.toast.emit("%s told %s %s." % [who, Game.npcs.boss_name(), what], "bad")
	Bus.sfx.emit("bad")
	Game.tutor.hint("snitch")
	if how != "absence" and Game.chance(FOLLOW_UP * float(Game.diff().boss_check)):
		Game.events.fire_later(Game.rng.randi_range(2, 5), "snitch_followup", {"who": id, "urgent": true})
	else:
		var line := line_for(id, "snitch_absence" if how == "absence" else "snitch")
		if line != "":
			Game.comms.say(boss, line)
	snitched.emit(id, how)


func _on_minute() -> void:
	## Someone who has it in for you watches your status dot.
	if not Game.time.running() or not Game.time.in_work_hours():
		return
	if int(Game.time.minute) == HYPE_AT:
		for id in who_can("hype"):
			Game.comms.post("team", id, line_for(id, "hype"), "good")
			Game.stats.add("ill", HYPE_ILL, "%s talked you up" % Game.npcs.first_name(id))
	if Game.presence.absent_run != WATCH_AFTER:
		return
	for id in colleagues():
		if tier(id) == Tier.HOSTILE and int(told.get(id, 0)) < SNITCH_PER_DAY and Game.chance(60.0):
			_tell_boss(id, "absence")
			return


func _on_relationship(id: String, _value: float) -> void:
	if not Game.active or not is_colleague(id):
		return
	var now := tier(id)
	var before := int(tiers.get(id, now))
	tiers[id] = now
	if now == before:
		return
	var up := now > before
	tier_changed.emit(id, now, up)
	if not Game.time.running():
		return
	var who := Game.npcs.first_name(id)
	if up and now >= Tier.FRIENDLY:
		var unlocked: Array = []
		for f in favours(id):
			if int(f.get("tier", Tier.FRIENDLY)) == now:
				unlocked.append(str(f.title))
		var extra := "" if unlocked.is_empty() else " New: %s." % ", ".join(unlocked)
		Bus.toast.emit("%s is now: %s. They won't tell on you any more.%s" % [who, tier_name(id), extra], "good")
		var line := line_for(id, "friend" if now == Tier.FRIEND else "friendly")
		if line != "" and Game.time.phase == "work":
			Game.comms.say(id, line, false)
		Game.tutor.hint("friend")
	elif not up and now <= Tier.COLD:
		Bus.toast.emit("%s is now: %s. Leave them hanging and %s hears about it." % [who, tier_name(id), Game.npcs.boss_name()], "bad")
		if now == Tier.HOSTILE:
			var line := line_for(id, "hostile")
			if line != "" and Game.time.phase == "work":
				Game.comms.say(id, line, false)


# --- Favours: what a friend does so you don't have to -------------------------

func favours(id: String) -> Array:
	return Game.npcs.def(id).get("favours", [])


func favour(id: String, favour_id: String) -> Dictionary:
	for f in favours(id):
		if str(f.id) == favour_id:
			return f
	return {}


func has_perk(id: String, type: String) -> bool:
	## Is this colleague close enough to do `type` for you?
	for f in favours(id):
		if str(f.type) == type and tier(id) >= int(f.get("tier", Tier.FRIENDLY)):
			return true
	return false


func who_can(type: String) -> Array:
	## Colleagues who would do `type` for you right now, closest friend first.
	var out: Array = []
	for id in colleagues():
		if has_perk(id, type):
			out.append(id)
	out.sort_custom(func(a, b): return Game.npcs.relationship(a) > Game.npcs.relationship(b))
	return out


func favour_view(id: String, f: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	## Everything the UI needs to offer one favour: {id, title, hint, cost,
	## act, passive, locked, ok, why}.
	var type := str(f.type)
	var v := {
		"id": str(f.id), "title": str(f.title), "hint": str(f.get("hint", "")), "cost": int(f.get("cost", 1)),
		"act": str(ACTIONS.get(type, "ask_favor")), "passive": bool(f.get("passive", false)),
		"locked": false, "ok": true, "why": "",
	}
	var need := int(f.get("tier", Tier.FRIENDLY))
	if tier(id) < need:
		v.ok = false
		v.locked = true
		v.why = "Needs: %s (+%d)" % [str(TIERS[need].name), int(ceil(float(TIERS[need].at) - Game.npcs.relationship(id)))]
		return v
	if bool(v.passive):
		return v
	var why := ""
	if Game.economy.favors < int(v.cost):
		why = "Needs %d favour%s (you have %d)" % [int(v.cost), "" if int(v.cost) == 1 else "s", Game.economy.favors]
	elif int(used.get("%s:%s" % [id, str(f.id)], -1)) == Game.time.day and not bool(f.get("repeat", false)):
		why = "Already asked today"
	else:
		why = _blocked(type, f, ctx)
	v.ok = why == ""
	v.why = why
	return v


func _blocked(type: String, f: Dictionary, ctx: Dictionary) -> String:
	match type:
		"ticket", "bury":
			if _task_for(ctx).is_empty():
				return "No open ticket to hand over"
		"cover":
			if not Game.time.in_work_hours():
				return "Outside work hours"
			if Game.presence.covered():
				return "You are already covered"
		"skip_meeting":
			if _next_meeting(f).is_empty():
				return "No meeting left today they could take"
	return ""


func _task_for(ctx: Dictionary) -> Dictionary:
	## The ticket a favour applies to: the one named, or the most urgent one
	## nobody else is doing.
	var named := Game.work.task(str(ctx.get("task", "")))
	if not named.is_empty():
		return named if str(named.status) == "open" and str(named.by) == "" else {}
	for t in Game.work.open_tasks():
		if str(t.by) == "":
			return t
	return {}


func _next_meeting(f: Dictionary) -> Dictionary:
	for m in Game.comms.meetings_today():
		if str(m.state) != "upcoming" or str(m.kind) != "meeting" or bool(m.get("casual", false)):
			continue
		if not Game.comms.can_dodge(m) or (bool(m.mandatory) and not bool(f.get("mandatory", false))):
			continue
		return m
	return {}


func ask(id: String, favour_id: String, ctx: Dictionary = {}) -> bool:
	## Call in a favour. Returns false if it could not be asked.
	var f := favour(id, favour_id)
	if f.is_empty() or not is_colleague(id):
		return false
	var v := favour_view(id, f, ctx)
	if bool(v.passive):
		return false
	if not bool(v.ok):
		Bus.toast.emit(str(v.why) + ".", "warn")
		return false
	var who := Game.npcs.first_name(id)
	if not Game.work.perform(str(v.act), {"label": "%s: %s" % [who, str(f.title)]}):
		return false
	Game.economy.add_favor(-int(v.cost))
	used["%s:%s" % [id, str(f.id)]] = Game.time.day
	Game.bump("favours_called")
	Game.deception.observe("desk_message")
	Game.presence.touch()
	var thread := Game.comms.dm_thread(id)
	var say := str(f.get("say", "On it."))
	Game.comms.post(thread, "me", str(f.get("ask", f.title)))
	match str(f.type):
		"ticket":
			var t := _task_for(ctx)
			t.by = id
			t["botch"] = float(f.get("botch", 0.04))
			t.helper_left = int(t.effort) * int(f.get("speed", 30))
			Game.bump("tasks_delegated")
			say = say.replace("{task}", str(t.key))
			Bus.task_changed.emit(t)
		"bury":
			var t := _task_for(ctx)
			say = say.replace("{task}", str(t.key))
			Game.work.lose_task(str(t.id))
		"cover":
			Game.presence.grant_cover(int(f.get("minutes", 45)), "colleague")
			Bus.toast.emit("%s is covering for you: %d minutes nobody will ask where you are." % [who, int(f.get("minutes", 45))], "good")
		"vouch":
			Game.stats.add("susp", -absf(float(f.get("susp", 5.0))), "%s vouched for you" % who)
			Game.stats.add("ill", float(f.get("ill", 0.0)), "%s vouched for you" % who)
			Game.npcs.irritate(Game.npcs.boss_id(), -float(f.get("calm", 4.0)))
			if str(f.get("public", "")) != "":
				Game.comms.post("team", id, str(f.public), "good")
		"distract":
			var mins := int(f.get("minutes", 40))
			Game.flags["boss_busy_until"] = Game.time.now() + mins
			Bus.toast.emit("%s is keeping %s busy for %d minutes. He will not come looking for you." % [who, Game.npcs.boss_name(), mins], "good")
		"intel":
			var seen := Game.events.forecast()
			say += "\n" + ("\n".join(seen) if not seen.is_empty() else "Nothing on the radar for the rest of today. Enjoy it.")
		"skip_meeting":
			var m := _next_meeting(f)
			m.state = "excused"
			Game.bump("meetings_avoided")
			say = say.replace("{meeting}", str(m.title))
			Bus.toast.emit("%s is taking \"%s\" for you." % [who, str(m.title)], "good")
			Bus.meeting_changed.emit(m)
	Game.comms.post(thread, id, say, "good")
	Bus.sfx.emit("good")
	Bus.comms_changed.emit()
	return true


func ask_type(id: String, type: String, ctx: Dictionary = {}) -> bool:
	for f in favours(id):
		if str(f.type) == type and not bool(f.get("passive", false)):
			return ask(id, str(f.id), ctx)
	return false


func wingman(m: Dictionary) -> String:
	## A friend sitting in this meeting who will take a question for you.
	if m.is_empty() or str(m.kind) != "meeting" or bool(m.get("casual", false)) or bool(m.get("private", false)) or bool(m.get("no_dodge", false)):
		return ""
	for id in who_can("wingman"):
		if bool(Game.npcs.def(id).get("in_meetings", false)):
			return id
	return ""


func tip_off(what: String) -> bool:
	## A friend who hears things warns you before a surprise check.
	if not Game.time.running() or not Game.time.in_work_hours():
		return false
	for id in who_can("tipoff"):
		var line := line_for(id, "tip_" + what)
		if line == "":
			continue
		Game.comms.say(id, line)
		Game.bump("tipoffs")
		return true
	return false


func leverage(from: String) -> Dictionary:
	## The one-time card you hold once you know something about this person.
	if from == "" or not Game.flag("dirt_" + from) or Game.flag("dirt_%s_used" % from):
		return {}
	for c in Db.lines("leverage"):
		if str(c.get("on", "")) == from:
			return c
	return {}


# --- Being nice on purpose ----------------------------------------------------

func talked_today(id: String) -> bool:
	return int(used.get("talk:" + id, -1)) == Game.time.day


func small_talk(id: String) -> bool:
	## Strike up a conversation. Cheap friendship, once a day per person, and
	## the usual risk of starting conversations: they remember they wanted something.
	if not is_colleague(id) or not Game.time.running():
		return false
	if talked_today(id):
		Bus.toast.emit("You already chatted with %s today. Twice would look like you have nothing to do." % Game.npcs.first_name(id), "warn")
		return false
	if not Game.work.perform("small_talk", {"label": "Small talk with %s" % Game.npcs.first_name(id)}):
		return false
	used["talk:" + id] = Game.time.day
	var thread := Game.comms.dm_thread(id)
	Game.comms.post(thread, "me", str(Game.pick(Db.lines("small_talk"))))
	Game.comms.post(thread, id, line_for(id, "small_talk"), "good")
	Game.npcs.adjust(id, TALK_REL)
	Game.npcs.irritate(id, -2.0)
	Game.bump("small_talk")
	Game.deception.observe("desk_message")
	Game.presence.touch()
	Bus.sfx.emit("pop")
	Bus.comms_changed.emit()
	if Game.chance(TALK_BACKFIRE):
		var asks: Array = []
		for ev in Db.events:
			var def: Dictionary = Db.events[ev]
			if str(def.pool) == "peer" and str(def.from) == id and Game.events.check(def.conditions, {}, true):
				asks.append(ev)
		if not asks.is_empty():
			Game.events.fire_later(Game.rng.randi_range(2, 5), str(Game.pick(asks)), {})
	return true


func can_gift() -> bool:
	return Game.active and not Game.flag("bribe_day_%d" % Game.time.day)


func gift_price() -> int:
	return Game.economy.price(GIFT_PRICE)


func gift_target() -> String:
	## Who a gift does the most good for: whoever is closest to the next tier.
	var best := ""
	var gap := 999
	for id in colleagues():
		var d := to_next_tier(id)
		if d > 0 and d < gap:
			gap = d
			best = id
	if best == "" and not colleagues().is_empty():
		best = str(colleagues()[0])
	return best


func gift(id: String = "") -> bool:
	## A gift card: one favour and a lot of goodwill, for cash. One per day.
	if id == "":
		id = gift_target()
	if not is_colleague(id):
		return false
	if not can_gift():
		Bus.toast.emit("One suspiciously generous gift card per day is the limit.", "warn")
		return false
	var cost := gift_price()
	if not Game.economy.can_afford(cost):
		Bus.toast.emit("You can't afford that. Payday is at 17:00.", "warn")
		return false
	if not Game.work.perform("gift", {"label": "Gift card for %s" % Game.npcs.first_name(id)}):
		return false
	Game.set_flag("bribe_day_%d" % Game.time.day)
	Game.economy.add_money(-cost, "Gift card")
	Game.economy.add_favor(1)
	Game.npcs.adjust(id, GIFT_REL)
	Game.npcs.irritate(id, -4.0)
	Game.bump("gifts")
	var who := Game.npcs.first_name(id)
	Bus.sfx.emit("buy")
	Bus.toast.emit("%s got a gift card. %s now owes you one." % [who, who], "money")
	var line := line_for(id, "gift")
	if line != "" and Game.time.phase == "work":
		Game.comms.say(id, line, false)
	return true
