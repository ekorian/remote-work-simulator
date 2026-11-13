class_name NPCManager
extends GameSystem
## NPCManager — the people of SynerCorp and what each of them thinks of you.
##
## Every NpcDef under resources/npcs gets a runtime record: relationship,
## irritation (which drives mood), which of your claims they have heard,
## and how often they have caught you lying. The manager flagged `is_boss`
## additionally has an escalation state driven by suspicion. Adding a
## character is adding a resource file; nothing here names anyone.

signal mood_changed(npc: String, mood: String)
signal relationship_changed(npc: String, value: float)
signal escalated(level: int)

const MOOD_INFO := {
	"pleased": {"label": "pleased with you", "trust": 6.0, "color": Color("5ad17a")},
	"neutral": {"label": "neutral", "trust": 0.0, "color": Color("9aa39b")},
	"annoyed": {"label": "annoyed", "trust": -2.0, "color": Color("ffd166")},
	"suspicious": {"label": "suspicious", "trust": -4.0, "color": Color("ff8c5a")},
	"furious": {"label": "furious", "trust": -7.0, "color": Color("ff5d73")},
}
## Boss escalation: suspicion at which each state begins, and how much more
## often he contacts you in it.
const ESCALATION := [
	{"name": "Unbothered", "at": 0.0, "frequency": 1.0},
	{"name": "Keeping an eye on you", "at": 40.0, "frequency": 1.2},
	{"name": "Micromanaging", "at": 62.0, "frequency": 1.4},
	{"name": "Building a case", "at": 82.0, "frequency": 1.6},
]

var state: Dictionary = {}       ## npc id -> {rel, irritation, mood, known:[claim ids], caught, last_contact, contacts}
var escalation := 0
var _boss := ""


func _ready() -> void:
	Game.time.minute_passed.connect(_on_minute)


func setup_run() -> void:
	Db.load_all()
	state = {}
	escalation = 0
	_boss = ""
	for id in Db.npcs:
		var d: Dictionary = Db.npcs[id]
		state[id] = {"rel": float(d.start_relationship), "irritation": 0.0, "mood": "neutral", "known": [], "caught": 0, "last_contact": -999, "contacts": 0, "snitched": 0}
		if bool(d.is_boss):
			_boss = id


func new_day() -> void:
	for id in state:
		state[id].contacts = 0
		state[id].irritation = float(state[id].irritation) * 0.5


func save_state() -> Dictionary:
	return {"state": state, "escalation": escalation}


func load_state(d: Dictionary) -> void:
	setup_run()
	var saved: Dictionary = d.get("state", {})
	for id in saved:
		if state.has(id):
			state[id] = saved[id]
	escalation = int(d.get("escalation", 0))


# --- Lookup ------------------------------------------------------------------

func boss_id() -> String:
	return _boss


func boss_name() -> String:
	return first_name(_boss)


func has(id: String) -> bool:
	return Db.npcs.has(id)


func def(id: String) -> Dictionary:
	return Db.npcs.get(id, {})


func display_name(id: String) -> String:
	if id == "me":
		return "You"
	return str(def(id).get("display_name", id))


func first_name(id: String) -> String:
	return display_name(id).get_slice(" ", 0)


func color(id: String) -> Color:
	if id == "me":
		return Color("5ad17a")
	return def(id).get("color", Color("c9c4e6"))


func role(id: String) -> String:
	return str(def(id).get("role", ""))


func kind(id: String) -> String:
	return str(def(id).get("kind", ""))


func voice(id: String) -> String:
	## Voice id used on calls ("" = the generic mumble).
	return str(def(id).get("voice", ""))


func record(id: String) -> Dictionary:
	return state.get(id, {})


# --- Relationship, mood, knowledge -------------------------------------------

func suspicion(id: String) -> float:
	## How suspicious this person is of you (0..100). For the manager this is
	## the Suspicion resource itself; for everyone else it follows from how
	## often they have caught you and how much they like you.
	if id == _boss:
		return Game.stats.get_value("susp")
	var r := record(id)
	return clampf(float(r.get("caught", 0)) * 18.0 + (50.0 - float(r.get("rel", 50.0))) * 0.6, 0.0, 100.0)


func relationship(id: String) -> float:
	return float(record(id).get("rel", 50.0))


func adjust(id: String, delta: float) -> void:
	if not state.has(id) or is_zero_approx(delta):
		return
	var r: Dictionary = state[id]
	r.rel = clampf(float(r.rel) + delta, 0.0, 100.0)
	relationship_changed.emit(id, float(r.rel))


func irritate(id: String, amount: float) -> void:
	if state.has(id):
		state[id].irritation = clampf(float(state[id].irritation) + amount, 0.0, 40.0)
		_refresh_mood(id)


func mood(id: String) -> String:
	return str(record(id).get("mood", "neutral"))


