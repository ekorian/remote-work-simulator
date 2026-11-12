class_name EventDirector
extends GameSystem
## EventDirector — decides what SynerCorp throws at you, and when.
##
## Events are data (resources/events/*.tres). Each one says how it can
## happen: fixed slots in the week, a filler pool the director draws from,
## or a reactive trigger with conditions on the simulation state. The
## director applies difficulty modifiers, cooldowns and pacing rules so the
## player is never hit by two things demanding attention at once.

signal event_fired(id: String)
signal event_deferred(id: String)

const MIN_GAP := 6               ## minutes between two director-initiated interruptions
const MAX_PENDING := 3           ## unanswered prompts before new ones are held back
const DEFER_MINUTES := 5
const MAX_DEFERS := 8
const CALL_CHANCE := [0.0, 45.0, 55.0, 65.0, 40.0]   ## surprise call, by day

var last_fired: Dictionary = {}  ## event id -> absolute minute it last fired
var count: Dictionary = {}       ## event id -> times fired this run
var deferred: Array = []         ## [{id, ctx, at, tries}] held back by pacing
var last_attention := -999       ## absolute minute of the last interruption


func _ready() -> void:
	Game.time.minute_passed.connect(_on_minute)
	Game.time.timer_fired.connect(_on_timer)


func setup_run() -> void:
	Db.load_all()
	last_fired = {}
	count = {}
	deferred = []
	last_attention = -999


func new_day() -> void:
	deferred = []


func save_state() -> Dictionary:
	return {"last_fired": last_fired, "count": count, "deferred": deferred, "last_attention": last_attention}


func load_state(d: Dictionary) -> void:
	last_fired = d.get("last_fired", {})
	count = d.get("count", {})
	deferred = d.get("deferred", [])
	last_attention = int(d.get("last_attention", -999))


# ---------------------------------------------------------------------------
# Planning the day
# ---------------------------------------------------------------------------

func plan_day() -> void:
	var day := Game.time.day
	if day > 4:
		return
	var d := Game.diff()
	var base := day * 1440
	var busy: Array = []         # [from, to] minutes that are already eventful
	# Fixed slots.
	for id in Db.events:
		var def: Dictionary = Db.events[id]
		if _skipped(def):
			continue
		for slot in def.get("schedule", []):
			if int(slot.day) != day:
				continue
			if slot.has("chance") and not Game.chance(float(slot.chance)):
				continue
			if slot.has("diffs") and not Game.difficulty_id in slot.diffs:
				continue
			var at: int = Game.rng.randi_range(int(slot.at[0]), int(slot.at[1])) if slot.at is Array else int(slot.at)
			if str(def.kind) == "meeting":
				var m := _meeting_def(def, at)
				if day == 0 and Game.tutor.on and str(m.script) == "standup":
					m.start = 600          # tutorial: give the new hire an hour first
					m.title = "%s (moved: %s overslept)" % [str(m.title), Game.npcs.boss_name()]
				Game.comms.add_meeting(m)
				busy.append([int(m.start) - 12, int(m.start) + int(m.dur) + 6])
			else:
				Game.time.schedule(base + at, "event", {"id": id})
				if str(def.kind) in ["chat", "call"] or str(def.action) == "audit":
					busy.append([at - 12, at + 12])
	# Filler: the boss checking in, colleagues wanting things.
	var freq := sqrt(Game.npcs.frequency())      # a suspicious boss checks in more, within reason
	for group in [["boss", (2.0 if day == 0 else 3.0) * float(d.boss_check) * freq], ["peer", (1.0 if day == 0 else 2.0) * float(d.event_rate)]]:
		var pool := _pool(str(group[0]))
		for i in int(round(float(group[1]))):
			var t := _free_slot(busy, 585, 1000, 9)
			if t < 0 or pool.is_empty():
				break
			var id: String = pool[Game.rng.randi() % pool.size()]
			pool.erase(id)
			Game.time.schedule(base + t, "event", {"id": id})
	# A surprise call.
	if Game.chance(minf(float(CALL_CHANCE[day]) * float(d.boss_check) * freq, 95.0)):
		var t := _free_slot(busy, 610, 960, 20)
		var calls := _pool("call")
		if t >= 0 and not calls.is_empty():
			Game.time.schedule(base + t, "event", {"id": str(calls[0])})
	# Channel chatter.
	var lines: Array = Db.lines("chatter").duplicate()
	for i in int(round(5.0 * float(d.event_rate))):
		if lines.is_empty():
			break
		var line: Array = lines[Game.rng.randi() % lines.size()]
		lines.erase(line)
		Game.time.schedule(base + Game.rng.randi_range(545, 1010), "chatter", {"line": line})


