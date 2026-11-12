class_name GameManager
extends Node
## GameManager (autoload "Game") — the composition root of the simulation.
##
## It owns the run lifecycle (new run, day flow, victory and loss), the
## difficulty, run statistics, and one instance of every system. Systems
## keep their own state and talk to each other through this node and
## through signals; nothing in here references a scene or a Control.

signal day_started(day: int)
signal workday_ended(report: Dictionary)
signal run_ended(result: Dictionary)

const SAVE_VERSION := 3

# --- Systems -----------------------------------------------------------------
var time: TimeManager
var stats: PlayerStats
var economy: EconomyManager
var presence: Presence
var activities: Activities
var home: Home
var work: WorkSystem
var comms: Comms
var deception: DeceptionManager
var automation: AutomationManager
var npcs: NPCManager
var social: Social
var events: EventDirector
var tutor: Tutorial
var saves: SaveManager
var _systems: Dictionary = {}      ## name -> GameSystem, in setup order

# --- Run state ---------------------------------------------------------------
var active := false                ## a run is loaded
var paused := false                ## UI pause (menus, reports, calls)
var difficulty_id := "survivor"
var player: Dictionary = {}        ## name and appearance
var player_pos: Array = []         ## [x, z, yaw] written by the world before saving
var flags: Dictionary = {}
var today: Dictionary = {}         ## statistics for the current day
var week: Dictionary = {}          ## statistics for the whole run
var reports: Array = []            ## one end-of-day report per finished day
var result: Dictionary = {}        ## set when the run ends
var rng := RandomNumberGenerator.new()
var _next_id := 1


func _init() -> void:
	Db.load_all()
	_define_input()
	time = _add("time", TimeManager.new())
	stats = _add("stats", PlayerStats.new())
	economy = _add("economy", EconomyManager.new())
	presence = _add("presence", Presence.new())
	activities = _add("activities", Activities.new())
	home = _add("home", Home.new())
	npcs = _add("npcs", NPCManager.new())
	social = _add("social", Social.new())
	work = _add("work", WorkSystem.new())
	comms = _add("comms", Comms.new())
	deception = _add("deception", DeceptionManager.new())
	automation = _add("automation", AutomationManager.new())
	events = _add("events", EventDirector.new())
	tutor = _add("tutor", Tutorial.new())
	saves = SaveManager.new()
	saves.name = "saves"
	add_child(saves)


func _add(sys_name: String, sys: GameSystem) -> Variant:
	sys.name = sys_name
	_systems[sys_name] = sys
	add_child(sys)
	return sys


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	today = _blank_stats()
	week = _blank_stats()


