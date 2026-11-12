class_name WorkSystem
extends GameSystem
## WorkSystem — the single place that decides what counts as WORK, plus
## everything about tickets: assignment, deadlines and the ways around them.
##
## Every player-initiated action is declared in DEFS with a class. Gameplay
## code never applies a work penalty itself: it calls `perform(id, ctx)` and
## carries on only if that returns true. The health penalty, the
## Professional Unemployed instant loss, energy costs and the worked-minutes
## log all live here and nowhere else.

enum Cls {
	WORK,      ## legitimate work: costs health, lethal on Professional Unemployed
	STRESS,    ## accepting corporate responsibility: costs health, never lethal
	FAKE,      ## simulating work: allowed, feeds the productivity illusion
	DELEGATE,  ## making it someone else's problem
	AUTOMATE,  ## making it a gadget's problem
	DECEIVE,   ## excuses, bluffs and lies
	BUREAU,    ## weaponised process
	SOCIAL,    ## colleagues and favours
	LEISURE,   ## the reason you took this job
	UPKEEP,    ## gadget and equipment maintenance
	NEUTRAL,   ## honest, harmless or purely logistical
}

const CLS_INFO := {
	Cls.WORK: {"tag": "REAL WORK", "color": Color("ff5d73")},
	Cls.STRESS: {"tag": "RESPONSIBILITY", "color": Color("ff8c5a")},
	Cls.FAKE: {"tag": "FAKE WORK", "color": Color("5ad17a")},
	Cls.DELEGATE: {"tag": "DELEGATE", "color": Color("4fb3ff")},
	Cls.AUTOMATE: {"tag": "AUTOMATION", "color": Color("5ad1c8")},
	Cls.DECEIVE: {"tag": "DECEPTION", "color": Color("b48cff")},
	Cls.BUREAU: {"tag": "BUREAUCRACY", "color": Color("ffd166")},
	Cls.SOCIAL: {"tag": "SOCIAL", "color": Color("ff9ecb")},
	Cls.LEISURE: {"tag": "LEISURE", "color": Color("5ad1c8")},
	Cls.UPKEEP: {"tag": "UPKEEP", "color": Color("c9c4e6")},
	Cls.NEUTRAL: {"tag": "", "color": Color("c9c4e6")},
}

