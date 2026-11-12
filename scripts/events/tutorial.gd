class_name Tutorial
extends GameSystem
## Tutorial — a checklist in the corner, one short list per day, that
## advances when the player actually does the thing. It never pauses the
## game or takes control away. Each day introduces what the week's
## progression calls for: Monday the controls and lying, Tuesday automation,
## Wednesday the ledger, Thursday failures and combinations, Friday the review.

const DAYS := [
	[
		{"id": "move", "title": "Get out of bed", "text": "Walk with WASD or click the floor. Q / E rotate the camera, the mouse wheel zooms. Click any object (or press F next to it) to use it."},
		{"id": "desk", "title": "Clock in", "text": "Go to the Work Computer in the home office (top-left room) and press F to log in."},
		{"id": "reply", "title": "Answer {boss}", "text": "Open SynerTeams and reply to your manager before his timer runs out. Green tags are safe. RED tags are real work and cost Health."},
		{"id": "fake", "title": "Fake some progress", "text": "Open SynerTasks, pick a ticket and post a FAKE progress update. It feeds your Productivity Illusion without doing anything."},
		{"id": "excuse", "title": "Tell your first lie", "text": "Pick 'Make an excuse...' on a message, or 'Excuse...' on a meeting in SynerCalendar. Every lie is remembered: don't do anything that contradicts it."},
		{"id": "leave", "title": "Walk away", "text": "Press Esc to leave the desk. Within minutes your status turns Away, and unexplained absence raises Suspicion."},
		{"id": "relax", "title": "Now do nothing", "text": "Sofa, TV, console, coffee, a snack. Leisure restores Health and Energy, and paid slacking is what your grade is made of."},
		{"id": "standup", "title": "Survive the standup", "text": "A meeting will ring. Join it from the computer or your phone (Tab), or find a way out of it. Meetings drain Health; missing them raises Suspicion."},
	],
	[
		{"id": "shop", "title": "Automate your presence", "text": "MouseMover.exe is on sale today. Use the Gaming PC (the dark desk with the RGB strip) and buy it from ShadyDeals.biz."},
		{"id": "enable", "title": "Switch it on", "text": "Use the Keyboard & Mouse on your work desk, or the ShadowIT app, to switch it ON. Your status stays green while you roam."},
		{"id": "roam", "title": "Slack while it covers", "text": "With MouseMover running, go and do something better. Gadgets wear out: service them before they fail."},
		{"id": "ally", "title": "Make an ally", "text": "Colleagues you leave hanging may tell {boss}. Ones who like you cover for you instead. Pick up when one calls, do one a favour, or open their chat in SynerTeams for small talk."},
	],
	[
		{"id": "ledger", "title": "Read your Alibi Ledger", "text": "{boss} is getting suspicious and now checks your stories. Open ShadowIT on the work computer: the ledger lists every claim and what would expose it."},
		{"id": "evidence", "title": "Lie with evidence", "text": "Back a story up before you tell it: unplug the router for an outage, block your calendar for a conflicting meeting, print a doctor's note. Evidence shows as a green tag."},
	],
	[
		{"id": "service", "title": "Service your gadgets", "text": "Worn gadgets fail, and every failure has consequences. Service them at the Keyboard & Mouse or in ShadowIT (costs Energy)."},
		{"id": "combo", "title": "Run a combination", "text": "Some gadgets work better together, at a higher risk. Run two that combine (ShadowIT shows which) and watch your Heat."},
	],
	[
		{"id": "review", "title": "Survive the review", "text": "15:30: the weekly performance review. It cannot be avoided, and it is built from everything you did this week."},
	],
]

const HINTS := {
	"away": "Your status is Away. Suspicion climbs until you look busy, or have an accepted excuse.",
	"low_energy": "Low Energy: you can't lie convincingly when exhausted. Eat, drink coffee, or nap.",
	"low_health": "Low Health. Console, TV, the sofa and food restore it. Meetings and desk time drain it.",
	"phone": "Press Tab for your phone: answer chats and calls from anywhere, while it has battery.",
	"evening": "Work is over. Shop at the Gaming PC, recover, then sleep in the bed to start the next day.",
	"gadget_broke": "A gadget broke. Service your gadgets at the Keyboard & Mouse (it costs Energy).",
	"heat": "Running gadgets generate Heat. SynerWatch scans can catch you: switch things off before a scan.",
	"claim": "Your story is now in the Alibi Ledger. While it is active, some actions would contradict it: the desktop warns you.",
	"contradiction": "You were caught contradicting yourself. Whoever heard the story will want an explanation: answer them.",
	"favor": "Someone owes you a favour. Spend it on a colleague in SynerTeams: a ticket taken off your hands, a meeting skipped, a good word.",
	"fast": "Time fast-forwards during activities. Press F to stop early if something comes up.",
	"upgrade": "Gadgets can be upgraded at the Gaming PC: more reliable, less Heat, new abilities.",
	"colleague": "Colleagues remember who answers. Leave one hanging and they may tell your manager; be good to them and they become friends who cover for you.",
	"snitch": "A colleague you ignored just told your manager. In SynerTeams, each colleague's page shows how likely they are to do that.",
	"friend": "You made a friend. Open their chat in SynerTeams: friends never tell on you, and you can ask them for favours.",
	"casual_call": "A colleague is calling. These calls cost no Health and count as time off: pick up to make friends. Rejecting is safer than letting it ring out.",
}

var on := false
var done := true
var ticked: Array = []           ## ids of the steps completed so far
var _moved := 0.0