static func _define_input() -> void:
	## Input actions are defined in code so the project file stays minimal.
	for action in Cfg.KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for key in Cfg.KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func new_run(difficulty: String, who: Dictionary, tutorial: bool = true, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	difficulty_id = difficulty if Db.difficulties.has(difficulty) else "survivor"
	player = who.duplicate(true)
	player_pos = []
	flags = {}
	today = _blank_stats()
	week = _blank_stats()
	reports = []
	result = {}
	_next_id = 1
	active = true
	paused = false
	for sys_name in _systems:
		(_systems[sys_name] as GameSystem).setup_run()
	tutor.begin(tutorial)
	time.hold = tutorial
	events.plan_day()
	presence.update()
	Bus.state_loaded.emit()
	day_started.emit(0)


func clear_run() -> void:
	active = false
	paused = false
	time.phase = "over"
	time.speed = 1.0
	activities.current = {}
	result = {}


func diff() -> Dictionary:
	return Cfg.diff(difficulty_id)


func player_name() -> String:
	return str(player.get("name", "Alex"))


# ---------------------------------------------------------------------------
# Save / load
# ---------------------------------------------------------------------------

func save_state() -> Dictionary:
	var d := {
		"version": SAVE_VERSION,
		"run": {
			"difficulty": difficulty_id, "player": player, "player_pos": player_pos, "flags": flags,
			"today": today, "week": week, "reports": reports, "next_id": _next_id, "rng": rng.state,
		},
		"systems": {},
	}
	for sys_name in _systems:
		d.systems[sys_name] = (_systems[sys_name] as GameSystem).save_state()
	return d


func load_state(d: Dictionary) -> bool:
	if int(d.get("version", -1)) != SAVE_VERSION:
		return false
	var run: Dictionary = d.get("run", {})
	var sys_data: Dictionary = d.get("systems", {})
	for sys_name in _systems:
		if not sys_data.has(sys_name):
			push_warning("Save is missing system '%s'" % sys_name)
			return false
	difficulty_id = str(run.get("difficulty", "survivor"))
	player = run.get("player", {})
	player_pos = run.get("player_pos", [])
	flags = run.get("flags", {})
	today = run.get("today", _blank_stats())
	week = run.get("week", _blank_stats())
	reports = run.get("reports", [])
	_next_id = int(run.get("next_id", 1))
	if run.has("rng"):
		rng.state = int(run.rng)
	result = {}
	active = true
	paused = false
	for sys_name in _systems:
		(_systems[sys_name] as GameSystem).load_state(sys_data[sys_name])
	time.set_speed(float(activities.current.get("speed", 1.0)) if activities.busy() else 1.0)
	presence.update()
	Bus.state_loaded.emit()
	return true


# ---------------------------------------------------------------------------
# Statistics
# ---------------------------------------------------------------------------

func _blank_stats() -> Dictionary:
	return {
		"worked_min": 0, "work_actions": 0, "pretend_min": 0, "leisure_min": 0, "slack_min": 0,
		"excuses": 0, "excuses_failed": 0, "lies": 0, "lies_landed": 0, "contradictions": 0,
		"meetings_avoided": 0, "meetings_attended": 0, "meetings_missed": 0,
		"prompts_answered": 0, "prompts_ignored": 0,
		"susp_gained": 0.0, "susp_lost": 0.0,
		"auto_runs": 0, "auto_ok": 0,
		"tasks_done": 0, "tasks_faked": 0, "tasks_delegated": 0, "tasks_failed": 0,
		"absent_min": 0, "salary": 0, "spent": 0,
		"calls_taken": 0, "calls_dodged": 0, "colleagues_ignored": 0, "snitched": 0,
		"favours_called": 0, "small_talk": 0, "gifts": 0, "tipoffs": 0, "tasks_lost": 0,
	}


func bump(key: String, amount: float = 1.0) -> void:
	## Add to a statistic for both today and the week.
	today[key] = today.get(key, 0) + amount
	week[key] = week.get(key, 0) + amount


# ---------------------------------------------------------------------------
# Day flow
# ---------------------------------------------------------------------------

func after_minute(phase_before: String) -> void:
	## Called by the TimeManager at the end of every tick.
	if phase_before == "work" and time.minute >= Cfg.WORK_END:
		_end_workday()
	elif time.phase == "evening" and time.minute >= TimeManager.LATEST_BEDTIME:
		Bus.toast.emit("You passed out mid-scroll. Terrible sleep.", "warn")
		sleep()


func _end_workday() -> void:
	activities.stop()
	comms.close_day()
	var rep := build_report()
	var boss := npcs.boss_name()
	# The boss's end-of-day gut feeling.
	if float(rep.ill) < 25.0:
		stats.add("susp", 8.0, "End of day: 'What does this person DO?'")
		rep.verdict = "%s left the office wondering what you actually do." % boss
	elif float(rep.ill) >= 70.0:
		stats.add("susp", -6.0, "End of day: looks like a busy bee")
		rep.verdict = "%s left the office convinced you're a machine." % boss
	else:
		rep.verdict = "%s left the office thinking about lunch, not you." % boss
	if not time.running():
		return
	economy.pay_salary(int(rep.salary))
	rep.susp_end = stats.values.susp
	reports.append(rep)
	presence.in_call = false
	time.set_phase("evening")
	workday_ended.emit(rep)


func build_report() -> Dictionary:
	var td := today
	var pay := economy.day_salary(int(td.worked_min), stats.get_value("ill"), stats.get_value("susp"))
	td.salary = int(pay.total)
	week.salary = int(week.salary) + int(pay.total)
	var runs := int(td.auto_runs)
	var eff := -1.0
	if runs > 0:
		eff = 100.0 * float(td.auto_ok) / float(runs)
	return {
		"day": time.day,
		"hours_employed": 8.0,
		"worked_min": int(td.worked_min),
		"pretend_min": int(td.pretend_min),
		"leisure_min": int(td.leisure_min),
		"slack_min": int(td.slack_min),
		"excuses": int(td.excuses),
		"meetings_avoided": int(td.meetings_avoided),
		"meetings_attended": int(td.meetings_attended),
		"meetings_missed": int(td.meetings_missed),
		"calls_taken": int(td.get("calls_taken", 0)),
		"snitched": int(td.get("snitched", 0)),
		"favours_called": int(td.get("favours_called", 0)),
		"salary": int(pay.total),
		"salary_lines": pay.lines,
		"susp_gained": float(td.susp_gained),
		"susp_lost": float(td.susp_lost),
		"susp": stats.get_value("susp"),
		"health": stats.get_value("health"),
		"ill": stats.get_value("ill"),
		"auto_eff": eff,
		"auto_runs": runs,
		"absent_min": int(td.absent_min),
		"title": _day_title(td),
		"verdict": "",
	}


func _day_title(td: Dictionary) -> String:
	var worked := int(td.worked_min)
	if worked == 0 and int(td.slack_min) >= 240:
		return "Paid Vacationer"
	if worked == 0 and int(td.excuses) >= 4:
		return "Sultan of Excuses"
	if worked == 0 and int(td.auto_runs) >= 4:
		return "Fully Automated Luxury Employee"
	if worked == 0 and stats.get_value("ill") >= 70.0:
		return "Thought Leader (Zero Thoughts)"
	if worked == 0 and int(td.slack_min) >= 150:
		return "Paid Vacationer"
	if worked == 0:
		return "Certified Seat Warmer"
	if worked <= 60:
		return "Reluctant Contributor"
	if worked <= 180:
		return "Suspiciously Productive"
	return "Actual Employee (Disappointing)"


func sleep() -> void:
	## End the evening and start the next workday.
	if not active or time.phase != "evening":
		return
	activities.stop()
	var hours := clampf((1440.0 + Cfg.DAY_START - time.minute) / 60.0, 3.0, 10.0)
	time.day += 1
	time.minute = float(Cfg.DAY_START)
	time._acc = 0.0
	time.phase = "work"
	stats.add("energy", hours * 11.0, "Sleep")
	stats.add("health", hours * 1.5, "Sleep")
	today = _blank_stats()
	for sys_name in _systems:
		(_systems[sys_name] as GameSystem).new_day()
	events.plan_day()
	presence.update()
	time.phase_changed.emit("work")
	day_started.emit(time.day)
	saves.autosave()


func finish_week() -> void:
	## Called once the Friday report has been shown.
	if time.running():
		end_run("win", {})


func end_run(kind: String, info: Dictionary = {}) -> void:
	if not time.running():
		return
	activities.stop()
	var res := build_result(kind, info)
	result = res
	time.set_speed(1.0)
	time.set_phase("over")
	run_ended.emit(res)


func build_result(kind: String, info: Dictionary) -> Dictionary:
	var wk := week
	var d := diff()
	var worked := int(wk.worked_min)
	var won := kind == "win"
	var susp := stats.get_value("susp")
	var score := 0.0
	score += float(economy.money) * 1.0
	score += float(wk.salary) * 0.5
	score += float(wk.slack_min) * 2.5
	score += float(wk.leisure_min) * 0.3
	score += float(wk.meetings_avoided) * 40.0
	score += float(wk.excuses) * 10.0
	score -= float(worked) * 3.0
	if won:
		score += 600.0 + (100.0 - susp) * 6.0
		if worked == 0:
			score += 800.0
	score = maxf(0.0, score) * float(d.score)
	var grade := "F"
	var slack := int(wk.slack_min)
	if won:
		if worked == 0 and slack >= Cfg.SLACK_S:
			grade = "S"
		elif worked == 0 and slack >= Cfg.SLACK_A:
			grade = "A"
		elif worked <= 60:
			grade = "B"
		elif worked <= 360:
			grade = "C"
		else:
			grade = "D"
	# Work avoidance: the share of the hours you were paid for in which you
	# did no legitimate work.
	var paid := float((time.day + 1) * 480 if won else time.day * 480 + clampi(int(time.minute) - Cfg.WORK_START, 0, 480))
	var avoidance := 100.0 if paid <= 0.0 else clampf(100.0 * (1.0 - float(worked) / paid), 0.0, 100.0)
	var runs := int(wk.auto_runs)
	var friends := 0
	for id in social.colleagues():
		if social.tier(id) >= Social.Tier.FRIENDLY:
			friends += 1
	var rating := ""
	if won and worked == 0:
		rating = "IMMACULATE: zero minutes of actual work"
	return {
		"avoidance": avoidance,
		"paid_min": paid,
		"salary": economy.earned,
		"deceptions": int(wk.get("lies_landed", 0)),
		"caught": deception.caught(),
		"claims": deception.claims.size(),
		"friends": friends,
		"colleagues": social.colleagues().size(),
		"snitched": int(wk.get("snitched", 0)),
		"favours_called": int(wk.get("favours_called", 0)),
		"auto_eff": -1.0 if runs == 0 else 100.0 * float(wk.auto_ok) / float(runs),
		"rating": rating,
		"kind": kind,
		"won": won,
		"day": time.day,
		"time": time.minute,
		"grade": grade,
		"score": int(round(score)),
		"reason": str(info.get("reason", "")),
		"action": str(info.get("action", "")),
		"week": wk.duplicate(true),
		"money": economy.money,
		"susp": susp,
		"health": stats.get_value("health"),
		"ill": stats.get_value("ill"),
		"diff": difficulty_id,
		"reports": reports.duplicate(true),
	}


# ---------------------------------------------------------------------------
# Small helpers used across systems
# ---------------------------------------------------------------------------

func next_id(prefix: String) -> String:
	_next_id += 1
	return "%s%d" % [prefix, _next_id - 1]


func chance(pct: float) -> bool:
	return rng.randf() * 100.0 < pct


func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[rng.randi() % arr.size()]


func flag(id: String) -> bool:
	return bool(flags.get(id, false))


func set_flag(id: String, v: Variant = true) -> void:
	flags[id] = v