## id -> {cls, label, en (energy delta), mins (work minutes logged, WORK only)}
const DEFS := {
	# --- Legitimate work (forbidden fruit) ---------------------------------
	"work_task": {"cls": Cls.WORK, "label": "Do the actual work", "en": -6, "mins": 45},
	"write_report": {"cls": Cls.WORK, "label": "Write a real report", "en": -6, "mins": 45},
	"fix_bug": {"cls": Cls.WORK, "label": "Fix the actual bug", "en": -6, "mins": 45},
	"real_answer": {"cls": Cls.WORK, "label": "Give a genuinely useful answer", "en": -4, "mins": 15},
	"help_colleague": {"cls": Cls.WORK, "label": "Actually help a colleague", "en": -5, "mins": 30},
	"do_training": {"cls": Cls.WORK, "label": "Complete the training properly", "en": -5, "mins": 40},
	"real_timesheet": {"cls": Cls.WORK, "label": "Reconstruct an accurate timesheet", "en": -5, "mins": 30},
	"live_demo": {"cls": Cls.WORK, "label": "Do the work live on a call", "en": -8, "mins": 30},
	# --- Stressful responsibilities ---------------------------------------
	"accept_duty": {"cls": Cls.STRESS, "label": "Accept the responsibility", "en": -3},
	"volunteer": {"cls": Cls.STRESS, "label": "Volunteer", "en": -3},
	# --- Simulated work ----------------------------------------------------
	"fake_update": {"cls": Cls.FAKE, "label": "Post a fake progress update", "en": -4},
	"fake_report": {"cls": Cls.FAKE, "label": "Generate a fake corporate report", "en": -5},
	"pretend_investigate": {"cls": Cls.FAKE, "label": "Pretend to investigate", "en": -4},
	"fake_timesheet": {"cls": Cls.FAKE, "label": "Submit a creative timesheet", "en": -4},
	"bg_training": {"cls": Cls.FAKE, "label": "Let the training play on mute", "en": -1},
	"react": {"cls": Cls.FAKE, "label": "React with an emoji", "en": -1},
	"jargon": {"cls": Cls.FAKE, "label": "Answer in pure jargon", "en": -3},
	"reply_all": {"cls": Cls.FAKE, "label": "Reply-all to look engaged", "en": -2},
	"stage_desk": {"cls": Cls.FAKE, "label": "Stage a busy-looking desk", "en": -4},
	"wedge_mug": {"cls": Cls.FAKE, "label": "Wedge the mug on the spacebar", "en": -1},
	"set_focus": {"cls": Cls.FAKE, "label": "Set status to Focusing", "en": -1},
	"fake_block": {"cls": Cls.FAKE, "label": "Block the calendar with a fake meeting", "en": -2},
	"forge_note": {"cls": Cls.FAKE, "label": "Print a forged document", "en": -3},
	"report_phish": {"cls": Cls.FAKE, "label": "Report it and look vigilant", "en": -1},
	# --- Delegation --------------------------------------------------------
	"delegate_colleague": {"cls": Cls.DELEGATE, "label": "Call in a favour", "en": -3},
	"forward": {"cls": Cls.DELEGATE, "label": "Forward it to someone else", "en": -2},
	# --- Automation --------------------------------------------------------
	"delegate_ai": {"cls": Cls.AUTOMATE, "label": "Delegate to your AI clone", "en": -2},
	"send_clone": {"cls": Cls.AUTOMATE, "label": "Send your AI clone instead", "en": -2},
	"assistant_answer": {"cls": Cls.AUTOMATE, "label": "Let the Meeting Assistant answer", "en": 0},
	"use_gadget": {"cls": Cls.AUTOMATE, "label": "Use a gadget", "en": -1},
	# --- Deception ---------------------------------------------------------
	"excuse": {"cls": Cls.DECEIVE, "label": "Make an excuse", "en": -4},
	"bluff": {"cls": Cls.DECEIVE, "label": "Bluff", "en": -4},
	"deflect": {"cls": Cls.DECEIVE, "label": "Deflect", "en": -3},
	"blame": {"cls": Cls.DECEIVE, "label": "Blame something else", "en": -4},
	"flatter": {"cls": Cls.DECEIVE, "label": "Flatter", "en": -2},
	"stall": {"cls": Cls.DECEIVE, "label": "Stall", "en": -2},
	"cut_router": {"cls": Cls.DECEIVE, "label": "Pull the router plug", "en": -1},
	"force_update": {"cls": Cls.DECEIVE, "label": "Force a system update", "en": -2},
	# --- Bureaucracy -------------------------------------------------------
	"clarify": {"cls": Cls.BUREAU, "label": "Request clarification", "en": -3},
	"change_request": {"cls": Cls.BUREAU, "label": "File a Form 27-B", "en": -3},
	"escalate": {"cls": Cls.BUREAU, "label": "Escalate to a committee", "en": -3},
	"decline_conflict": {"cls": Cls.BUREAU, "label": "Decline: calendar conflict", "en": -1},
	# --- Social ------------------------------------------------------------
	"do_favor": {"cls": Cls.SOCIAL, "label": "Cover for a colleague", "en": -3},
	"chat": {"cls": Cls.SOCIAL, "label": "Chat", "en": -1},
	# --- Leisure and upkeep ------------------------------------------------
	"leisure": {"cls": Cls.LEISURE, "label": "Relax", "en": 0},
	"maintain": {"cls": Cls.UPKEEP, "label": "Service the gadgets", "en": -8},
	"fix_printer": {"cls": Cls.UPKEEP, "label": "Clear the paper jam", "en": -7},
	"toggle_gadget": {"cls": Cls.UPKEEP, "label": "Toggle a gadget", "en": 0},
	# --- Neutral -----------------------------------------------------------
	"honest": {"cls": Cls.NEUTRAL, "label": "Tell the truth", "en": 0},
	"ack": {"cls": Cls.NEUTRAL, "label": "Acknowledge", "en": 0},
	"ignore": {"cls": Cls.NEUTRAL, "label": "Ignore", "en": 0},
	"use": {"cls": Cls.NEUTRAL, "label": "Use", "en": 0},
}

