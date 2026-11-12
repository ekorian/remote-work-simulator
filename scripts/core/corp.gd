extends Node
## Corp — SynerCorp's side of the simulation: chat threads, prompts that need
## an answer, tickets, the calendar, calls and mail. Pure data + rules; the
## desktop apps and the phone are thin views over this API.

func _ready() -> void:
	Game.minute_passed.connect(_on_minute)
	Bus.activity_ended.connect(_on_activity_ended)


func setup_run() -> void:
	var th := {}
	for tid in Content.THREADS:
		th[tid] = {"msgs": [], "unread": 0}
	Game.s.threads = th
	Game.s.call = {}


# ---------------------------------------------------------------------------
# Threads and notifications
# ---------------------------------------------------------------------------

func fmt(text: String) -> String:
	return text.replace("{name}", Game.player_name())


func post(thread: String, who: String, text: String, kind: String = "") -> Dictionary:
	var th: Dictionary = Game.s.threads[thread]
	var m := {"who": who, "text": fmt(text), "day": int(Game.s.day), "t": int(Game.s.t), "kind": kind}
	th.msgs.append(m)
	if th.msgs.size() > 80:
		th.msgs.pop_front()
	if who != "me":
		th.unread = int(th.unread) + 1
	Bus.thread_message.emit(thread, m)
	Bus.comms_changed.emit()
	return m


func say(who: String, text: String, loud: bool = true) -> void:
	## An NPC speaks in their direct-message thread.
	post(Content.dm_thread(who), who, text)
	if loud:
		notify(Content.person_name(who), fmt(text), "info", false)


func can_react(thread: String) -> bool:
	if str(Content.THREADS[thread].kind) != "group":
		return false
	var msgs: Array = Game.s.threads[thread].msgs
	for i in range(msgs.size() - 1, -1, -1):
		var m: Dictionary = msgs[i]
		if str(m.who) != "me" and str(m.who) != "bot":
			return not bool(m.get("reacted", false))
	return false


func react(thread: String) -> bool:
	## Drop an emoji on the latest message in a group channel.
	if not can_react(thread):
		return false
	if not Actions.perform("react", {"label": "React in %s" % str(Content.THREADS[thread].name)}):
		return false
	var msgs: Array = Game.s.threads[thread].msgs
	for i in range(msgs.size() - 1, -1, -1):
		var m: Dictionary = msgs[i]
		if str(m.who) != "me" and str(m.who) != "bot":
			m["reacted"] = true
			break
	if Game.in_work_hours():
		Game.add("ill", 1.5, "Visible engagement")
	Game.touch()
	Bus.sfx.emit("pop")
	Bus.comms_changed.emit()
	return true


func mark_read(thread: String) -> void:
	Game.s.threads[thread].unread = 0
	Bus.comms_changed.emit()


func unread_total() -> int:
	var n := 0
	for tid in Game.s.threads:
		n += int(Game.s.threads[tid].unread)
	return n


func notify(title: String, text: String, kind: String = "info", urgent: bool = false) -> void:
	## Tell the player — if they are in a position to notice.
	if Game.can_notice():
		Bus.toast.emit("%s: %s" % [title, text], kind)
		Bus.sfx.emit("ring" if urgent else "ping")
		if urgent:
			Game.alert()
	else:
		Bus.sfx.emit("ping_far")


# ---------------------------------------------------------------------------
# Choices (shared by chat prompts, mail and calls)
# ---------------------------------------------------------------------------

func choice_view(c: Dictionary, context: String = "chat") -> Dictionary:
	## Everything the UI needs to draw one choice button.
	var act: String = str(c.get("a", "ack"))
	var v := {
		"text": fmt(str(c.t)), "badge": Actions.badge(act), "odds": -1.0,
		"ok": true, "why": "", "excuse": bool(c.get("excuse", false)), "cost": Actions.energy_cost(act),
	}
	var check := Actions.can(act)
	if not check.ok:
		v.ok = false
		v.why = check.why
	var req: Dictionary = c.get("req", {})
	if req.has("gadget") and not Auto.working(str(req.gadget)):
		v.ok = false
		v.why = "Needs a working %s" % str(Auto.GADGETS[str(req.gadget)].name)
	if req.has("favor") and int(Game.s.favor) < int(req.favor):
		v.ok = false
		v.why = "Needs %d favour(s)" % int(req.favor)
	if req.has("money") and int(Game.s.money) < int(req.money):
		v.ok = false
		v.why = "Needs $%d" % int(req.money)
	if req.has("loop") and not Interact.loop_ready():
		v.ok = false
		v.why = "Record a webcam loop at the company laptop first"
	if c.has("gadget"):
		v.odds = 100.0 - Auto.fail_chance(str(c.gadget))
	elif c.has("p"):
		var tags: Array = c.get("tags", []).duplicate()
		if context == "video" and not "video" in tags:
			tags.append("video")
		v.odds = Deception.chance(float(c.p), tags)
	return v