func _ready() -> void:
	Bus.desktop_opened.connect(func(): tick("desk"))
	Bus.desktop_closed.connect(func(): tick("leave"))
	Bus.prompt_resolved.connect(func(_p, o): if not bool(o.get("expired", false)) and not bool(o.get("auto", false)): tick("reply"))
	Bus.action_performed.connect(_on_action)
	Bus.gadget_changed.connect(_on_gadget)
	Bus.prompt_added.connect(func(p): if Game.social.is_colleague(str(p.from)): hint("colleague"))
	Bus.activity_started.connect(_on_activity)
	Bus.meeting_changed.connect(_on_meeting)
	Game.time.minute_passed.connect(_on_minute)
	Game.day_started.connect(func(_d): Bus.tutorial_changed.emit())
	Game.presence.changed.connect(func(st): if st == "away" and Game.time.in_work_hours(): hint("away"))
	Game.time.phase_changed.connect(func(ph): if ph == "evening": hint("evening"))
	Game.economy.favors_changed.connect(func(v): if v > 0: hint("favor"))
	Game.deception.claim_added.connect(_on_claim)
	Game.deception.contradiction.connect(func(_c, _f): hint("contradiction"))


func setup_run() -> void:
	begin(false)


func begin(enabled: bool) -> void:
	on = enabled
	done = not enabled
	ticked = []
	_moved = 0.0


func save_state() -> Dictionary:
	return {"on": on, "done": done, "ticked": ticked}


func load_state(d: Dictionary) -> void:
	on = bool(d.get("on", false))
	done = bool(d.get("done", true))
	ticked = d.get("ticked", [])


# --- State -------------------------------------------------------------------

func steps_today() -> Array:
	return DAYS[clampi(Game.time.day, 0, DAYS.size() - 1)]


func step() -> Dictionary:
	## The first step of today's list that has not been ticked off yet.
	if not on or done or not Game.active:
		return {}
	for st in steps_today():
		if not str(st.id) in ticked:
			return st
	return {}


func active() -> bool:
	return not step().is_empty()


func is_done(id: String) -> bool:
	return id in ticked


func progress() -> Vector2i:
	var n := 0
	for st in steps_today():
		if str(st.id) in ticked:
			n += 1
	return Vector2i(n, steps_today().size())


func skip() -> void:
	if Game.active:
		done = true
		Game.time.hold = false
		Bus.tutorial_changed.emit()


func tick(id: String) -> void:
	## Mark a step complete. Steps of other days are ignored.
	if not on or done or not Game.active or id in ticked:
		return
	var today := false
	for st in steps_today():
		if str(st.id) == id:
			today = true
	if not today:
		return
	ticked.append(id)
	if id == "desk":
		Game.time.hold = false          # the clock starts when you first log in
		tick("move")
	Bus.sfx.emit("good")
	if Game.time.day == 0 and progress().x >= progress().y:
		Bus.toast.emit("That's the job. Survive until Friday 17:00. Don't work. Don't get caught.", "tip")
	Bus.tutorial_changed.emit()


func walked(metres: float) -> void:
	if on and not done and not is_done("move"):
		_moved += metres
		if _moved > 2.5:
			tick("move")


func opened_ledger() -> void:
	tick("ledger")


# --- Signals -----------------------------------------------------------------

func _on_action(id: String, _cls: int, _ctx: Dictionary) -> void:
	if Game.active and Game.time.hold:
		Game.time.hold = false          # the clock starts with your first action
		Bus.tutorial_changed.emit()
	match id:
		"fake_update":
			tick("fake")
		"excuse":
			tick("excuse")
		"maintain":
			tick("service")
		"small_talk", "gift", "ask_favor", "do_favor":
			tick("ally")


func _on_claim(c: Claim) -> void:
	if c.status == Claim.ACTIVE:
		hint("claim")
		if not c.evidence.is_empty():
			tick("evidence")


func _on_gadget(id: String) -> void:
	if not Game.active:
		return
	var auto := Game.automation
	for gid in auto.gadgets:
		if auto.owns(gid) and "presence" in auto.abilities(gid):
			tick("shop")
	if auto.can("presence"):
		tick("enable")
	if not auto.combos_active().is_empty():
		tick("combo")
	if id != "" and auto.owns(id):
		if bool(auto.g(id).broken):
			hint("gadget_broke")
		elif auto.can_upgrade(id):
			hint("upgrade")
	if auto.heat() >= 25.0:
		hint("heat")


func _on_activity(a: Dictionary) -> void:
	if a.has("stat"):
		tick("relax")
		if Game.automation.can("presence"):
			tick("roam")
	hint("fast")


func _on_meeting(m: Dictionary) -> void:
	if bool(m.get("casual", false)):
		if str(m.state) == "ringing" and Game.social.is_colleague(str(m.who)):
			hint("casual_call")
		elif str(m.state) == "done" and Game.social.is_colleague(str(m.who)):
			tick("ally")
		return                      # not a meeting: it does not count for the checklist
	if str(m.kind) == "block" or not str(m.state) in ["done", "excused", "declined", "looped", "missed"]:
		return
	tick("standup")
	if str(m.script) == "review":
		tick("review")


func _on_minute() -> void:
	if not Game.time.running():
		return
	if Game.stats.get_value("energy") < 22.0:
		hint("low_energy")
	if Game.stats.get_value("health") < 40.0:
		hint("low_health")
	if not Game.comms.prompts.is_empty() and not Game.presence.at_desk and Game.home.phone_usable():
		hint("phone")


func hint(id: String) -> void:
	## One-off contextual tip, shown the first time a situation comes up.
	if not Game.active or not bool(Prefs.get_v("hints")) or not HINTS.has(id):
		return
	var key := "hint_" + id
	if Game.flag(key):
		return
	Game.set_flag(key)
	Bus.toast.emit(str(HINTS[id]), "tip")