## Excuse categories that can be attached to a ticket to buy it time.
const BLOCKERS := ["waiting_team", "process_blocker", "data_validation", "prod_incident"]

var tasks: Array = []


func _ready() -> void:
	Game.time.minute_passed.connect(_on_minute)
	Bus.activity_ended.connect(_on_activity_ended)


func setup_run() -> void:
	Db.load_all()
	tasks = []


func save_state() -> Dictionary:
	return {"tasks": tasks}


func load_state(d: Dictionary) -> void:
	tasks = d.get("tasks", [])


# ---------------------------------------------------------------------------
# Work classification
# ---------------------------------------------------------------------------

func cls_of(id: String) -> int:
	return int(DEFS.get(id, DEFS["use"]).cls)


func is_work(id: String) -> bool:
	## The one and only test for "is this legitimate work?".
	return cls_of(id) == Cls.WORK


func energy_cost(id: String) -> float:
	var en := float(DEFS.get(id, DEFS["use"]).get("en", 0))
	if en < 0.0 and Game.active and id in ["fake_update", "fake_report", "jargon"] and Game.automation.can("free_jargon"):
		return 0.0
	return -en


func hp_cost(id: String) -> float:
	## Health this action would cost on the current difficulty.
	var d := Game.diff()
	match cls_of(id):
		Cls.WORK:
			return float(d.work_hp)
		Cls.STRESS:
			return 12.0 if bool(d.lethal) else clampf(float(d.work_hp) * 0.6, 3.0, 12.0)
	return 0.0


func lethal(id: String) -> bool:
	return is_work(id) and bool(Game.diff().lethal)


func can(id: String) -> Dictionary:
	## {ok, why} — can the player afford this right now?
	if not Game.time.running():
		return {"ok": false, "why": "No run in progress"}
	var cost := energy_cost(id)
	if cost > 0.0 and Game.stats.get_value("energy") < cost:
		return {"ok": false, "why": "Too exhausted (need %d energy)" % int(ceil(cost))}
	return {"ok": true, "why": ""}


func badge(id: String) -> Dictionary:
	## {text, color, warn} — how the UI must label this action. Used wherever
	## an action is offered, so the player can always tell work from fake work.
	var c := cls_of(id)
	var info: Dictionary = CLS_INFO[c]
	var text := str(info.tag)
	var warn := false
	if c == Cls.WORK:
		warn = true
		if lethal(id):
			text = "REAL WORK - ENDS YOUR RUN"
		else:
			text = "REAL WORK  -%d HP" % int(hp_cost(id))
	elif c == Cls.STRESS:
		warn = true
		text = "RESPONSIBILITY  -%d HP" % int(hp_cost(id))
	return {"text": text, "color": info.color, "warn": warn}


func perform(id: String, ctx: Dictionary = {}) -> bool:
	## Execute the generic part of an action. Returns false if it could not
	## be performed, or if performing it ended the run.
	if not DEFS.has(id):
		push_warning("WorkSystem.perform: undeclared action '%s'" % id)
		id = "use"
	var check := can(id)
	if not check.ok:
		Bus.toast.emit(str(check.why), "warn")
		return false
	var def: Dictionary = DEFS[id]
	var c := int(def.cls)
	var label := str(ctx.get("label", def.label))
	var cost := energy_cost(id)
	if cost > 0.0:
		Game.stats.add("energy", -cost, str(def.label))
	match c:
		Cls.WORK:
			Game.bump("worked_min", int(def.get("mins", 30)))
			Game.bump("work_actions")
			if bool(Game.diff().lethal):
				Bus.action_performed.emit(id, c, ctx)
				Game.end_run("worked", {"action": label, "reason": "You did actual work."})
				return false
			Game.stats.add("health", -hp_cost(id), "Actual work: %s" % label)
		Cls.STRESS:
			Game.stats.add("health", -hp_cost(id), "Responsibility: %s" % label)
		Cls.DECEIVE:
			Game.bump("lies")
	Bus.action_performed.emit(id, c, ctx)
	return Game.time.running()