func resolve(c: Dictionary, context: String, what: String, excuse_id: String = "") -> Dictionary:
	## Execute one choice. Returns {done, ok, say, end}. `done` is false when the
	## choice could not be taken (or the run ended while taking it).
	var res := {"done": false, "ok": true, "say": "", "end": false}
	var view := choice_view(c, context)
	if not view.ok:
		Bus.toast.emit(str(view.why), "warn")
		return res
	var act: String = str(c.get("a", "ack"))
	var out: Dictionary = {}
	if bool(c.get("excuse", false)):
		if excuse_id == "" or not Deception.EXCUSES.has(excuse_id):
			return res
		if not Actions.perform("excuse", {"label": Deception.EXCUSES[excuse_id].label}):
			return res
		var att := Deception.attempt(excuse_id, context, what)
		res.ok = bool(att.ok)
		res.say = str(att.say)
		out = c.get("ok", {}) if res.ok else c.get("ko", {"susp": 7})
		if res.ok and not out.has("susp"):
			out = out.duplicate()
			out["susp"] = -1
	else:
		if not Actions.perform(act, {"label": fmt(str(c.t))}):
			return res
		if Actions.is_work(act) and not in_call():
			# Real work takes real (game) time, wherever it was agreed to.
			Game.start_activity({
				"id": "grind", "label": "Doing actual work", "mins": int(Actions.DEFS[act].get("mins", 30)),
				"speed": 6.0, "anim": "type", "thing": "", "per": {},
			})
		if c.has("req") and c.req.has("favor"):
			Game.add_favor(-int(c.req.favor))
		if c.has("req") and c.req.has("money"):
			Game.add_money(-int(c.req.money), "Favour")
		if c.has("gadget"):
			res.ok = Auto.use(str(c.gadget))
		elif c.has("p"):
			var tags: Array = c.get("tags", []).duplicate()
			if context == "video" and not "video" in tags:
				tags.append("video")
			res.ok = Deception.roll(float(c.p), tags)
		out = c.get("ok", {}) if res.ok else c.get("ko", c.get("ok", {}))
		res.say = str(out.get("say", ""))
	if not Game.active or Game.s.phase == "over":
		return res
	res.done = true
	res.end = bool(out.get("end", false))
	_apply(out, what)
	return res


func _apply(out: Dictionary, reason: String) -> void:
	Game.apply_fx(out, reason)
	if not Game.active or Game.s.phase == "over":
		return
	if out.has("task"):
		add_task(str(out.task))
	if out.has("progress"):
		var urgent := most_urgent_task()
		if not urgent.is_empty():
			task_progress(str(urgent.id), int(out.progress), 0.0, "me")
	if out.has("later"):
		var l: Dictionary = out.later
		Director.schedule(Game.now() + int(l.get("in", 30)), str(l.ev), l.get("args", {}))
	if out.has("give"):
		_hand_off(str(out.give))
	if out.has("stat"):
		Game.bump(str(out.stat))


func _hand_off(who: String) -> void:
	## Hand your most urgent open ticket to a colleague.
	var t := most_urgent_task()
	if t.is_empty():
		return
	t.by = who
	t.helper_left = int(t.effort) * 35
	Game.bump("tasks_delegated")
	Bus.toast.emit("%s is now quietly doing %s." % [Content.person_name(who), str(t.key)], "good")
	Bus.task_changed.emit(t)


# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------

func add_prompt(def: Dictionary) -> Dictionary:
	var window := int(round(float(def.get("window", 25)) * float(Game.diff().window) * Cfg.WINDOW_SCALE))
	var due := Game.now() + window
	var kind: String = str(def.get("kind", "chat"))
	# People leave you alone (for a bit) while they think you are legitimately out.
	if kind == "chat" and Game.covered() and bool(def.get("routine", false)):
		due = int(Game.s.cover.until) + window
	var p := {
		"id": Game.next_id("p"), "key": str(def.get("id", "")), "kind": kind,
		"thread": str(def.get("thread", Content.dm_thread(str(def.get("from", "todd"))))),
		"from": str(def.get("from", "todd")), "text": fmt(str(def.text)),
		"choices": def.choices.duplicate(true), "due": due, "born": Game.now(), "window": window,
		"routine": bool(def.get("routine", false)), "expire": def.get("expire", {"susp": 7}),
		"stalled": false, "mail": str(def.get("mail", "")), "auto_tried": false,
		"no_excuse": bool(def.get("no_excuse", kind != "chat")),
	}
	Game.s.prompts.append(p)
	if kind == "chat":
		post(p.thread, p.from, p.text, "prompt")
	if Game.can_notice():
		Bus.sfx.emit("ping")
		Game.alert()
	else:
		Bus.sfx.emit("ping_far")
	Bus.prompt_added.emit(p)
	Bus.comms_changed.emit()
	return p


func prompt(pid: String) -> Dictionary:
	for p in Game.s.prompts:
		if p.id == pid:
			return p
	return {}


func prompts(kind: String = "") -> Array:
	var out: Array = []
	for p in Game.s.prompts:
		if kind == "" or p.kind == kind:
			out.append(p)
	out.sort_custom(func(a, b): return int(a.due) < int(b.due))
	return out


func prompt_for_thread(thread: String) -> Dictionary:
	for p in Game.s.prompts:
		if p.kind == "chat" and p.thread == thread:
			return p
	return {}


func prompt_for_mail(mail_id: String) -> Dictionary:
	for p in Game.s.prompts:
		if p.mail == mail_id:
			return p
	return {}


func choices_of(p: Dictionary) -> Array:
	var out: Array = p.choices.duplicate()
	if not bool(p.no_excuse):
		out.append({"t": "Make an excuse...", "a": "excuse", "excuse": true})
	return out


