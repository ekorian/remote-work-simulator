extends Node
## Actions — the single place that decides what counts as WORK.
##
## Every player-initiated gameplay action is declared in DEFS with a class.
## Gameplay scripts never apply work penalties themselves: they call
## `Actions.perform(id, ctx)` and only carry on if it returns true.
## The work health penalty, the Professional Unemployed instant-loss rule,
## energy costs and all bookkeeping live here and nowhere else.

enum Cls {
	WORK,      ## legitimate work: costs health, lethal on Professional Unemployed
	STRESS,    ## accepting corporate responsibility: costs health, never lethal
	FAKE,      ## simulating work: allowed, feeds the productivity illusion
	DELEGATE,  ## making it someone (or something) else's problem
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
	"record_loop": {"cls": Cls.FAKE, "label": "Record a webcam loop", "en": -4},
	"forge_note": {"cls": Cls.FAKE, "label": "Print a forged document", "en": -3},
	"report_phish": {"cls": Cls.FAKE, "label": "Report it and look vigilant", "en": -1},
	# --- Delegation --------------------------------------------------------
	"delegate_ai": {"cls": Cls.DELEGATE, "label": "Delegate to the AI assistant", "en": -2},
	"delegate_colleague": {"cls": Cls.DELEGATE, "label": "Call in a favour", "en": -3},
	"forward": {"cls": Cls.DELEGATE, "label": "Forward it to someone else", "en": -2},
	"send_loop": {"cls": Cls.DELEGATE, "label": "Send the webcam loop instead", "en": -2},
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


func cls_of(id: String) -> int:
	return int(DEFS.get(id, DEFS["use"]).cls)


func is_work(id: String) -> bool:
	## The one and only test for "is this legitimate work?".
	return cls_of(id) == Cls.WORK


func energy_cost(id: String) -> float:
	var en := float(DEFS.get(id, DEFS["use"]).get("en", 0))
	if en < 0.0 and cls_of(id) == Cls.FAKE and Auto.working("buzzword") and id in ["fake_update", "fake_report", "jargon"]:
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
	if not Game.active or Game.s.phase == "over":
		return {"ok": false, "why": "No run in progress"}
	var cost := energy_cost(id)
	if cost > 0.0 and Game.get_stat("energy") < cost:
		return {"ok": false, "why": "Too exhausted (need %d energy)" % int(ceil(cost))}
	return {"ok": true, "why": ""}


func badge(id: String) -> Dictionary:
	## {text, color, warn} — how the UI must label this action. Used everywhere
	## an action is offered, so the player can always tell work from fake work.
	var c := cls_of(id)
	var info: Dictionary = CLS_INFO[c]
	var text: String = info.tag
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
	## Execute the generic part of an action. Returns false if it could not be
	## performed, or if performing it ended the run.
	if not DEFS.has(id):
		push_warning("Actions.perform: undeclared action '%s'" % id)
		id = "use"
	var check := can(id)
	if not check.ok:
		Bus.toast.emit(check.why, "warn")
		return false
	var def: Dictionary = DEFS[id]
	var c := int(def.cls)
	var cost := energy_cost(id)
	if cost > 0.0:
		Game.add("energy", -cost, str(def.label))
	match c:
		Cls.WORK:
			Game.bump("worked_min", int(def.get("mins", 30)))
			Game.bump("work_actions")
			if bool(Game.diff().lethal):
				Bus.action_performed.emit(id, c, ctx)
				Game.end_run("worked", {"action": str(ctx.get("label", def.label)), "reason": "You did actual work."})
				return false
			Game.add("health", -hp_cost(id), "Actual work: %s" % str(ctx.get("label", def.label)))
		Cls.STRESS:
			Game.add("health", -hp_cost(id), "Responsibility: %s" % str(ctx.get("label", def.label)))
		Cls.DECEIVE:
			Game.bump("lies")
	Bus.action_performed.emit(id, c, ctx)
	return Game.active and Game.s.phase != "over"