func _pool(pool: String) -> Array:
	var out: Array = []
	for id in Db.events:
		var def: Dictionary = Db.events[id]
		if str(def.pool) == pool and not _skipped(def) and check(def.conditions, {}, true):
			out.append(id)
	return out


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


func _meeting_def(def: Dictionary, at: int) -> Dictionary:
	var m: Dictionary = def.meeting.duplicate(true)
	m["id"] = str(def.id)
	m["title"] = Game.comms.fmt(str(def.title)).replace("Martin", Game.npcs.boss_name())
	m["start"] = at
	m["day"] = Game.time.day
	if not m.has("who"):
		m["who"] = str(def.from)
	return m


# ---------------------------------------------------------------------------
# Conditions
# ---------------------------------------------------------------------------

func _skipped(def: Dictionary) -> bool:
	return bool(def.get("difficulty", {}).get(Game.difficulty_id, {}).get("skip", false))


func check(cond: Dictionary, ctx: Dictionary = {}, planning: bool = false) -> bool:
	## Evaluate an event's preconditions. `planning` ignores time-of-day and
	## momentary state (used when the day is laid out in the morning).
	var day := Game.time.day
	if cond.has("day_min") and day < int(cond.day_min):
		return false
	if cond.has("day_max") and day > int(cond.day_max):
		return false
	if cond.has("flag") and not Game.flag(str(cond.flag)):
		return false
	if cond.has("not_flag") and Game.flag(str(cond.not_flag)):
		return false
	if cond.has("owns") and not Game.automation.owns(str(cond.owns)):
		return false
	if planning:
		return true
	var m := Game.time.minute
	if cond.has("from") and m < float(cond.from):
		return false
	if cond.has("to") and m > float(cond.to):
		return false
	if bool(cond.get("work_hours", true)) and not Game.time.in_work_hours():
		return false
	var susp := Game.stats.get_value("susp")
	if cond.has("susp_min") and susp < float(cond.susp_min):
		return false
	if cond.has("susp_max") and susp > float(cond.susp_max):
		return false
	var ill := Game.stats.get_value("ill")
	if cond.has("ill_min") and ill < float(cond.ill_min):
		return false
	if cond.has("ill_max") and ill > float(cond.ill_max):
		return false
	if cond.has("ability") and not Game.automation.can(str(cond.ability)):
		return false
	if cond.has("absent_min") and Game.presence.absent_run < int(cond.absent_min):
		return false
	if cond.has("status") and not Game.presence.status in cond.status:
		return false
	if cond.has("escalation_min") and Game.npcs.escalation < int(cond.escalation_min):
		return false
	if cond.has("claim") and Game.deception.live(str(cond.claim)) == null:
		return false
	if bool(cond.get("open_task", false)) and Game.work.most_urgent_task().is_empty():
		return false
	if bool(cond.get("urgent_task", false)):
		var t := Game.work.urgent_unfinished()
		if t.is_empty():
			return false
		ctx["task"] = str(t.id)
	if bool(cond.get("faked_task", false)) and not ctx.has("task"):
		var t := Game.work.faked_task()
		if t.is_empty():
			return false
		ctx["task"] = str(t.id)
	return true


func cooled_down(def: Dictionary) -> bool:
	var id := str(def.id)
	if not last_fired.has(id):
		return true
	if bool(def.once):
		return false
	var cd := int(def.cooldown)
	if cd <= 0:
		return int(int(last_fired[id]) / 1440.0) != Game.time.day      # once per day
	return Game.time.now() - int(last_fired[id]) >= cd


# ---------------------------------------------------------------------------
# Pacing
# ---------------------------------------------------------------------------

func is_interruption(def: Dictionary) -> bool:
	## Does this event demand the player's attention?
	match str(def.kind):
		"chat", "call":
			return true
		"mail":
			return not def.choices.is_empty()
	return false


