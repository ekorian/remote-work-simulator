extends Node
## Director — decides what SynerCorp throws at you and when.
##
## Each morning it lays out the day: scripted beats from Content, plus filler
## pings, chatter, surprise calls and scans scaled by difficulty. It also
## reacts to how you are doing (long absences, rising suspicion).

const BOSS_PINGS := ["quick_q", "thoughts", "numbers", "task_status", "you_there", "article", "blockers", "weekend", "emoji"]
const PEER_PINGS := ["kevin_brag", "it_survey", "priya_branch", "linda_form", "dave_cover"]


func _ready() -> void:
	Game.minute_passed.connect(_on_minute)


func setup_run() -> void:
	Game.s.queue = []


func schedule(abs_minute: int, ev: String, args: Dictionary = {}) -> void:
	Game.s.queue.append({"at": abs_minute, "ev": ev, "args": args})


func plan_day() -> void:
	var day := int(Game.s.day)
	if day > 4:
		return
	var d := Game.diff()
	var base := day * 1440
	var busy: Array = []      # [start, end] minutes that are already eventful
	for m in Content.WEEK_MEETINGS[day]:
		var def: Dictionary = m.duplicate(true)
		def["day"] = day
		if day == 0 and bool(Game.s.tut.on) and str(def.script) == "standup":
			def["start"] = 600          # tutorial: give the new hire an hour first
			def["title"] = "Daily Standup (moved: Todd overslept)"
		Corp.add_meeting(def)
		busy.append([int(def.start) - 12, int(def.start) + int(def.dur) + 6])
	for e in Content.WEEK_EVENTS[day]:
		schedule(base + int(e[0]), str(e[1]), e[2])
		if str(e[1]) in ["ping", "audit", "demo_demand"]:
			busy.append([int(e[0]) - 14, int(e[0]) + 14])
	if day == 0 and bool(Game.s.tut.on):
		schedule(base + 541, "say", {"who": "priya", "text": Content.PRIYA_INTRO[0]})
		schedule(base + 547, "say", {"who": "priya", "text": Content.PRIYA_INTRO[1]})
	# Boss check-ins
	for group in [[BOSS_PINGS, (2.0 if day == 0 else 3.0) * float(d.boss_check)], [PEER_PINGS, (1.0 if day == 0 else 2.0) * float(d.event_rate)]]:
		var pool: Array = group[0].duplicate()
		for i in int(round(float(group[1]))):
			var t := _free_slot(busy, 585, 1000, 9)
			if t < 0 or pool.is_empty():
				break
			var id: String = pool[Game.rng.randi() % pool.size()]
			pool.erase(id)
			schedule(base + t, "ping", {"id": id})
	# Surprise call
	var call_p: float = [0.0, 45.0, 55.0, 65.0, 40.0][day] * float(d.boss_check)
	if Game.chance(minf(call_p, 95.0)):
		var t := _free_slot(busy, 610, 960, 20)
		if t >= 0:
			schedule(base + t, "call", {})
	# Unannounced scans
	if day == 3 or (day == 1 and str(Game.s.diff) in ["senior", "unemployed"]):
		var t := _free_slot(busy, 800, 950, 16)
		if t >= 0:
			schedule(base + t, "audit", {"warned": false})
	# IT pushes a genuine update now and then: a free, legitimate excuse.
	if day in [1, 3] and Game.chance(55.0):
		schedule(base + Game.rng.randi_range(780, 930), "it_update", {})
	# Channel chatter
	var lines: Array = Content.CHATTER.duplicate()
	for i in int(round(5.0 * float(d.event_rate))):
		if lines.is_empty():
			break
		var line: Array = lines[Game.rng.randi() % lines.size()]
		lines.erase(line)
		schedule(base + Game.rng.randi_range(545, 1010), "chatter", {"line": line})


func _free_slot(busy: Array, from: int, to: int, pad: int) -> int:
	## A random minute that does not collide with anything already planned.
	for attempt in 24:
		var t := Game.rng.randi_range(from, to)
		var clash := false
		for b in busy:
			if t >= int(b[0]) - pad and t <= int(b[1]) + pad:
				clash = true
				break
		if not clash:
			busy.append([t - pad, t + pad])
			return t
	return -1