func answer(pid: String, idx: int, excuse_id: String = "") -> Dictionary:
	var p := prompt(pid)
	if p.is_empty():
		return {"done": false}
	var list := choices_of(p)
	if idx < 0 or idx >= list.size():
		return {"done": false}
	var c: Dictionary = list[idx]
	var res := resolve(c, "chat", str(p.text), excuse_id)
	if not res.done:
		return res
	var line: String = fmt(str(c.t))
	if bool(c.get("excuse", false)):
		line = str(Deception.EXCUSES[excuse_id].label)
	if p.kind == "chat":
		post(p.thread, "me", line)
		if res.say != "":
			post(p.thread, p.from, res.say, "good" if res.ok else "bad")
	elif res.say != "":
		Bus.toast.emit("%s: %s" % [Content.person_name(p.from), fmt(res.say)], "good" if res.ok else "bad")
	Game.s.prompts.erase(p)
	Game.bump("prompts_answered")
	Game.touch()
	Bus.sfx.emit("good" if res.ok else "bad")
	Bus.prompt_resolved.emit(p, res)
	Bus.comms_changed.emit()
	return res


func stall(pid: String) -> bool:
	## "On it!" — buys time once per prompt.
	var p := prompt(pid)
	if p.is_empty() or bool(p.stalled):
		return false
	if not Actions.perform("stall", {"label": "Stall"}):
		return false
	p.stalled = true
	p.due = int(p.due) + int(round(15.0 * float(Game.diff().window)))
	if p.kind == "chat":
		post(p.thread, "me", Game.pick(["On it!", "Looking into it now.", "Give me two minutes.", "Yep, circling back shortly."]))
	Bus.comms_changed.emit()
	return true


func _expire(p: Dictionary) -> void:
	Game.s.prompts.erase(p)
	Game.bump("prompts_ignored")
	var ex: Dictionary = p.expire
	_apply(ex, "Ignored: %s" % Content.person_name(p.from))
	if p.kind == "chat":
		post(p.thread, p.from, str(ex.get("say", Game.pick(["Hello??", "...", "Guess you're busy. Noted.", "Read 14 minutes ago. Interesting."]))), "bad")
	Bus.sfx.emit("bad")
	Bus.prompt_resolved.emit(p, {"done": true, "ok": false, "say": "", "expired": true})
	Bus.comms_changed.emit()


# ---------------------------------------------------------------------------
# Tasks
# ---------------------------------------------------------------------------

func add_task(tid: String) -> Dictionary:
	var def: Dictionary = Content.TASKS[tid]
	var due_day := int(Game.s.day) + int(def.get("due_day", 0))
	var due := Game.abs_at(mini(due_day, 4), int(def.get("due_t", 1000)))
	if due <= Game.now() + 60:
		due = Game.now() + 120
	due = mini(due, Game.abs_at(4, 1010))
	var t := {
		"id": Game.next_id("t"), "tid": tid, "key": str(def.key), "title": str(def.title),
		"desc": str(def.get("desc", "")), "prio": int(def.get("prio", 2)), "effort": int(def.get("effort", 2)),
		"due": due, "status": "open", "real": 0, "fake": 0.0, "fake_n": 0, "by": "",
		"helper_left": 0, "clarified": false, "botched": false, "slipped": false,
		"demo_asked": false, "how": "", "born": Game.now(),
	}
	Game.s.tasks.append(t)
	post("team", "bot", "SynerTasks: %s \"%s\" was assigned to {name}. Due %s." % [t.key, t.title, due_text(due)], "sys")
	notify("SynerTasks", "New ticket %s: %s" % [t.key, t.title], "warn", false)
	Bus.task_changed.emit(t)
	Bus.comms_changed.emit()
	return t


func due_text(due: int) -> String:
	var d := int(due / 1440.0)
	var m := due % 1440
	if d == int(Game.s.day):
		return "today %s" % Cfg.fmt_time(m)
	return "%s %s" % [Cfg.DAYS_SHORT[clampi(d, 0, 4)], Cfg.fmt_time(m)]


func task(id: String) -> Dictionary:
	for t in Game.s.get("tasks", []):
		if t.id == id:
			return t
	return {}


func open_tasks() -> Array:
	var out: Array = []
	for t in Game.s.tasks:
		if t.status == "open":
			out.append(t)
	out.sort_custom(func(a, b): return int(a.due) < int(b.due))
	return out


func most_urgent_task() -> Dictionary:
	for t in open_tasks():
		if str(t.by) == "":
			return t
	return {}


func task_real_done(id: String) -> bool:
	var t := task(id)
	return not t.is_empty() and int(t.real) >= int(t.effort)


func task_looks_done(t: Dictionary) -> bool:
	return float(t.fake) >= 100.0


func task_work(id: String) -> bool:
	## Legitimate work on a ticket. Classified (and punished) by Actions.
	var t := task(id)
	if t.is_empty() or t.status != "open" or Game.busy():
		return false
	if not Actions.perform("work_task", {"label": "%s %s" % [t.key, t.title]}):
		return false
	Game.start_activity({
		"id": "work", "label": "Working on %s" % str(t.key), "mins": 45, "speed": 6.0,
		"anim": "type", "thing": "workstation", "task": id, "per": {},
	})
	return true