func can_interrupt(def: Dictionary, ctx: Dictionary = {}) -> String:
	## "" if the event may fire now, otherwise the reason it must wait.
	if not is_interruption(def):
		return ""
	var comms := Game.comms
	if comms.in_call():
		return "in a call"
	if not comms.ringing().is_empty():
		return "a call is ringing"
	if comms.prompts.size() >= MAX_PENDING:
		return "too many unanswered messages"
	if str(def.kind) == "chat" and not comms.prompt_for_thread(_thread(def)).is_empty():
		return "that conversation is waiting on you"
	if str(def.kind) == "call":
		if int(Game.time.minute) > 985:
			return "too late in the day"
		for m in comms.meetings_today():
			if str(m.kind) != "block" and absi(int(m.start) - int(Game.time.minute)) < 15:
				return "a meeting is about to start"
	# Scripted beats and direct consequences are not rate-limited; filler is.
	if not bool(ctx.get("urgent", false)) and (str(def.pool) != "" or str(def.trigger) != ""):
		if Game.time.now() - last_attention < MIN_GAP:
			return "too soon after the last interruption"
	return ""


func _thread(def: Dictionary) -> String:
	return str(def.thread) if str(def.thread) != "" else Game.comms.dm_thread(str(def.from))


# ---------------------------------------------------------------------------
# Firing
# ---------------------------------------------------------------------------

func fire(id: String, ctx: Dictionary = {}) -> bool:
	## Fire an event now if its conditions and the pacing rules allow it.
	## Returns true if it happened; if pacing blocked it, it is retried later.
	if not Db.events.has(id):
		push_warning("EventDirector: unknown event '%s'" % id)
		return false
	if not Game.time.running() or Game.time.phase != "work":
		return false
	var def: Dictionary = Db.events[id]
	if _skipped(def):
		return false
	if bool(def.once) and last_fired.has(id):
		return false
	if not check(def.conditions, ctx):
		return false
	var blocked := can_interrupt(def, ctx)
	if blocked != "":
		_defer(id, ctx)
		return false
	_dispatch(def, ctx)
	for fact in def.get("facts", []):
		Game.deception.observe(str(fact))          # the event itself may expose a story
	if def.get("args", {}).has("mark_task"):
		var marked := Game.work.task(str(ctx.get("task", "")))
		if not marked.is_empty():
			marked[str(def.args.mark_task)] = true
	last_fired[id] = Game.time.now()
	count[id] = int(count.get(id, 0)) + 1
	if is_interruption(def):
		last_attention = Game.time.now()
	event_fired.emit(id)
	return true


func fire_later(minutes: int, id: String, ctx: Dictionary = {}) -> void:
	Game.time.schedule(Game.time.now() + minutes, "event", {"id": id, "ctx": ctx})


func _defer(id: String, ctx: Dictionary) -> void:
	var tries := int(ctx.get("_tries", 0)) + 1
	if tries > MAX_DEFERS:
		return
	var c := ctx.duplicate()
	c["_tries"] = tries
	deferred.append({"id": id, "ctx": c, "at": Game.time.now() + DEFER_MINUTES})
	event_deferred.emit(id)


func _subs(text: String, ctx: Dictionary) -> String:
	var out := text
	if out.contains("{task}"):
		var t := Game.work.task(str(ctx.get("task", "")))
		if t.is_empty():
			t = Game.work.most_urgent_task()
		out = out.replace("{task}", str(t.get("key", "that ticket")))
	if out.contains("{gadget}"):
		out = out.replace("{gadget}", str(Game.automation.def(str(ctx.get("gadget", ""))).get("display_name", "your gadget")))
	for key in ["subject", "title"]:
		if out.contains("{%s}" % key):
			out = out.replace("{%s}" % key, str(ctx.get(key, "")))
	return out