# ---------------------------------------------------------------------------
# Tickets
# ---------------------------------------------------------------------------

func add_task(tid: String) -> Dictionary:
	var def: Dictionary = Db.tasks[tid]
	var due_day := Game.time.day + int(def.due_day)
	var due := Game.time.abs_at(mini(due_day, 4), int(def.due_t))
	if due <= Game.time.now() + 60:
		due = Game.time.now() + 120
	due = mini(due, Game.time.abs_at(4, 1010))
	var t := {
		"id": Game.next_id("t"), "tid": tid, "key": str(def.key), "title": str(def.title),
		"desc": str(def.desc), "prio": int(def.prio), "effort": int(def.effort),
		"due": due, "status": "open", "real": 0, "fake": 0.0, "fake_n": 0, "by": "",
		"helper_left": 0, "clarified": false, "botched": false, "slipped": false,
		"demo_asked": false, "nagged": false, "blocked": "", "how": "", "born": Game.time.now(),
	}
	tasks.append(t)
	Game.comms.post("team", "bot", "SynerTasks: %s \"%s\" was assigned to {name}. Due %s." % [t.key, t.title, due_text(due)], "sys")
	Game.comms.notify("SynerTasks", "New ticket %s: %s" % [t.key, t.title], "warn", false)
	Bus.task_changed.emit(t)
	Bus.comms_changed.emit()
	return t


func due_text(due: int) -> String:
	var d := int(due / 1440.0)
	var m := due % 1440
	if d == Game.time.day:
		return "today %s" % Cfg.fmt_time(m)
	return "%s %s" % [Cfg.DAYS_SHORT[clampi(d, 0, 4)], Cfg.fmt_time(m)]


func task(id: String) -> Dictionary:
	for t in tasks:
		if t.id == id:
			return t
	return {}


func open_tasks() -> Array:
	var out: Array = []
	for t in tasks:
		if t.status == "open":
			out.append(t)
	out.sort_custom(func(a, b): return int(a.due) < int(b.due))
	return out


func most_urgent_task() -> Dictionary:
	for t in open_tasks():
		if str(t.by) == "":
			return t
	return {}


func urgent_unfinished() -> Dictionary:
	## A ticket about to be due with little to show for it (and not yet asked about).
	var now := Game.time.now()
	for t in open_tasks():
		if str(t.by) == "" and not bool(t.nagged) and int(t.due) - now <= 90 and int(t.due) - now >= 20 and float(t.fake) < 60.0 and int(t.real) < int(t.effort):
			return t
	return {}


func faked_task() -> Dictionary:
	for t in open_tasks():
		if float(t.fake) > 0.0 and str(t.by) == "" and not bool(t.demo_asked):
			return t
	return {}


func task_looks_done(t: Dictionary) -> bool:
	return float(t.fake) >= 100.0


func extend_deadline(id: String, minutes: int) -> void:
	var t := task(id)
	if t.is_empty() or t.status != "open":
		return
	t.due = mini(int(t.due) + minutes, Game.time.abs_at(4, 1010))
	Bus.toast.emit("%s is now due %s." % [str(t.key), due_text(int(t.due))], "good")
	Bus.task_changed.emit(t)


func set_deadline(id: String, due: int) -> void:
	var t := task(id)
	if t.is_empty() or t.status != "open":
		return
	t.due = clampi(due, Game.time.now() + 30, Game.time.abs_at(4, 1010))
	Bus.toast.emit("%s is now due %s." % [str(t.key), due_text(int(t.due))], "warn")
	Bus.task_changed.emit(t)


func task_work(id: String) -> bool:
	## Legitimate work on a ticket. Classified (and punished) by perform().
	var t := task(id)
	if t.is_empty() or t.status != "open" or Game.activities.busy():
		return false
	if not perform("work_task", {"label": "%s %s" % [t.key, t.title]}):
		return false
	Game.deception.observe("desk_message")
	Game.deception.observe("ticket_activity", {"task": id})
	Game.activities.start({
		"id": "work", "label": "Working on %s" % str(t.key), "mins": 45, "speed": 6.0,
		"anim": "type", "thing": "workstation", "task": id, "per": {},
	})
	return true


