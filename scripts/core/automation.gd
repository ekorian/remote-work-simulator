extends Node
## Auto — gadgets and automation.
##
## Gadgets are bought at the gaming PC and managed from the "ShadowIT" app on
## the work computer. Running ones wear out, can break at the worst moment and
## add to the detection "heat" that SynerWatch audits look at, so automation
## has to be planned rather than left on forever.

const GADGETS := {
	"jiggler": {
		"name": "Mouse Jiggler 3000", "price": 60, "day": 0, "heat": 8, "fail": 3.5, "net": false, "kind": "always",
		"blurb": "Keeps your status green while you are anywhere but your desk.",
		"broke": "The jiggler jammed. Your cursor has been drawing a perfect circle for an hour.",
	},
	"pecker": {
		"name": "Desk Bird Typist", "price": 95, "day": 0, "heat": 12, "fail": 4.5, "net": false, "kind": "always",
		"blurb": "A drinking bird that pecks the keyboard. Slowly raises Productivity Illusion.",
		"broke": "The bird fell over onto Enter and sent 'jjjjjjjj' to the whole company.",
	},
	"smartwatch": {
		"name": "Wrist Buzzer", "price": 70, "day": 0, "heat": 0, "fail": 0.0, "net": false, "kind": "passive",
		"blurb": "Buzzes for every message and call, wherever you are. Never miss a ping on the sofa.",
		"broke": "",
	},
	"buzzword": {
		"name": "Buzzword Generator Pro", "price": 110, "day": 1, "heat": 4, "fail": 0.0, "net": false, "kind": "passive",
		"blurb": "Fake updates, fake reports and jargon cost no energy.",
		"broke": "",
	},
	"replyguy": {
		"name": "ReplyGuy Auto-Responder", "price": 140, "day": 1, "heat": 16, "fail": 13.0, "net": true, "kind": "use",
		"blurb": "Answers routine pings for you with confident filler. Sometimes too confident.",
		"broke": "ReplyGuy answered Todd with: 'As a large language model, I cannot attend standup.'",
	},
	"reportomatic": {
		"name": "Report-o-Matic", "price": 130, "day": 1, "heat": 8, "fail": 9.0, "net": true, "kind": "use",
		"blurb": "Emails a fake status report every day at the time you choose.",
		"broke": "Report-o-Matic sent last year's report. With last year's date. To the CEO.",
	},
	"loopcam": {
		"name": "LoopCam Nodding Rig", "price": 180, "day": 2, "heat": 18, "fail": 15.0, "net": true, "kind": "use",
		"blurb": "Plays a webcam loop of you nodding. Attends meetings so you don't have to.",
		"broke": "The loop glitched. You nodded at the same angle 400 times, then froze mid-blink.",
	},
	"delegatron": {
		"name": "Delegatron AI Intern", "price": 220, "day": 2, "heat": 20, "fail": 6.0, "net": true, "kind": "always",
		"blurb": "Quietly does one assigned ticket in the background. Mostly correctly.",
		"broke": "Delegatron committed its own apology letter to the main branch.",
	},
	"fakescreen": {
		"name": "AltTab Pro Fake Screen", "price": 150, "day": 3, "heat": 6, "fail": 12.0, "net": false, "kind": "use",
		"blurb": "A looping screen of scrolling code and spreadsheets. Passes screen-share checks.",
		"broke": "The fake screen looped on a frame that said 'DEMO MODE - NOT REAL WORK'.",
	},
}

const ORDER := ["jiggler", "pecker", "smartwatch", "buzzword", "replyguy", "reportomatic", "loopcam", "delegatron", "fakescreen"]
const REPORT_TIMES := [-1, 600, 780, 990]   # off, 10:00, 13:00, 16:30


func _ready() -> void:
	Game.minute_passed.connect(_on_minute)


func setup_run() -> void:
	var g := {}
	for id in GADGETS:
		g[id] = {"owned": false, "on": false, "wear": 0.0, "broken": false, "runs": 0}
	Game.s.gadgets = g
	Game.s.autos = {"report_at": -1, "report_sent": false, "ai_task": "", "ai_left": 0, "loop_uses": 0}