func task_fake(id: String) -> bool:
	var t := task(id)
	if t.is_empty() or t.status != "open":
		return false
	if task_looks_done(t):
		Bus.toast.emit("It already looks 100% done. More updates would be suspicious.", "warn")
		return false
	if not Actions.perform("fake_update", {"label": "Fake update on %s" % str(t.key)}):
		return false
	t.fake = minf(100.0, float(t.fake) + float(Game.rng.randi_range(22, 34)))
	t.fake_n = int(t.fake_n) + 1
	Game.add("ill", 3.5, "Fake update")
	post("team", "me", Content.fake_update_line(t), "auto")
	if not bool(t.demo_asked) and Game.chance(maxf(0.0, float(int(t.fake_n) - 2)) * 15.0 * float(Game.diff().boss_check)):
		t.demo_asked = true
		Director.schedule(Game.now() + Game.rng.randi_range(6, 18), "demo_demand", {"task": id})
	Game.touch()
	Bus.task_changed.emit(t)
	return true


func task_delegate(id: String) -> bool:
	var t := task(id)
	if t.is_empty() or t.status != "open" or str(t.by) != "":
		return false
	if int(Game.s.favor) < 1:
		Bus.toast.emit("Nobody owes you a favour. Cover for a colleague first.", "warn")
		return false
	if not Actions.perform("delegate_colleague", {"label": "Delegate %s" % str(t.key)}):
		return false
	Game.add_favor(-1)
	t.by = "dave"
	t.helper_left = int(t.effort) * 30
	Game.bump("tasks_delegated")
	say("dave", "Fine. I'll do %s. But we're even. And you never saw me at the driving range." % str(t.key), false)
	Bus.task_changed.emit(t)
	return true


func task_ai(id: String) -> bool:
	var t := task(id)
	if t.is_empty() or t.status != "open" or str(t.by) != "":
		return false
	if not Auto.working("delegatron"):
		Bus.toast.emit("Needs a working Delegatron AI Intern (switch it on in ShadowIT).", "warn")
		return false
	if str(Game.s.autos.ai_task) != "":
		Bus.toast.emit("Delegatron is already busy with another ticket.", "warn")
		return false
	if not Actions.perform("delegate_ai", {"label": "Delegate %s to AI" % str(t.key)}):
		return false
	t.by = "delegatron"
	Game.bump("tasks_delegated")
	Auto.assign_ai(id)
	Bus.task_changed.emit(t)
	return true


func task_clarify(id: String) -> bool:
	## Bureaucracy: "this is blocked pending requirements".
	var t := task(id)
	if t.is_empty() or t.status != "open" or bool(t.clarified):
		return false
	if not Actions.perform("clarify", {"label": "Clarify %s" % str(t.key)}):
		return false
	t.clarified = true
	if Deception.roll(72.0, ["jargon"]):
		t.due = mini(int(t.due) + 1440, Game.abs_at(4, 1010))
		Game.add("ill", 1.0, "Asked a 'clarifying question'")
		post("team", "me", "%s is blocked pending clarification of the acceptance criteria. Parking it." % str(t.key), "auto")
		Bus.toast.emit("%s pushed to %s. Requirements are a team sport." % [str(t.key), due_text(int(t.due))], "good")
	else:
		Game.add("susp", 5.0, "Transparent stalling")
		say("todd", "The acceptance criteria for %s are 'do it'. Do it." % str(t.key))
	Bus.task_changed.emit(t)
	return true


func task_change_request(id: String) -> bool:
	## Bureaucracy: bury the ticket in process. Once per day.
	var t := task(id)
	var key := "cr_day_%d" % int(Game.s.day)
	if t.is_empty() or t.status != "open":
		return false
	if Game.flag(key):
		Bus.toast.emit("The Change Advisory Board only accepts one Form 27-B per day.", "warn")
		return false
	if not Actions.perform("change_request", {"label": "Form 27-B for %s" % str(t.key)}):
		return false
	Game.set_flag(key)
	if Deception.roll(46.0 + 6.0 * float(3 - int(t.prio)), ["jargon"]):
		t.status = "cancelled"
		t.how = "descoped"
		Game.add("ill", 2.0, "Process champion")
		post("team", "bot", "SynerTasks: %s moved to 'Descoped - pending steering committee review (est. Q4)'." % str(t.key), "sys")
		Bus.toast.emit("%s is now the steering committee's problem. Forever." % str(t.key), "good")
	else:
		Game.add("susp", 7.0, "Frivolous Form 27-B")
		say("todd", "We are not convening a steering committee over %s." % str(t.key))
	Bus.task_changed.emit(t)
	return true


func task_progress(id: String, hours: int, botch: float, by: String) -> void:
	var t := task(id)
	if t.is_empty() or t.status != "open":
		return
	t.real = int(t.real) + hours
	if botch > 0.0 and Game.chance(botch * 100.0 * float(Game.diff().gadget_fail)):
		t.botched = true
	if by == "me":
		Game.add("ill", 3.0, "Real progress")
		Game.add("susp", -2.0, "Real progress")
	if int(t.real) >= int(t.effort):
		_complete(t, by)
	Bus.task_changed.emit(t)


func _complete(t: Dictionary, by: String) -> void:
	t.status = "done"
	t.how = by
	Game.bump("tasks_done")
	if bool(t.botched):
		Director.schedule(Game.now() + Game.rng.randi_range(20, 60), "bounce", {"task": str(t.id)})
	Game.add("ill", 9.0 if by == "me" else 7.0, "Ticket closed")
	if by == "me":
		Game.add("susp", -4.0, "Ticket closed")
	post("team", "bot", "SynerTasks: %s was closed by {name}." % str(t.key), "sys")
	Bus.task_changed.emit(t)