func _on_minute() -> void:
	if not Game.active or Game.s.phase != "work":
		return
	var now := Game.now()
	var due: Array = []
	for e in Game.s.queue:
		if int(e.at) <= now:
			due.append(e)
	for e in due:
		Game.s.queue.erase(e)
	for e in due:
		if not Game.active or Game.s.phase == "over":
			return
		_fire(str(e.ev), e.args)
	if not Game.active or Game.s.phase == "over" or not Game.in_work_hours():
		return
	_react()


func _react() -> void:
	var p: Dictionary = Game.s.pres
	if int(p.absent_run) >= Cfg.UNCOVERED_ALERT and not bool(p.nagged):
		p.nagged = true
		_ping("why_away")
	var susp := Game.get_stat("susp")
	if susp >= 50.0 and not Game.flag("warn50"):
		Game.set_flag("warn50")
		Corp.say("todd", "{name}, I'm getting... vibes. Not great ones. Let's be more visible, yeah?")
		Bus.toast.emit("Suspicion past 50%. Todd is watching more closely.", "bad")
		schedule(Game.now() + Game.rng.randi_range(25, 55), "call", {})
	if susp >= 75.0 and not Game.flag("warn75"):
		Game.set_flag("warn75")
		Corp.say("linda", "Formal heads-up: your 'engagement metrics' have been escalated to People & Culture.")
		Bus.toast.emit("Suspicion past 75%. HR has opened a file on you.", "bad")
	var key := "lowill_%d" % int(Game.s.day)
	if Game.get_stat("ill") < 18.0 and not Game.flag(key) and int(Game.s.t) > 600:
		Game.set_flag(key)
		Corp.say("todd", "I haven't seen a single thing from you today. Not a commit, not an emoji. Nothing.")
		Bus.toast.emit("Productivity Illusion is critically low. Fake something!", "bad")


func _fire(ev: String, args: Dictionary) -> void:
	match ev:
		"ping":
			_ping(str(args.id))
		"task":
			Corp.add_task(str(args.id))
		"mail":
			Corp.add_mail(str(args.id))
		"say":
			Corp.say(str(args.who), str(args.text))
		"flag":
			Game.set_flag(str(args.id))
		"chatter":
			var line: Array = args.line
			Corp.post(str(line[0]), str(line[1]), str(line[2]))
		"audit":
			_audit(bool(args.get("warned", false)))
		"verify_excuse":
			Deception.verify(str(args.id))
		"demo_demand":
			_demo_demand(str(args.get("task", "")))
		"block_audit":
			_ping("block_audit", {"{title}": str(args.title)})
		"bounce":
			_bounce(str(args.task))
		"call":
			_surprise_call()
		"it_update":
			_it_update()
		_:
			push_warning("Director: unknown event '%s'" % ev)


func _ping(id: String, subs: Dictionary = {}) -> void:
	if not Content.PINGS.has(id):
		push_warning("Director: unknown ping '%s'" % id)
		return
	var def: Dictionary = Content.PINGS[id].duplicate(true)
	if str(def.text).contains("{task}"):
		var t := Corp.most_urgent_task()
		if t.is_empty():
			if id == "task_status":
				_ping("quick_q")
			return
		subs["{task}"] = str(t.key)
	for k in subs:
		def.text = str(def.text).replace(k, str(subs[k]))
	# Never stack two prompts in the same thread: defer instead.
	var thread: String = str(def.get("thread", Content.dm_thread(str(def.get("from", "todd")))))
	if not Corp.prompt_for_thread(thread).is_empty():
		schedule(Game.now() + 12, "ping", {"id": id})
		return
	def["id"] = id
	Corp.add_prompt(def)


func _demo_demand(task_id: String) -> void:
	var t := Corp.task(task_id)
	if t.is_empty() or str(t.status) != "open":
		t = {}
		for o in Corp.open_tasks():
			if float(o.fake) > 0.0 and str(o.by) == "":
				t = o
				break
	if t.is_empty():
		return
	t.demo_asked = true
	_ping("demo_demand", {"{task}": str(t.key)})