func new_day() -> void:
	Game.s.autos.report_sent = false
	Game.s.autos.loop_uses = 0


# --- Queries -----------------------------------------------------------------

func g(id: String) -> Dictionary:
	return Game.s.get("gadgets", {}).get(id, {})


func owns(id: String) -> bool:
	return Game.active and bool(g(id).get("owned", false))


func is_on(id: String) -> bool:
	return owns(id) and bool(g(id).on)


func working(id: String) -> bool:
	if not owns(id):
		return false
	var st := g(id)
	var def: Dictionary = GADGETS[id]
	if bool(st.broken):
		return false
	if str(def.kind) != "passive" and not bool(st.on):
		return false
	if bool(def.net) and not Interact.internet_up():
		return false
	return true


func jiggler_running() -> bool:
	return working("jiggler")


func unlocked(id: String) -> bool:
	return int(Game.s.day) >= int(GADGETS[id].day)


func price(id: String) -> int:
	return int(round(float(GADGETS[id].price) * float(Game.diff().cost) / 5.0)) * 5


func heat() -> float:
	## How suspicious your machine looks to SynerWatch right now (0..100).
	var h := 0.0
	for id in GADGETS:
		if working(id):
			h += float(GADGETS[id].heat)
	if Game.now() < int(Game.s.pres.mug_until):
		h += 10.0
	return minf(100.0, h)


func fail_chance(id: String) -> float:
	## Percent chance the gadget fails on its next use (or next half-hour, for
	## always-on ones). Driven almost entirely by wear: service them and they behave.
	var st := g(id)
	var w := float(st.wear) / 40.0
	var factor := clampf(w * w, 0.04, 6.0) if str(GADGETS[id].kind) == "always" else 0.5 + w
	return clampf(float(GADGETS[id].fail) * factor * float(Game.diff().gadget_fail), 0.0, 90.0)


func any_broken() -> bool:
	for id in GADGETS:
		if owns(id) and bool(g(id).broken):
			return true
	return false


func max_wear() -> float:
	var w := 0.0
	for id in GADGETS:
		if owns(id):
			w = maxf(w, float(g(id).wear))
	return w


# --- Commands ---------------------------------------------------------------

func buy(id: String) -> bool:
	if owns(id):
		return false
	if not unlocked(id):
		Bus.toast.emit("Ships %s." % Cfg.DAYS[int(GADGETS[id].day)], "warn")
		return false
	var cost := price(id)
	if int(Game.s.money) < cost:
		Bus.toast.emit("You can't afford that. Payday is at 17:00.", "warn")
		return false
	Game.add_money(-cost, str(GADGETS[id].name))
	var st := g(id)
	st.owned = true
	st.on = str(GADGETS[id].kind) == "passive"
	Bus.sfx.emit("buy")
	Bus.toast.emit("Bought: %s. Switch it on in ShadowIT on your work computer." % str(GADGETS[id].name) if str(GADGETS[id].kind) != "passive" else "Bought: %s. Always on." % str(GADGETS[id].name), "money")
	Bus.gadget_changed.emit(id)
	return true


const BRIBE_PRICE := 45


func can_bribe() -> bool:
	return Game.active and not Game.flag("bribe_day_%d" % int(Game.s.day))


func bribe() -> bool:
	## A gift card "for the team". One favour per day, for cash.
	if not can_bribe():
		Bus.toast.emit("One suspiciously generous gift card per day is the limit.", "warn")
		return false
	var cost := int(round(float(BRIBE_PRICE) * float(Game.diff().cost) / 5.0)) * 5
	if int(Game.s.money) < cost:
		Bus.toast.emit("You can't afford that. Payday is at 17:00.", "warn")
		return false
	if not Actions.perform("flatter", {"label": "Gift card for a colleague"}):
		return false
	Game.set_flag("bribe_day_%d" % int(Game.s.day))
	Game.add_money(-cost, "Gift card")
	Game.add_favor(1)
	Bus.sfx.emit("buy")
	Bus.toast.emit("Dave got a gift card. Dave now owes you one.", "money")
	return true


