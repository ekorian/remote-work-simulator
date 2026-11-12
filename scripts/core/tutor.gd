extends Node
## Tutor — the Monday-morning tutorial. It never pauses the game or takes
## control away: it is a checklist in the corner that advances when the
## player actually does the thing, plus one-off contextual hints later on.

const STEPS := [
	{"id": "move", "title": "Get out of bed", "text": "Walk with WASD or click the floor. Q / E rotate the camera, the mouse wheel zooms. Click any object (or press F next to it) to use it."},
	{"id": "desk", "title": "Clock in", "text": "Go to the Work Computer in the home office (top-left room) and press F to log in."},
	{"id": "reply", "title": "Answer Todd", "text": "Open SynerTeams and reply to your boss before his timer runs out. Green tags are safe. RED tags are real work and cost Health."},
	{"id": "fake", "title": "Fake some progress", "text": "Open SynerTasks, pick ticket SYN-101 and post a FAKE progress update. It feeds your Productivity Illusion without doing anything."},
	{"id": "leave", "title": "Walk away", "text": "Press Esc to leave the desk. Within minutes your status turns Away, and unexplained absence raises Suspicion."},
	{"id": "shop", "title": "Buy a Mouse Jiggler", "text": "Use the Gaming PC (the dark desk with the RGB strip) and buy the Mouse Jiggler from ShadyDeals.biz."},
	{"id": "enable", "title": "Switch it on", "text": "Use the Keyboard & Mouse on your work desk (or the ShadowIT app) to switch the jiggler ON. Your status stays green while you roam."},
	{"id": "relax", "title": "Now do nothing", "text": "You're covered. Go and enjoy it: sofa, TV, console, coffee, a snack. Leisure restores Health and Energy. Lying costs Energy."},
	{"id": "standup", "title": "Survive the standup", "text": "A meeting rings at 09:30. Join it from the computer or your phone (Tab), or find a way out of it. Meetings drain Health; missing them raises Suspicion."},
]

const HINTS := {
	"away": "Your status is Away. Suspicion climbs until you look busy, or have an accepted excuse.",
	"low_energy": "Low Energy: you can't lie convincingly when exhausted. Eat, drink coffee, or nap.",
	"low_health": "Low Health. Console, TV, the sofa and food restore it. Meetings and desk time drain it.",
	"phone": "Press Tab for your phone: answer chats and calls from anywhere, while it has battery.",
	"evening": "Work is over. Shop at the Gaming PC, recover, then sleep in the bed to start the next day.",
	"gadget_broke": "A gadget broke. Service your gadgets at the Keyboard & Mouse (it costs Energy).",
	"heat": "Running gadgets generate Heat. SynerWatch scans can catch you: switch things off before a scan.",
	"excuse": "Excuses wear out when reused, and some get checked. An outage excuse needs the router actually unplugged.",
	"favor": "Someone owes you a favour. Spend it in SynerTasks to hand a ticket to a colleague.",
	"fast": "Time fast-forwards during activities. Press F to stop early if something comes up.",
}

var _moved := 0.0


func _ready() -> void:
	Bus.desktop_opened.connect(func(): _done("desk"))
	Bus.desktop_closed.connect(func(): _done("leave"))
	Bus.prompt_resolved.connect(func(_p, o): if not bool(o.get("expired", false)): _done("reply"))
	Bus.action_performed.connect(_on_action)
	Bus.gadget_changed.connect(_on_gadget)
	Bus.activity_started.connect(_on_activity)
	Bus.meeting_changed.connect(_on_meeting)
	Game.minute_passed.connect(_on_minute)
	Game.presence_changed.connect(func(st): if st == "away" and Game.in_work_hours(): hint("away"))
	Game.phase_changed.connect(func(ph): if ph == "evening": hint("evening"))
	Game.favor_changed.connect(func(v): if v > 0: hint("favor"))


func active() -> bool:
	return Game.active and bool(Game.s.tut.on) and not bool(Game.s.tut.done)


func is_done(id: String) -> bool:
	return id in Game.s.tut.get("ticked", [])


func step() -> Dictionary:
	## The first step that has not been ticked off yet.
	if not active():
		return {}
	for st in STEPS:
		if not is_done(str(st.id)):
			return st
	return {}


func progress() -> Vector2i:
	return Vector2i(Game.s.tut.get("ticked", []).size(), STEPS.size())


func skip() -> void:
	if Game.active:
		Game.s.tut.done = true
		Bus.tutorial_changed.emit()


func walked(metres: float) -> void:
	if active() and not is_done("move"):
		_moved += metres
		if _moved > 2.5:
			_done("move")


func _done(id: String) -> void:
	if not active() or is_done(id):
		return
	if not Game.s.tut.has("ticked"):
		Game.s.tut["ticked"] = []
	Game.s.tut.ticked.append(id)
	Game.s.tut.step = Game.s.tut.ticked.size()
	if id == "desk":
		Game.s.hold = false          # the clock starts when you first log in
		_done("move")
	Bus.sfx.emit("good")
	if Game.s.tut.ticked.size() >= STEPS.size():
		Game.s.tut.done = true
		Bus.toast.emit("That's the whole job. Survive until Friday 17:00. Don't work. Don't get caught.", "tip")
	Bus.tutorial_changed.emit()


func _on_action(id: String, cls: int, _ctx: Dictionary) -> void:
	if Game.active and bool(Game.s.get("hold", false)):
		Game.s.hold = false          # the clock starts with your first action
		Bus.tutorial_changed.emit()
	if id == "fake_update":
		_done("fake")
	if cls == Actions.Cls.DECEIVE and id == "excuse":
		hint("excuse")


func _on_gadget(id: String) -> void:
	if not Game.active:
		return
	if Auto.owns("jiggler"):
		_done("shop")
	if Auto.working("jiggler"):
		_done("enable")
	if id != "" and Auto.owns(id) and bool(Auto.g(id).broken):
		hint("gadget_broke")
	if Auto.heat() >= 25.0:
		hint("heat")


func _on_activity(a: Dictionary) -> void:
	if a.has("stat"):
		_done("relax")
	hint("fast")


func _on_meeting(m: Dictionary) -> void:
	if str(m.kind) != "block" and str(m.state) in ["done", "excused", "declined", "looped", "missed"]:
		_done("standup")


func _on_minute() -> void:
	if not Game.active or Game.s.phase == "over":
		return
	if Game.get_stat("energy") < 22.0:
		hint("low_energy")
	if Game.get_stat("health") < 40.0:
		hint("low_health")
	if not Game.s.prompts.is_empty() and not bool(Game.s.pres.at_desk) and Interact.phone_usable():
		hint("phone")
	# Don't leave the player stuck on a step the day has moved past.
	if active() and int(Game.s.day) > 0:
		skip()


func hint(id: String) -> void:
	## One-off contextual tip, shown the first time a situation comes up.
	if not Game.active or not bool(Prefs.get_v("hints")) or not HINTS.has(id):
		return
	var key := "hint_" + id
	if Game.flag(key):
		return
	Game.set_flag(key)
	Bus.toast.emit(str(HINTS[id]), "tip")