func _dispatch(def: Dictionary, ctx: Dictionary) -> void:
	var mods: Dictionary = def.get("difficulty", {}).get(Game.difficulty_id, {})
	match str(def.kind):
		"chat":
			Game.comms.add_prompt({
				"id": str(def.id), "from": str(def.from), "thread": _thread(def), "text": _subs(str(def.text), ctx),
				"choices": def.choices, "window": float(def.window) * float(mods.get("window", 1.0)), "routine": bool(def.routine),
				"expire": def.expire if not def.expire.is_empty() else {"susp": 7}, "no_excuse": bool(def.no_excuse),
				"claim": str(ctx.get("claim", "")), "task": str(ctx.get("task", "")), "gadget": str(ctx.get("gadget", "")),
			})
		"mail":
			Game.comms.add_mail(def)
		"meeting":
			Game.comms.add_meeting(_meeting_def(def, int(Game.time.minute)))
		"call":
			var m := _meeting_def(def, int(Game.time.minute))
			m["kind"] = "call"
			m["surprise"] = true
			Game.comms.add_meeting(m)
		"task":
			Game.work.add_task(str(def.task))
		"say":
			Game.comms.say(str(def.from), _subs(str(def.text), ctx))
		"system":
			call("_sys_" + str(def.action), def.get("args", {}), ctx)


func _on_timer(event: String, args: Dictionary) -> void:
	match event:
		"event":
			fire(str(args.id), args.get("ctx", {}).duplicate())
		"chatter":
			var line: Array = args.line
			Game.comms.post(str(line[0]), str(line[1]), str(line[2]))
		"bounce":
			_bounce(str(args.task))


func _on_minute() -> void:
	if not Game.time.running() or Game.time.phase != "work":
		return
	var now := Game.time.now()
	# Retry what pacing held back.
	if not deferred.is_empty():
		var ready: Array = []
		for e in deferred:
			if int(e.at) <= now:
				ready.append(e)
		for e in ready:
			deferred.erase(e)
		for e in ready:
			fire(str(e.id), e.ctx)
	if not Game.time.in_work_hours():
		return
	# Reactive events.
	for id in Db.events:
		var def: Dictionary = Db.events[id]
		if str(def.trigger) != "state" or not cooled_down(def):
			continue
		if check(def.conditions, {}) and can_interrupt(def) == "":
			fire(id)
			break                       # one reaction per minute is plenty


# ---------------------------------------------------------------------------
# Reactions and system actions
# ---------------------------------------------------------------------------

func on_escalation(level: int) -> void:
	## The boss just became more suspicious: he acts on it.
	match level:
		1:
			var calls := _pool("call")
			if not calls.is_empty():
				fire_later(Game.rng.randi_range(25, 50), str(calls[0]), {"urgent": true})
		2:
			fire_later(Game.rng.randi_range(4, 10), "micromanage", {"urgent": true})
		3:
			fire_later(Game.rng.randi_range(3, 8), "formal_warning", {"urgent": true})
			fire_later(Game.rng.randi_range(30, 50), "audit_surprise", {})


func _bounce(task_id: String) -> void:
	var t := Game.work.task(task_id)
	if t.is_empty():
		return
	Game.stats.add("susp", 8.0, "%s bounced" % str(t.key))
	Game.stats.add("ill", -4.0, "%s bounced" % str(t.key))
	Game.comms.say(Game.npcs.boss_id(), "The fix for %s imports a library called 'left-pad-pro-max' that does not exist. Did you even read it?" % str(t.key))


func on_call_join() -> void:
	## A call just started on camera: something may go wrong during it.
	var call := Game.comms.live_call
	if call.is_empty() or bool(call.get("phone", false)) or bool(Game.comms.call_meeting().get("no_dodge", false)):
		return
	for id in Db.events:
		var def: Dictionary = Db.events[id]
		if str(def.trigger) != "call_join" or _skipped(def) or not cooled_down(def) or not check(def.conditions, {}):
			continue
		var mods: Dictionary = def.get("difficulty", {}).get(Game.difficulty_id, {})
		if not Game.chance(float(def.args.get("chance", 100)) * float(mods.get("chance", 1.0))):
			continue
		var extra: Array = Db.dialogues.get(str(def.args.dialogue), {}).get("beats", []).duplicate(true)
		for i in extra.size():
			call.beats.insert(mini(1 + i, call.beats.size()), extra[i])
		last_fired[id] = Game.time.now()
		count[id] = int(count.get(id, 0)) + 1
		event_fired.emit(id)
		return


func _sys_inject(_args: Dictionary, _ctx: Dictionary) -> void:
	pass          # injected beats are handled by on_call_join()