func _deadline(t: Dictionary) -> void:
	var key: String = str(t.key)
	if task_looks_done(t):
		if Deception.roll(64.0 - 6.0 * float(3 - int(t.prio)), ["jargon"]):
			t.status = "done"
			t.how = "faked"
			Game.bump("tasks_faked")
			Game.add("ill", 5.0, "Shipped an illusion")
			post("team", "bot", "SynerTasks: %s auto-closed (status: Looks Done)." % key, "sys")
			notify("SynerTasks", "%s closed. Nobody looked inside." % key, "good")
		else:
			t.status = "failed"
			Game.bump("tasks_failed")
			Game.add("susp", 11.0, "QA opened %s" % key)
			Game.add("ill", -8.0, "QA opened %s" % key)
			say("todd", "QA opened %s. It's a TODO comment and a photo of a duck. Explain." % key)
		Bus.task_changed.emit(t)
		return
	var frac := maxf(float(t.real) / float(t.effort), float(t.fake) / 100.0 * 0.7)
	if str(t.by) != "":
		frac = maxf(frac, 0.6)
	if frac >= 0.5 and not bool(t.slipped):
		t.slipped = true
		t.due = mini(int(t.due) + 1440, Game.abs_at(4, 1015))
		Game.add("susp", 5.0, "%s slipped" % key)
		Game.add("ill", -3.0, "%s slipped" % key)
		say("todd", "%s is late. I'm moving it to %s. Don't make me move it again." % [key, due_text(int(t.due))])
	else:
		t.status = "failed"
		Game.bump("tasks_failed")
		Game.add("susp", 8.0 + 3.0 * float(3 - int(t.prio)), "Missed deadline: %s" % key)
		Game.add("ill", -8.0, "Missed deadline")
		say("todd", "%s is overdue and untouched. I've reassigned it to Priya. We need to talk." % key)
	Bus.task_changed.emit(t)


func fake_report(auto: bool) -> bool:
	## The daily status report, generated rather than written.
	var key := "report_day_%d" % int(Game.s.day)
	if Game.flag(key):
		if not auto:
			Bus.toast.emit("You already sent a status report today. Two would look desperate.", "warn")
		return false
	if not auto and not Actions.perform("fake_report", {"label": "Fake status report"}):
		return false
	Game.set_flag(key)
	var text := Content.fake_report_text()
	add_mail_raw({"from": "me", "subject": "Daily Status: Strategic Momentum Update", "body": text, "sent": true})
	if auto or Deception.roll(74.0, ["jargon"]):
		Game.add("ill", 8.0 if auto else 9.0, "Status report")
		if not auto:
			say("todd", Game.pick(["Great report. Didn't read it, but great length.", "Love the bullet points. Very bullet-y.", "Forwarding this to leadership. Nice."]), false)
			Bus.toast.emit("Report sent. It contains zero information. Perfect.", "good")
	else:
		Game.add("ill", 2.0, "Status report")
		Game.add("susp", 5.0, "Todd actually read your report")
		say("todd", "I read your report twice. What is a 'holistic deliverable runway'?")
	return true


func real_report() -> bool:
	var key := "report_day_%d" % int(Game.s.day)
	if Game.flag(key):
		Bus.toast.emit("You already sent a status report today.", "warn")
		return false
	if not Actions.perform("write_report", {"label": "Real status report"}):
		return false
	Game.set_flag(key)
	Game.add("ill", 10.0, "Honest report")
	Game.add("susp", -5.0, "Honest report")
	add_mail_raw({"from": "me", "subject": "Daily Status (accurate)", "body": "A painfully honest account of the day. It took 45 minutes of your one life.", "sent": true})
	return true


# ---------------------------------------------------------------------------
# Calendar, meetings and calls
# ---------------------------------------------------------------------------

func add_meeting(def: Dictionary) -> Dictionary:
	var m := {
		"id": Game.next_id("m"), "key": str(def.get("id", "")), "title": str(def.title),
		"day": int(def.get("day", Game.s.day)), "start": int(def.start), "dur": int(def.get("dur", 30)),
		"kind": str(def.get("kind", "meeting")), "who": str(def.get("who", "todd")),
		"mandatory": bool(def.get("mandatory", false)), "video": bool(def.get("video", true)),
		"script": str(def.get("script", "")), "state": "upcoming", "ring_until": -1,
		"excuse_tried": false, "no_dodge": bool(def.get("no_dodge", false)),
		"surprise": bool(def.get("surprise", false)), "warned": false,
	}
	Game.s.meetings.append(m)
	Bus.meeting_changed.emit(m)
	return m


func meeting(id: String) -> Dictionary:
	for m in Game.s.get("meetings", []):
		if m.id == id:
			return m
	return {}


func meetings_today() -> Array:
	var out: Array = []
	for m in Game.s.meetings:
		if int(m.day) == int(Game.s.day):
			out.append(m)
	out.sort_custom(func(a, b): return int(a.start) < int(b.start))
	return out


func ringing() -> Dictionary:
	for m in Game.s.get("meetings", []):
		if m.state == "ringing":
			return m
	return {}


func next_meeting() -> Dictionary:
	for m in meetings_today():
		if m.state == "upcoming" and m.kind != "block":
			return m
	return {}


func calendar_block_now() -> bool:
	return not _block_at(int(Game.s.t)).is_empty()


func _block_at(minute: int) -> Dictionary:
	for m in Game.s.get("meetings", []):
		if m.kind == "block" and int(m.day) == int(Game.s.day) and minute >= int(m.start) and minute < int(m.start) + int(m.dur):
			return m
	return {}