func toggle(id: String) -> bool:
	if not owns(id) or str(GADGETS[id].kind) == "passive":
		return false
	var st := g(id)
	if bool(st.broken):
		Bus.toast.emit("It's broken. Service your gadgets first.", "warn")
		return false
	if not Actions.perform("toggle_gadget", {"gadget": id}):
		return false
	flip(id)
	return true


func flip(id: String) -> void:
	## Switch a gadget without going through Actions (the caller already did).
	var st := g(id)
	if not owns(id) or bool(st.broken):
		return
	st.on = not bool(st.on)
	Bus.sfx.emit("switch")
	Game._update_presence()
	Bus.gadget_changed.emit(id)


func maintain() -> bool:
	## Service every gadget: resets wear and repairs breakage.
	if not Actions.perform("maintain", {}):
		return false
	service()
	return true


func service() -> void:
	for id in GADGETS:
		if owns(id):
			var st := g(id)
			st.wear = 0.0
			st.broken = false
	Bus.toast.emit("Gadgets oiled, rebooted and threatened. Good as new.", "good")
	Bus.gadget_changed.emit("")


func set_report_time(minute: int) -> void:
	Game.s.autos.report_at = minute
	Bus.gadget_changed.emit("reportomatic")


func assign_ai(task_id: String) -> void:
	Game.s.autos.ai_task = task_id
	Game.s.autos.ai_left = 40
	Bus.gadget_changed.emit("delegatron")


func use(id: String) -> bool:
	## Fire a one-shot gadget. Returns true if it worked.
	if not working(id):
		return false
	var st := g(id)
	st.runs = int(st.runs) + 1
	Game.bump("auto_runs")
	var failed := Game.chance(fail_chance(id))
	st.wear = minf(100.0, float(st.wear) + 9.0)
	if failed:
		_break(id)
		return false
	Game.bump("auto_ok")
	Bus.gadget_changed.emit(id)
	return true


func _break(id: String) -> void:
	var st := g(id)
	st.broken = true
	st.on = false
	Game.add("susp", 6.0, "Gadget failure: %s" % str(GADGETS[id].name))
	Game.add("ill", -4.0, "Gadget failure")
	Bus.toast.emit(str(GADGETS[id].broke), "bad")
	Bus.sfx.emit("bad")
	Game.alert()
	Game._update_presence()
	Bus.gadget_changed.emit(id)


func _on_minute() -> void:
	if not Game.active or not Game.in_work_hours():
		return
	var t := Game.now()
	# Continuous gadgets: wear, upkeep rolls, effects.
	for id in ["jiggler", "pecker", "delegatron"]:
		if not working(id):
			continue
		var st := g(id)
		st.wear = minf(100.0, float(st.wear) + 0.2)
		if t % 30 == 0:
			Game.bump("auto_runs")
			if Game.chance(fail_chance(id)):
				_break(id)
				continue
			Game.bump("auto_ok")
	if working("pecker"):
		Game.add("ill", 0.085, "")
	# Report-o-Matic
	var a: Dictionary = Game.s.autos
	if int(a.report_at) > 0 and not bool(a.report_sent) and int(Game.s.t) >= int(a.report_at) and working("reportomatic"):
		a.report_sent = true
		if use("reportomatic"):
			Corp.fake_report(true)
	# Delegatron
	if str(a.ai_task) != "" and working("delegatron"):
		var task := Corp.task(str(a.ai_task))
		if task.is_empty() or str(task.status) != "open":
			a.ai_task = ""
		else:
			a.ai_left = int(a.ai_left) - 1
			if int(a.ai_left) <= 0:
				a.ai_left = 40
				Corp.task_progress(str(a.ai_task), 1, 0.06, "delegatron")
				if Corp.task(str(a.ai_task)).get("status", "") != "open" or Corp.task_real_done(str(a.ai_task)):
					Bus.toast.emit("Delegatron finished %s. You did nothing. Beautiful." % str(task.key), "good")
					a.ai_task = ""
				Bus.gadget_changed.emit("delegatron")