func _sys_outcomes(args: Dictionary, ctx: Dictionary) -> void:
	## Something happened on your behalf: pick one of the authored outcomes.
	var o: Dictionary = Game.pick(args.outcomes)
	Bus.toast.emit(Game.comms.fmt(str(o.text)), "warn")
	Game.comms.say(Game.npcs.boss_id(), str(o.say))
	Game.comms.apply(o.get("fx", {}), "Your clone", ctx)


func _sys_flag(args: Dictionary, _ctx: Dictionary) -> void:
	Game.set_flag(str(args.id))


func _sys_incident(args: Dictionary, _ctx: Dictionary) -> void:
	Game.flags["incident_until"] = Game.time.now() + int(args.get("minutes", 60))


func _sys_it_update(args: Dictionary, _ctx: Dictionary) -> void:
	if Game.home.laptop_updating():
		return
	var mins := int(args.get("minutes", 35))
	Game.home.things.laptop_until = Game.time.now() + mins
	Game.comms.say("it", "Pushing a mandatory security update to your laptop. Do not turn it off. Estimated time: %d minutes (or forever)." % mins)
	Bus.toast.emit("IT is updating your laptop for real. %d minutes nobody can blame you for." % mins, "good")
	Game.presence.update()
	Bus.thing_changed.emit("laptop")


func _sys_isp_outage(args: Dictionary, _ctx: Dictionary) -> void:
	## The provider genuinely drops. An outage story told now is true.
	var mins := int(args.get("minutes", 25))
	Game.home.start_outage(mins)
	Game.flags["isp_until"] = Game.time.now() + mins + 40
	Bus.toast.emit("Your internet just died. For real. For once, the outage excuse is TRUE.", "good")
	Bus.sfx.emit("unplug")


func _sys_audit(args: Dictionary, _ctx: Dictionary) -> void:
	## SynerWatch scan: are you active, and does your machine look human?
	var warned := bool(args.get("warned", false))
	var st := Game.presence.status
	var heat := Game.automation.heat()
	if Game.presence.at_desk:
		heat *= 0.5
	if Game.automation.can("pass_scan"):
		heat *= 0.6
	Game.comms.post("it", "it", "SynerWatch scan running on your device%s..." % ("" if warned else " (unscheduled)"), "sys")
	if st in ["away", "offline"] and not Game.presence.covered():
		Game.stats.add("susp", 10.0, "SynerWatch: no activity detected")
		Game.stats.add("ill", -4.0, "SynerWatch: no activity detected")
		Game.comms.say("it", "Scan result: NO ACTIVITY DETECTED for an extended period. Your manager has been cc'd.")
		return
	if heat > 0.0 and Game.chance(heat * 0.9 * float(Game.diff().gadget_fail)):
		var hot := Game.automation.hottest()
		if hot != "":
			Game.automation.fail(hot, true)
		Game.stats.add("susp", 5.0, "SynerWatch: non-human input patterns")
		fire("audit_flagged", {"gadget": hot, "urgent": true})
		return
	if st == "online" or st == "busy":
		Game.stats.add("ill", 4.0, "SynerWatch: clean scan")
	Game.comms.say("it", "Scan result: clean. Activity score: %dth percentile." % Game.rng.randi_range(88, 99), false)
	Bus.toast.emit("SynerWatch scan passed. You look extremely employed.", "good")


func review_verdict() -> void:
	## The outcome of Friday's performance review, from how the week really went.
	if not Game.time.running():
		return
	var susp := Game.stats.get_value("susp")
	var ill := Game.stats.get_value("ill")
	var verdict := "meets"
	if susp < 35.0 and ill >= 60.0:
		verdict = "exceeds"
		Game.economy.add_money(150, "Review bonus")
		Game.stats.add("susp", -6.0, "Review: Exceeds Expectations")
		Game.comms.say("linda", "Review outcome: EXCEEDS EXPECTATIONS. A $150 spot bonus has been issued. Nobody is sure why.")
	elif susp < 68.0:
		Game.comms.say("linda", "Review outcome: MEETS EXPECTATIONS. The expectations were not written down.")
	else:
		verdict = "pip"
		Game.comms.say("linda", "Review outcome: PERFORMANCE IMPROVEMENT PLAN. Please sign the attached 14 pages.")
		Game.stats.add("susp", 12.0, "Review: Performance Improvement Plan")
	if Game.time.running():
		Game.flags["review"] = verdict