func task_fake(id: String, auto: bool = false) -> bool:
	## Post a progress update with nothing behind it.
	var t := task(id)
	if t.is_empty() or t.status != "open":
		return false
	if task_looks_done(t):
		if not auto:
			Bus.toast.emit("It already looks 100% done. More updates would be suspicious.", "warn")
		return false
	if not auto and not perform("fake_update", {"label": "Fake update on %s" % str(t.key)}):
		return false
	t.fake = minf(100.0, float(t.fake) + float(Game.rng.randi_range(22, 34)))
	t.fake_n = int(t.fake_n) + 1
	Game.stats.add("ill", 3.5, "Fake update")
	Game.comms.post("team", "me", Dialogue.fake_update_line(t), "auto")
	Game.deception.observe("auto_message" if auto else "desk_message")
	Game.deception.observe("ticket_activity", {"task": id})
	if not bool(t.demo_asked) and Game.chance(maxf(0.0, float(int(t.fake_n) - 2)) * 15.0 * float(Game.diff().boss_check)):
		t.demo_asked = true
		Game.events.fire_later(Game.rng.randi_range(6, 18), "demo_demand", {"task": id})
	if not auto:
		Game.presence.touch()
	Bus.task_changed.emit(t)
	return true


func blockers() -> Array:
	## Excuse categories that can be attached to a ticket.
	var out: Array = []
	for type in BLOCKERS:
		if Db.claims.has(type):
			out.append(type)
	return out


func task_block(id: String, claim_type: String) -> Dictionary:
	## Tell the boss the ticket is stuck on something outside your control.
	var t := task(id)
	if t.is_empty() or t.status != "open" or str(t.blocked) != "" or not Db.claims.has(claim_type):
		return {"done": false}
	if not perform("excuse", {"label": "%s: %s" % [str(t.key), str(Db.claims[claim_type].title)]}):
		return {"done": false}
	var boss := Game.npcs.boss_id()
	Game.deception.observe("desk_message")
	var att := Game.deception.attempt(claim_type, "ticket", boss, str(t.key), id)
	Game.comms.post("team", "me", "%s: %s" % [str(t.key), str(Db.claims[claim_type].line)])
	if bool(att.ok):
		t.blocked = claim_type
		Game.comms.post("team", boss, str(att.say), "good")
		Bus.sfx.emit("good")
	else:
		Game.stats.add("susp", 5.0, "Transparent stalling")
		Game.comms.post("team", boss, str(att.say), "bad")
		Bus.sfx.emit("bad")
	Game.presence.touch()
	Bus.task_changed.emit(t)
	return {"done": true, "ok": bool(att.ok), "say": str(att.say)}


func task_delegate(id: String) -> bool:
	var t := task(id)
	if t.is_empty() or t.status != "open" or str(t.by) != "":
		return false
	if Game.economy.favors < 1:
		Bus.toast.emit("Nobody owes you a favour. Cover for a colleague first.", "warn")
		return false
	if not perform("delegate_colleague", {"label": "Delegate %s" % str(t.key)}):
		return false
	Game.economy.add_favor(-1)
	t.by = "dave"
	t.helper_left = int(t.effort) * 30
	Game.bump("tasks_delegated")
	Game.comms.say("dave", "Fine. I'll do %s. But we're even. And you never saw me at the driving range." % str(t.key), false)
	Bus.task_changed.emit(t)
	return true


func task_ai(id: String) -> bool:
	var t := task(id)
	if t.is_empty() or t.status != "open" or str(t.by) != "":
		return false
	if not Game.automation.can("do_tickets"):
		Bus.toast.emit("Needs a working %s that can do tickets." % Game.automation.owner_of("do_tickets"), "warn")
		return false
	if str(Game.automation.autos.ai_task) != "":
		Bus.toast.emit("Your clone is already busy with another ticket.", "warn")
		return false
	if not perform("delegate_ai", {"label": "Delegate %s to AI" % str(t.key)}):
		return false
	t.by = Game.automation.provider("do_tickets")
	Game.bump("tasks_delegated")
	Game.automation.assign_ai(id)
	Bus.task_changed.emit(t)
	return true