func mood_label(id: String) -> String:
	return str(MOOD_INFO[mood(id)].label)


func contacted(id: String) -> void:
	if state.has(id):
		state[id].last_contact = Game.time.now()
		state[id].contacts = int(state[id].contacts) + 1


func learn(id: String, claim_id: String) -> void:
	## This person has now heard one of your stories.
	if state.has(id) and not claim_id in state[id].known:
		state[id].known.append(claim_id)


func knows(id: String, claim_id: String) -> bool:
	return claim_id in record(id).get("known", [])


func caught_lying(id: String) -> void:
	if not state.has(id):
		return
	state[id].caught = int(state[id].caught) + 1
	adjust(id, -7.0)
	irritate(id, 9.0)


func trust(id: String) -> float:
	## Flat modifier (percentage points) on how readily this person believes you.
	if not state.has(id):
		return 0.0
	var r: Dictionary = state[id]
	var t := (float(r.rel) - 50.0) * 0.2
	t -= minf(float(r.caught), 3.0) * 4.0
	t += float(def(id).get("gullibility", 0.0))
	t += float(MOOD_INFO[str(r.mood)].trust)
	return t


func frequency() -> float:
	## How much more often than baseline the boss contacts you right now.
	var f := float(ESCALATION[escalation].frequency) * float(def(_boss).get("chattiness", 1.0))
	if mood(_boss) == "furious":
		f *= 1.15
	return f


func escalation_name() -> String:
	return str(ESCALATION[escalation].name)


func react(id: String, outcome_ok: bool, cls: int) -> void:
	## Called after the player answers this person.
	if not state.has(id):
		return
	if cls == WorkSystem.Cls.WORK:
		adjust(id, 3.0)
		irritate(id, -4.0)
	elif outcome_ok:
		adjust(id, 0.8)
		irritate(id, -1.5)
	else:
		adjust(id, -2.0)
		irritate(id, 4.0)


func ignored(id: String) -> void:
	adjust(id, -3.0)
	irritate(id, 6.0)


func _refresh_mood(id: String) -> void:
	var r: Dictionary = state[id]
	var score := float(r.irritation) * 2.0 - (float(r.rel) - 50.0) * 0.45
	if id == _boss:
		score += Game.stats.get_value("susp") * 0.62
	var m := "furious"
	if score < 16.0:
		m = "pleased"
	elif score < 36.0:
		m = "neutral"
	elif score < 54.0:
		m = "annoyed"
	elif score < 76.0:
		m = "suspicious"
	if m != str(r.mood):
		var order := MOOD_INFO.keys()
		var worse := order.find(m) > order.find(str(r.mood))
		var relieved := m == "pleased" and order.find(str(r.mood)) >= order.find("annoyed")
		r.mood = m
		mood_changed.emit(id, m)
		# He says so when things get worse, or when he has properly calmed down.
		if id == _boss and Game.time.in_work_hours() and (worse or relieved):
			_say_mood(id, m)


func _say_mood(id: String, m: String) -> void:
	var key := "mood_line_%d" % Game.time.day
	var last := int(Game.flags.get(key, -999))
	if Game.time.now() - last < 45:
		return
	var options: Array = def(id).get("mood_lines", {}).get(m, [])
	if options.is_empty():
		return
	Game.flags[key] = Game.time.now()
	Game.comms.say(id, str(Game.pick(options)))


func _on_minute() -> void:
	if not Game.time.running() or state.is_empty():
		return
	for id in state:
		var r: Dictionary = state[id]
		if float(r.irritation) > 0.0:
			r.irritation = maxf(0.0, float(r.irritation) - 0.06)
	if not Game.time.in_work_hours() or _boss == "":
		return
	_refresh_mood(_boss)
	# Escalation ratchets up with suspicion, and only relaxes one step once
	# suspicion has fallen well below the threshold.
	var susp := Game.stats.get_value("susp")
	var level := 1 if Game.flag("verify_mode") else 0     # from midweek he is never fully relaxed
	for i in ESCALATION.size():
		if susp >= float(ESCALATION[i].at):
			level = maxi(level, i)
	if level > escalation:
		escalation = level
		_on_escalated()
	elif level < escalation and susp < float(ESCALATION[escalation].at) - 18.0 and escalation > (1 if Game.flag("verify_mode") else 0):
		escalation -= 1
		escalated.emit(escalation)


func _on_escalated() -> void:
	escalated.emit(escalation)
	var lines: Array = def(_boss).get("escalation_lines", [])
	if escalation < lines.size() and str(lines[escalation]) != "":
		Game.comms.say(_boss, str(lines[escalation]))
	Bus.toast.emit("%s is now: %s. He will check on you more often." % [boss_name(), escalation_name()], "bad")
	Bus.sfx.emit("alarm")
	Game.events.on_escalation(escalation)