func _bounce(task_id: String) -> void:
	var t := Corp.task(task_id)
	if t.is_empty():
		return
	var who := Content.person_name(str(t.how))
	Game.add("susp", 8.0, "%s bounced" % str(t.key))
	Game.add("ill", -4.0, "%s bounced" % str(t.key))
	Corp.say("todd", "The fix for %s imports a library called 'left-pad-pro-max' that does not exist. Did you even read what %s wrote?" % [str(t.key), who])


func _surprise_call() -> void:
	if Corp.in_call() or not Corp.ringing().is_empty() or int(Game.s.t) > 985:
		return
	for m in Corp.meetings_today():
		if m.kind != "block" and absi(int(m.start) - int(Game.s.t)) < 15:
			return
	Corp.add_meeting({
		"title": "Todd is calling", "start": int(Game.s.t), "dur": 12, "kind": "call",
		"script": "sync", "surprise": true, "mandatory": false,
	})


func _it_update() -> void:
	if Interact.laptop_updating():
		return
	Game.s.things.laptop_until = Game.now() + 35
	Corp.say("it", "Pushing a mandatory security update to your laptop. Do not turn it off. Estimated time: 35 minutes (or forever).")
	Bus.toast.emit("IT is updating your laptop for real. 35 minutes nobody can blame you for.", "good")
	Game._update_presence()
	Bus.thing_changed.emit("laptop")


func _audit(warned: bool) -> void:
	## SynerWatch scan: are you active, and does your machine look human?
	var st: String = str(Game.s.pres.status)
	var heat := Auto.heat()
	if bool(Game.s.pres.at_desk):
		heat *= 0.5
	Corp.post("it", "it", "SynerWatch scan running on your device%s..." % ("" if warned else " (unscheduled)"), "sys")
	if st in ["away", "offline"] and not Game.covered():
		Game.add("susp", 10.0, "SynerWatch: no activity detected")
		Game.add("ill", -4.0, "SynerWatch: no activity detected")
		Corp.say("it", "Scan result: NO ACTIVITY DETECTED for an extended period. Your manager has been cc'd.")
		return
	if heat > 0.0 and Game.chance(heat * 0.9 * float(Game.diff().gadget_fail)):
		var hottest := ""
		var best := -1.0
		for id in Auto.GADGETS:
			if Auto.working(id) and float(Auto.GADGETS[id].heat) > best:
				best = float(Auto.GADGETS[id].heat)
				hottest = id
		Game.add("susp", 13.0, "SynerWatch: non-human input patterns")
		if hottest != "":
			var g := Auto.g(hottest)
			g.broken = true
			g.on = false
			Bus.gadget_changed.emit(hottest)
			Corp.say("it", "Scan result: 'non-human input patterns' detected. An unauthorised device (%s?) was remotely disabled." % str(Auto.GADGETS[hottest].name))
		else:
			Corp.say("it", "Scan result: your spacebar has been held down for 25 minutes. Are you OK?")
		Game._update_presence()
		return
	if st == "online" or st == "busy":
		Game.add("ill", 4.0, "SynerWatch: clean scan")
	Corp.say("it", "Scan result: clean. Activity score: %dth percentile." % Game.rng.randi_range(88, 99), false)
	Bus.toast.emit("SynerWatch scan passed. You look extremely employed.", "good")


func review_verdict() -> void:
	## The outcome of Friday's performance review, from how the week really went.
	if not Game.active or Game.s.phase == "over":
		return
	var susp := Game.get_stat("susp")
	var ill := Game.get_stat("ill")
	var verdict := "meets"
	if susp < 35.0 and ill >= 60.0:
		verdict = "exceeds"
		Game.add_money(150, "Review bonus")
		Game.add("susp", -6.0, "Review: Exceeds Expectations")
		Corp.say("linda", "Review outcome: EXCEEDS EXPECTATIONS. A $150 spot bonus has been issued. Nobody is sure why.")
	elif susp < 68.0:
		Corp.say("linda", "Review outcome: MEETS EXPECTATIONS. The expectations were not written down.")
	else:
		verdict = "pip"
		Corp.say("linda", "Review outcome: PERFORMANCE IMPROVEMENT PLAN. Please sign the attached 14 pages.")
		Game.add("susp", 12.0, "Review: Performance Improvement Plan")
	if Game.active and Game.s.phase != "over":
		Game.set_flag("review_" + verdict)
		Game.s.flags["review"] = verdict