func blocks_today() -> int:
	var n := 0
	for m in meetings_today():
		if m.kind == "block":
			n += 1
	return n


func conflicts(m: Dictionary) -> bool:
	for o in meetings_today():
		if o.kind == "block" and int(o.start) < int(m.start) + int(m.dur) and int(m.start) < int(o.start) + int(o.dur):
			return true
	return false


func add_block(start: int, dur: int = 30) -> bool:
	## A fake meeting on your own calendar. Shows you as "In a meeting".
	if blocks_today() >= 2:
		Bus.toast.emit("Policy 7.3: maximum two self-scheduled blocks per day.", "warn")
		return false
	if start + dur > Cfg.WORK_END or start < int(Game.s.t):
		Bus.toast.emit("That slot is in the past or after hours.", "warn")
		return false
	for o in meetings_today():
		if o.kind == "block" and int(o.start) < start + dur and start < int(o.start) + int(o.dur):
			Bus.toast.emit("You already blocked that slot.", "warn")
			return false
	if not Actions.perform("fake_block", {"label": "Fake calendar block"}):
		return false
	var title: String = Game.pick(Content.BLOCK_TITLES)
	add_meeting({"title": title, "start": start, "dur": dur, "kind": "block", "who": "me", "video": false})
	if Game.chance(22.0 * float(Game.diff().boss_check)):
		Director.schedule(Game.abs_at(int(Game.s.day), start + dur + 3), "block_audit", {"title": title})
	Bus.toast.emit("Blocked %s-%s: \"%s\"." % [Cfg.fmt_time(start), Cfg.fmt_time(start + dur), title], "good")
	Game.touch()
	return true


func can_dodge(m: Dictionary) -> bool:
	return (m.state == "upcoming" or m.state == "ringing") and not bool(m.no_dodge)


func decline_excuse(mid: String, excuse_id: String) -> Dictionary:
	var m := meeting(mid)
	if m.is_empty() or not can_dodge(m) or bool(m.excuse_tried):
		return {"done": false}
	if not Actions.perform("excuse", {"label": Deception.EXCUSES[excuse_id].label}):
		return {"done": false}
	m.excuse_tried = true
	var att := Deception.attempt(excuse_id, "chat", str(m.title))
	post("todd", "me", "Re: %s - %s" % [str(m.title), str(Deception.EXCUSES[excuse_id].label)])
	if bool(att.ok) and (not bool(m.mandatory) or Game.chance(70.0)):
		m.state = "excused"
		Game.bump("meetings_avoided")
		post("todd", str(m.who) if Content.PEOPLE.has(str(m.who)) else "todd", str(att.say), "good")
		Bus.toast.emit("You're excused from \"%s\"." % str(m.title), "good")
		Bus.sfx.emit("good")
	else:
		if bool(att.ok):
			att.say = "Sorry to hear that, but this one is mandatory. See you there."
			att.ok = false
		Game.add("susp", 5.0, "Excuse rejected")
		post("todd", "todd", str(att.say), "bad")
		Bus.toast.emit("Excuse rejected. You still have to deal with \"%s\"." % str(m.title), "bad")
		Bus.sfx.emit("bad")
	Bus.meeting_changed.emit(m)
	Bus.comms_changed.emit()
	return {"done": true, "ok": bool(att.ok), "say": str(att.say)}


func decline_conflict(mid: String) -> bool:
	## Bureaucracy: "sorry, I have a conflict" — only works if you really do.
	var m := meeting(mid)
	if m.is_empty() or not can_dodge(m):
		return false
	if not conflicts(m):
		Bus.toast.emit("You have no conflicting calendar block. Create one first.", "warn")
		return false
	if not Actions.perform("decline_conflict", {"label": "Decline %s" % str(m.title)}):
		return false
	if not bool(m.mandatory) or Game.chance(55.0):
		m.state = "declined"
		Game.bump("meetings_avoided")
		Bus.toast.emit("Declined \"%s\": calendar conflict. The system accepted it without a human involved." % str(m.title), "good")
	else:
		Game.add("susp", 4.0, "Tried to decline a mandatory meeting")
		say("todd", "Move your other thing. %s is mandatory." % str(m.title))
		m.no_dodge = true
	Bus.meeting_changed.emit(m)
	return true


func send_loop(mid: String) -> bool:
	var m := meeting(mid)
	if m.is_empty() or not can_dodge(m):
		return false
	if not Auto.working("loopcam"):
		Bus.toast.emit("Needs a working LoopCam (switch it on in ShadowIT).", "warn")
		return false
	if not Interact.loop_ready():
		Bus.toast.emit("Record today's webcam loop at the company laptop first.", "warn")
		return false
	if not Actions.perform("send_loop", {"label": "Send loop to %s" % str(m.title)}):
		return false
	Game.s.autos.loop_uses = int(Game.s.autos.loop_uses) + 1
	if Auto.use("loopcam"):
		if int(Game.s.autos.loop_uses) >= 3 and Game.chance(45.0):
			Game.add("susp", 9.0, "Same nod, third meeting")
			say("priya", "Weird question: why do you blink in exactly the same pattern in every meeting?")
		m.state = "looped"
		Game.bump("meetings_avoided")
		Game.add("ill", 3.0, "Attended (in spirit)")
		Bus.toast.emit("Your loop will attend \"%s\" for you. It nods beautifully." % str(m.title), "good")
	Bus.meeting_changed.emit(m)
	return true