func task_clarify(id: String) -> bool:
	## Bureaucracy: open a clarification request with another team. It leaves
	## a paper trail that backs up a later "waiting on another team".
	var t := task(id)
	if t.is_empty() or t.status != "open" or bool(t.clarified):
		return false
	if not perform("clarify", {"label": "Clarify %s" % str(t.key)}):
		return false
	t.clarified = true
	Game.stats.add("ill", 2.0, "Asked a 'clarifying question'")
	Game.comms.post("team", "me", "Raised a clarification request with Platform on the acceptance criteria for %s." % str(t.key), "auto")
	Game.deception.observe("desk_message")
	Bus.toast.emit("Paper trail created. 'Waiting on another team' will now check out.", "good")
	Game.presence.touch()
	Bus.task_changed.emit(t)
	return true


func task_change_request(id: String) -> bool:
	## Bureaucracy: bury the ticket in process. Once per day.
	var t := task(id)
	var key := "cr_day_%d" % Game.time.day
	if t.is_empty() or t.status != "open":
		return false
	if Game.flag(key):
		Bus.toast.emit("The Change Advisory Board only accepts one Form 27-B per day.", "warn")
		return false
	if not perform("change_request", {"label": "Form 27-B for %s" % str(t.key)}):
		return false
	Game.set_flag(key)
	Game.deception.observe("desk_message")
	if Game.deception.roll(46.0 + 6.0 * float(3 - int(t.prio)), ["jargon"]):
		t.status = "cancelled"
		t.how = "descoped"
		Game.stats.add("ill", 2.0, "Process champion")
		Game.comms.post("team", "bot", "SynerTasks: %s moved to 'Descoped - pending steering committee review (est. Q4)'." % str(t.key), "sys")
		Bus.toast.emit("%s is now the steering committee's problem. Forever." % str(t.key), "good")
	else:
		Game.stats.add("susp", 5.0, "Frivolous Form 27-B")
		Game.comms.say(Game.npcs.boss_id(), "We are not convening a steering committee over %s. The form stays on file, though." % str(t.key))
	Game.presence.touch()
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
		Game.stats.add("ill", 3.0, "Real progress")
		Game.stats.add("susp", -2.0, "Real progress")
	if int(t.real) >= int(t.effort):
		_complete(t, by)
	Bus.task_changed.emit(t)


func _complete(t: Dictionary, by: String) -> void:
	t.status = "done"
	t.how = by
	Game.bump("tasks_done")
	if bool(t.botched):
		Game.time.schedule(Game.time.now() + Game.rng.randi_range(20, 60), "bounce", {"task": str(t.id)})
	Game.stats.add("ill", 9.0 if by == "me" else 7.0, "Ticket closed")
	if by == "me":
		Game.stats.add("susp", -4.0, "Ticket closed")
	Game.comms.post("team", "bot", "SynerTasks: %s was closed by {name}." % str(t.key), "sys")
	Bus.task_changed.emit(t)


func _deadline(t: Dictionary) -> void:
	var key := str(t.key)
	var boss := Game.npcs.boss_id()
	if task_looks_done(t):
		if Game.deception.roll(64.0 - 6.0 * float(3 - int(t.prio)), ["jargon"]):
			t.status = "done"
			t.how = "faked"
			Game.bump("tasks_faked")
			Game.stats.add("ill", 5.0, "Shipped an illusion")
			Game.comms.post("team", "bot", "SynerTasks: %s auto-closed (status: Looks Done)." % key, "sys")
			Game.comms.notify("SynerTasks", "%s closed. Nobody looked inside." % key, "good")
		else:
			t.status = "failed"
			Game.bump("tasks_failed")
			Game.stats.add("susp", 11.0, "QA opened %s" % key)
			Game.stats.add("ill", -8.0, "QA opened %s" % key)
			Game.comms.say(boss, "QA opened %s. It's a TODO comment and a photo of a duck. Explain." % key)
		Bus.task_changed.emit(t)
		return
	var frac := maxf(float(t.real) / float(t.effort), float(t.fake) / 100.0 * 0.7)
	if str(t.by) != "":
		frac = maxf(frac, 0.6)
	if frac >= 0.5 and not bool(t.slipped):
		t.slipped = true
		t.due = mini(int(t.due) + 1440, Game.time.abs_at(4, 1015))
		Game.stats.add("susp", 5.0, "%s slipped" % key)
		Game.stats.add("ill", -3.0, "%s slipped" % key)
		Game.comms.say(boss, "%s is late. I'm moving it to %s. Don't make me move it again." % [key, due_text(int(t.due))])
	else:
		t.status = "failed"
		Game.bump("tasks_failed")
		Game.stats.add("susp", 8.0 + 3.0 * float(3 - int(t.prio)), "Missed deadline: %s" % key)
		Game.stats.add("ill", -8.0, "Missed deadline")
		Game.comms.say(boss, "%s is overdue and untouched. I've reassigned it to Priya. We need to talk." % key)
	Bus.task_changed.emit(t)