func join(mid: String, via_phone: bool = false) -> bool:
	var m := meeting(mid)
	if m.is_empty() or m.state != "ringing":
		return false
	m.state = "live"
	var beats := Content.build_call(m)
	Game.s.call = {
		"mid": mid, "beats": beats, "i": 0, "phone": via_phone,
		"per": maxi(2, int(float(m.dur) / float(maxi(1, beats.size())))), "log": [],
	}
	Game.s.pres.in_call = true
	Game.stop_activity()
	Game.set_speed(1.0)
	Game._update_presence()
	Bus.meeting_changed.emit(m)
	return true


func in_call() -> bool:
	return Game.active and not Game.s.get("call", {}).is_empty()


func call_context() -> String:
	return "phone" if bool(Game.s.call.get("phone", false)) else "video"


func call_beat() -> Dictionary:
	if not in_call():
		return {}
	var c: Dictionary = Game.s.call
	if int(c.i) >= c.beats.size():
		return {}
	return c.beats[int(c.i)]


func call_choices() -> Array:
	var b := call_beat()
	if b.is_empty():
		return []
	var out: Array = b.choices.duplicate()
	var m := meeting(str(Game.s.call.mid))
	if not bool(m.get("no_dodge", false)) and not bool(b.get("no_excuse", false)):
		out.append({"t": "Bail out with an excuse...", "a": "excuse", "excuse": true, "ok": {"end": true}, "ko": {"susp": 8}})
	return out


func call_choose(idx: int, excuse_id: String = "") -> Dictionary:
	if not in_call():
		return {"done": false}
	var list := call_choices()
	if idx < 0 or idx >= list.size():
		return {"done": false}
	var c: Dictionary = list[idx]
	var m := meeting(str(Game.s.call.mid))
	var res := resolve(c, call_context(), str(m.get("title", "Call")), excuse_id)
	if not res.done:
		return res
	if bool(c.get("excuse", false)) and res.ok:
		res["bailed"] = true
	_call_step(res)
	return res


func call_timeout() -> Dictionary:
	## The player froze. Awkward silence.
	if not in_call():
		return {"done": false}
	var b := call_beat()
	var sil: Dictionary = b.get("silence", {"susp": 5, "say": "...{name}? You're on mute. Or frozen. Moving on."})
	_apply(sil, "Awkward silence")
	var res := {"done": true, "ok": false, "say": fmt(str(sil.get("say", ""))), "end": false}
	_call_step(res)
	return res


func _call_step(res: Dictionary) -> void:
	if not in_call():
		return
	var c: Dictionary = Game.s.call
	var per := int(c.per)
	c.i = int(c.i) + 1
	Game.bump("pretend_min", per)
	Game.add("health", -Cfg.BEAT_HP * float(Game.diff().stress), "Meeting fatigue")
	if not in_call():
		res.end = true
		return
	Game.advance(per)
	if not in_call():
		res.end = true
		return
	if bool(res.get("end", false)) or int(c.i) >= c.beats.size():
		res.end = true
		call_end(bool(res.get("bailed", false)))


func call_end(bailed: bool = false) -> void:
	if not in_call():
		return
	var m := meeting(str(Game.s.call.mid))
	Game.s.call = {}
	Game.s.pres.in_call = false
	if not m.is_empty():
		if bailed:
			m.state = "excused"
			Game.bump("meetings_avoided")
		else:
			m.state = "done"
			Game.bump("meetings_attended")
			var after: Dictionary = Content.CALLS.get(str(m.script), {}).get("after", {})
			if not after.is_empty():
				_apply(after, str(m.title))
			if str(m.script) == "review":
				Director.review_verdict()
		Bus.meeting_changed.emit(m)
	Game.touch()
	Game._update_presence()


func call_hang_up() -> void:
	## Leaving mid-meeting without an excuse.
	if not in_call():
		return
	var m := meeting(str(Game.s.call.mid))
	Game.add("susp", 9.0 if bool(m.get("mandatory", false)) else 6.0, "Dropped off a call")
	say("todd", "Did you just... leave?", false)
	call_end(false)


func reject_call(mid: String) -> void:
	## Decline an incoming surprise call outright.
	var m := meeting(mid)
	if m.is_empty() or m.state != "ringing":
		return
	_miss(m, true)


func _miss(m: Dictionary, rejected: bool = false) -> void:
	if Game.covered() and not bool(m.no_dodge):
		m.state = "excused"
		Game.bump("meetings_avoided")
		Bus.meeting_changed.emit(m)
		return
	m.state = "missed"
	Game.bump("meetings_missed")
	var pen := 13.0 if bool(m.mandatory) else 8.0
	if bool(m.no_dodge):
		pen = 30.0
	if rejected:
		pen = 6.0
	Game.add("susp", pen, "Missed: %s" % str(m.title))
	Game.add("ill", -4.0, "Missed: %s" % str(m.title))
	say("todd", Game.pick(Content.MISSED_LINES).replace("{m}", str(m.title)))
	Bus.meeting_changed.emit(m)


# ---------------------------------------------------------------------------
# Mail
# ---------------------------------------------------------------------------

func add_mail(mid: String) -> Dictionary:
	var def: Dictionary = Content.MAILS[mid]
	var m := add_mail_raw({"from": str(def.from), "subject": str(def.subject), "body": str(def.body), "key": mid})
	if def.has("choices"):
		var pd := {
			"id": mid, "kind": "mail", "from": str(def.from), "text": str(def.subject), "choices": def.choices,
			"window": int(def.get("window", 90)), "expire": def.get("expire", {"susp": 4}), "mail": str(m.id),
		}
		add_prompt(pd)
	else:
		notify("SynerMail", str(def.subject), "info", false)
	return m


func add_mail_raw(def: Dictionary) -> Dictionary:
	var m := {
		"id": Game.next_id("e"), "key": str(def.get("key", "")), "from": str(def.from),
		"subject": fmt(str(def.subject)), "body": fmt(str(def.body)), "day": int(Game.s.day),
		"t": int(Game.s.t), "read": bool(def.get("sent", false)), "sent": bool(def.get("sent", false)),
	}
	Game.s.mails.append(m)
	if Game.s.mails.size() > 60:
		Game.s.mails.pop_front()
	Bus.mail_added.emit(m)
	Bus.comms_changed.emit()
	return m


func unread_mail() -> int:
	var n := 0
	for m in Game.s.mails:
		if not bool(m.read):
			n += 1
	return n


# ---------------------------------------------------------------------------
# Presence helpers and the minute tick
# ---------------------------------------------------------------------------

func set_focus() -> bool:
	## Flip your status to "Focusing". Costs credibility if abused.
	var p: Dictionary = Game.s.pres
	if Game.now() < int(p.focus_until):
		return false
	if not Actions.perform("set_focus", {"label": "Set status to Focusing"}):
		return false
	p.focus_used = int(p.focus_used) + 1
	p.focus_until = Game.now() + 40
	if int(p.focus_used) >= 3:
		Game.add("susp", 5.0, "Always 'Focusing'")
		say("todd", "You've been 'Focusing' three times today. On what?")
	else:
		Bus.toast.emit("Status: Focusing (40 min). Nobody expects a reply.", "good")
	Game._update_presence()
	return true


func close_day() -> void:
	## 17:00 — wrap up anything still hanging.
	if in_call():
		call_end(false)
	for p in Game.s.prompts.duplicate():
		Game.s.prompts.erase(p)
		Game.bump("prompts_ignored")
		Game.add("susp", 3.0, "Left on read overnight")
	for m in Game.s.meetings:
		if m.state == "ringing":
			_miss(m)
		elif m.state == "upcoming" and int(m.day) == int(Game.s.day):
			m.state = "done"
	Bus.comms_changed.emit()


func _on_minute() -> void:
	if not Game.active or Game.s.phase != "work":
		return
	var now := Game.now()
	var t := int(Game.s.t)
	# Prompts
	for p in Game.s.prompts.duplicate():
		if now >= int(p.due):
			_expire(p)
		elif bool(p.routine) and not bool(p.auto_tried) and now - int(p.born) >= int(int(p.window) / 2.0) and Auto.working("replyguy"):
			p.auto_tried = true
			if Auto.use("replyguy"):
				post(p.thread, "me", Game.pick(Content.AUTO_REPLIES), "auto")
				Game.s.prompts.erase(p)
				Game.add("ill", 2.0, "ReplyGuy")
				Game.bump("prompts_answered")
				Bus.toast.emit("ReplyGuy handled a ping from %s." % Content.person_name(p.from), "good")
				Bus.prompt_resolved.emit(p, {"done": true, "ok": true, "say": "", "auto": true})
				Bus.comms_changed.emit()
	if not Game.active or Game.s.phase == "over":
		return
	# Tasks
	for tk in Game.s.tasks:
		if tk.status != "open":
			continue
		if int(tk.helper_left) > 0 and Game.in_work_hours():
			tk.helper_left = int(tk.helper_left) - 1
			if int(tk.helper_left) <= 0:
				var who: String = str(tk.by)
				task_progress(str(tk.id), int(tk.effort), 0.18 if who == "kevin" else 0.04, who)
				if tk.status == "done":
					notify("SynerTasks", "%s finished %s for you." % [Content.person_name(who), str(tk.key)], "good")
				continue
		if now >= int(tk.due):
			_deadline(tk)
	if not Game.active or Game.s.phase == "over":
		return
	# Meetings
	for m in Game.s.meetings:
		if int(m.day) != int(Game.s.day):
			continue
		var start := int(m.start)
		match str(m.state):
			"upcoming":
				if m.kind == "block":
					if t >= start:
						m.state = "live"
						Game._update_presence()
						Bus.meeting_changed.emit(m)
				elif t >= start:
					m.state = "ringing"
					m.ring_until = start + maxi(4, int(round((5.0 if bool(m.surprise) else 8.0) * float(Game.diff().window))))
					if Game.can_notice():
						Bus.sfx.emit("ring")
						Game.alert()
					else:
						Bus.sfx.emit("ping_far")
					Bus.meeting_changed.emit(m)
				elif not bool(m.warned) and t >= start - 10:
					m.warned = true
					notify("SynerCalendar", "\"%s\" starts in %d min." % [str(m.title), start - t], "info", false)
			"ringing":
				if t > int(m.ring_until):
					_miss(m)
			"live":
				if m.kind == "block" and t >= start + int(m.dur):
					m.state = "done"
					Game._update_presence()
					Bus.meeting_changed.emit(m)
			"looped":
				if t >= start + int(m.dur):
					m.state = "done"
					Bus.meeting_changed.emit(m)


func _on_activity_ended(a: Dictionary, completed: bool) -> void:
	if str(a.get("id", "")) != "work" or not Game.active:
		return
	if completed:
		task_progress(str(a.task), 1, 0.0, "me")
	else:
		Bus.toast.emit("You stopped working. The damage is already done.", "warn")