# ---------------------------------------------------------------------------
# Status reports
# ---------------------------------------------------------------------------

func report_sent() -> bool:
	return Game.flag("report_day_%d" % Game.time.day)


func fake_report(auto: bool) -> bool:
	## The daily status report, generated rather than written.
	if report_sent():
		if not auto:
			Bus.toast.emit("You already sent a status report today. Two would look desperate.", "warn")
		return false
	if not auto and not perform("fake_report", {"label": "Fake status report"}):
		return false
	Game.set_flag("report_day_%d" % Game.time.day)
	var boss := Game.npcs.boss_id()
	Game.comms.add_mail_raw({"from": "me", "subject": "Daily Status: Strategic Momentum Update", "body": Dialogue.fake_report_text(), "sent": true})
	Game.deception.observe("auto_report" if auto else "desk_message")
	if auto or Game.deception.roll(74.0, ["jargon"]):
		Game.stats.add("ill", 8.0 if auto else 9.0, "Status report")
		if not auto:
			Game.comms.say(boss, str(Game.pick(Db.lines("report_ok"))), false)
			Bus.toast.emit("Report sent. It contains zero information. Perfect.", "good")
	else:
		Game.stats.add("ill", 2.0, "Status report")
		Game.stats.add("susp", 5.0, "%s actually read your report" % Game.npcs.boss_name())
		Game.comms.say(boss, "I read your report twice. What is a 'holistic deliverable runway'?")
	return true


func real_report() -> bool:
	if report_sent():
		Bus.toast.emit("You already sent a status report today.", "warn")
		return false
	if not perform("write_report", {"label": "Real status report"}):
		return false
	Game.set_flag("report_day_%d" % Game.time.day)
	Game.stats.add("ill", 10.0, "Honest report")
	Game.stats.add("susp", -5.0, "Honest report")
	Game.deception.observe("desk_message")
	Game.comms.add_mail_raw({"from": "me", "subject": "Daily Status (accurate)", "body": "A painfully honest account of the day. It took 45 minutes of your one life.", "sent": true})
	return true


# ---------------------------------------------------------------------------
# Ticking
# ---------------------------------------------------------------------------

func _on_minute() -> void:
	if not Game.time.running() or Game.time.phase != "work":
		return
	var now := Game.time.now()
	for tk in tasks:
		if not Game.time.running():
			return
		if tk.status != "open":
			continue
		if int(tk.helper_left) > 0 and Game.time.in_work_hours():
			tk.helper_left = int(tk.helper_left) - 1
			if int(tk.helper_left) <= 0:
				var who := str(tk.by)
				task_progress(str(tk.id), int(tk.effort), 0.18 if who == "kevin" else 0.04, who)
				if tk.status == "done":
					Game.comms.notify("SynerTasks", "%s finished %s for you." % [Game.npcs.display_name(who), str(tk.key)], "good")
				continue
		if now >= int(tk.due):
			_deadline(tk)


func _on_activity_ended(a: Dictionary, completed: bool) -> void:
	if str(a.get("id", "")) != "work" or not Game.active:
		return
	if completed:
		task_progress(str(a.task), 1, 0.0, "me")
	else:
		Bus.toast.emit("You stopped working. The damage is already done.", "warn")
