extends Node
## Game — owns the run state, the clock, and the four central resources.
##
## The whole simulation state lives in the plain Dictionary `s`, which makes
## save/load a single serialisation call. Every change to health, energy,
## suspicion or productivity illusion goes through `add()`, which applies the
## difficulty multipliers, clamps, records statistics and emits `stat_changed`.

signal stat_changed(stat: String, value: float, delta: float, reason: String)
signal money_changed(value: int, delta: int, reason: String)
signal favor_changed(value: int)
signal minute_passed()
signal phase_changed(phase: String)
signal day_started(day: int)
signal workday_ended(report: Dictionary)
signal run_ended(result: Dictionary)
signal presence_changed(status: String)
signal buffs_changed()
signal speed_changed(speed: float)

const STATS := ["health", "energy", "susp", "ill"]
const STAT_NAMES := {"health": "Health", "energy": "Energy", "susp": "Suspicion", "ill": "Productivity Illusion"}
const LATEST_BEDTIME := 1440 + 120   # 02:00 — you pass out

var s: Dictionary = {}
var active := false       ## a run is loaded
var paused := false       ## UI pause (menus, reports)
var manual := false       ## tests / bots drive the clock with advance()
var speed := 1.0
var rng := RandomNumberGenerator.new()
var _acc := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func new_run(difficulty: String, player: Dictionary, tutorial: bool = true, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	s = {
		"v": 1,
		"diff": difficulty,
		"player": player.duplicate(true),
		"outfit": "casual",
		"day": 0,
		"t": float(Cfg.DAY_START),
		"phase": "work",
		"health": 100.0, "energy": 90.0, "susp": 8.0, "ill": 45.0,
		"money": Cfg.START_MONEY,
		"favor": 0,
		"pres": {
			"at_desk": false, "last_input": -999, "status": "away", "mug_until": -1,
			"focus_until": -1, "focus_used": 0, "absent_run": 0, "absent_total": 0,
			"in_call": false, "nagged": false,
		},
		"cover": {"until": -1, "cat": ""},
		"things": {},
		"buffs": {},
		"gadgets": {},
		"autos": {},
		"threads": {},
		"prompts": [],
		"tasks": [],
		"meetings": [],
		"mails": [],
		"next_id": 1,
		"ledger": [],
		"queue": [],
		"flags": {},
		"act": {},
		"today": _blank_stats(),
		"week": _blank_stats(),
		"reports": [],
		"tut": {"on": tutorial, "step": 0, "done": not tutorial, "ticked": []},
		"hold": tutorial,          # tutorial: the clock waits until you first log in
		"pos": [],
	}
	active = true
	paused = false
	speed = 1.0
	_acc = 0.0
	Interact.setup_run()
	Auto.setup_run()
	Corp.setup_run()
	Director.setup_run()
	Director.plan_day()
	_update_presence()
	Bus.state_loaded.emit()
	day_started.emit(0)


func clear_run() -> void:
	active = false
	paused = false
	speed = 1.0
	s = {}


func _blank_stats() -> Dictionary:
	return {
		"worked_min": 0, "work_actions": 0, "pretend_min": 0, "leisure_min": 0, "slack_min": 0,
		"excuses": 0, "excuses_failed": 0, "lies": 0, "contradictions": 0,
		"meetings_avoided": 0, "meetings_attended": 0, "meetings_missed": 0,
		"prompts_answered": 0, "prompts_ignored": 0,
		"susp_gained": 0.0, "susp_lost": 0.0,
		"auto_runs": 0, "auto_ok": 0,
		"tasks_done": 0, "tasks_faked": 0, "tasks_delegated": 0, "tasks_failed": 0,
		"absent_min": 0, "salary": 0, "spent": 0,
	}


func bump(key: String, amount: float = 1.0) -> void:
	## Add to a statistic for both today and the week.
	for scope in ["today", "week"]:
		var d: Dictionary = s[scope]
		d[key] = d.get(key, 0) + amount


# ---------------------------------------------------------------------------
# Time
# ---------------------------------------------------------------------------

func now() -> int:
	## Absolute minute since Monday 00:00.
	return int(s.day) * 1440 + int(s.t)


func clock() -> float:
	## Minute of the day including the sub-minute fraction (for smooth UI).
	return float(s.t) + _acc


func abs_at(day: int, minute: int) -> int:
	return day * 1440 + minute


func in_work_hours() -> bool:
	return s.phase == "work" and s.t >= Cfg.WORK_START and s.t < Cfg.WORK_END


func day_name() -> String:
	return Cfg.DAYS[clampi(int(s.day), 0, 4)]


func diff() -> Dictionary:
	return Cfg.diff(s.get("diff", "survivor"))


func _process(delta: float) -> void:
	if not active or paused or manual or s.get("phase", "over") == "over":
		return
	if bool(s.get("hold", false)):
		return
	_acc += delta * Cfg.MIN_PER_SEC * speed * pace()
	var guard := 0
	while _acc >= 1.0 and guard < 60:
		_acc -= 1.0
		guard += 1
		tick()
		if paused or not active or s.phase == "over":
			_acc = 0.0
			break


func pace() -> float:
	## The first tutorial morning runs slower so there is time to read.
	if bool(s.tut.on) and not bool(s.tut.done) and int(s.day) == 0 and speed <= 1.0:
		return 0.6
	return 1.0


func advance(minutes: int) -> void:
	## Step the simulation synchronously (tests, bots, meeting time-skips).
	for i in minutes:
		if not active or s.phase == "over":
			return
		tick()


func tick() -> void:
	## One game minute.
	var phase_before: String = s.phase
	s.t += 1.0
	_update_presence()
	if in_work_hours():
		_passive()
	_tick_activity()
	_tick_buffs()
	minute_passed.emit()
	if not active or s.phase == "over":
		return
	if phase_before == "work" and s.t >= Cfg.WORK_END:
		_end_workday()
	elif s.phase == "evening" and s.t >= LATEST_BEDTIME:
		Bus.toast.emit("You passed out mid-scroll. Terrible sleep.", "warn")
		sleep()


func set_speed(v: float) -> void:
	if is_equal_approx(speed, v):
		return
	speed = v
	speed_changed.emit(speed)


func alert() -> void:
	## Something wants the player's attention: drop out of fast-forward.
	if speed > 1.0:
		set_speed(1.0)


# ---------------------------------------------------------------------------
# Resources (the single write path)
# ---------------------------------------------------------------------------

func add(stat: String, delta: float, reason: String = "") -> float:
	## Apply a change to one of the four central resources. Returns the applied delta.
	if not active or s.phase == "over" or is_zero_approx(delta):
		return 0.0
	var d := diff()
	if stat == "susp" and delta > 0.0:
		delta *= float(d.susp)
	elif (stat == "health" or stat == "energy") and delta > 0.0:
		delta *= float(d.recover)
	elif stat == "energy" and delta < 0.0 and has_buff("endorphins"):
		delta *= 0.6
	elif stat == "ill" and delta > 0.0:
		# The more impressive you already look, the harder it is to look more so.
		delta *= clampf(1.3 - float(s.ill) / 100.0, 0.35, 1.0)
	var before: float = s[stat]
	var after: float = clampf(before + delta, 0.0, 100.0)
	var applied := after - before
	s[stat] = after
	if stat == "susp":
		if applied > 0.0:
			bump("susp_gained", applied)
		else:
			bump("susp_lost", -applied)
	if not is_zero_approx(applied):
		stat_changed.emit(stat, after, applied, reason)
	if stat == "health" and after <= 0.0:
		end_run("burnout", {"reason": reason})
	elif stat == "susp" and after >= 100.0:
		end_run("fired", {"reason": reason})
	return applied


func get_stat(stat: String) -> float:
	return float(s.get(stat, 0.0))


func add_money(delta: int, reason: String = "") -> void:
	s.money = int(s.money) + delta
	if delta < 0:
		bump("spent", -delta)
	money_changed.emit(int(s.money), delta, reason)


func add_favor(delta: int) -> void:
	s.favor = maxi(0, int(s.favor) + delta)
	favor_changed.emit(int(s.favor))


func apply_fx(fx: Dictionary, reason: String = "") -> void:
	## Apply a data-driven effect bundle: {susp, ill, hp, en, money, favor, cover, buff, flag}.
	if fx.has("susp"):
		add("susp", float(fx.susp), reason)
	if fx.has("ill"):
		add("ill", float(fx.ill), reason)
	if fx.has("hp"):
		add("health", float(fx.hp), reason)
	if fx.has("en"):
		add("energy", float(fx.en), reason)
	if fx.has("money"):
		add_money(int(fx.money), reason)
	if fx.has("favor"):
		add_favor(int(fx.favor))
	if fx.has("cover"):
		grant_cover(int(fx.cover), str(fx.get("cover_cat", "focus")))
	if fx.has("buff"):
		add_buff(str(fx.buff[0]), int(fx.buff[1]))
	if fx.has("flag"):
		s.flags[str(fx.flag)] = true


# ---------------------------------------------------------------------------
# Buffs
# ---------------------------------------------------------------------------

const BUFFS := {
	"jitter": {"name": "Coffee Jitters", "desc": "Move faster, lie worse (-8% on bluffs).", "good": false},
	"wired": {"name": "Dangerously Wired", "desc": "Too much coffee. -16% on bluffs. Hands visibly shaking.", "good": false},
	"jargon": {"name": "Fluent in Buzzword", "desc": "+12% on jargon and bluffs.", "good": true},
	"endorphins": {"name": "Endorphins", "desc": "Energy costs reduced by 40%.", "good": true},
	"fed": {"name": "Well Fed", "desc": "No passive energy drain.", "good": true},
	"inspired": {"name": "Daytime-TV Inspired", "desc": "+10% on your next excuse.", "good": true},
}


func add_buff(id: String, minutes: int) -> void:
	s.buffs[id] = now() + minutes
	buffs_changed.emit()


func has_buff(id: String) -> bool:
	return s.get("buffs", {}).has(id)


func remove_buff(id: String) -> void:
	if s.buffs.has(id):
		s.buffs.erase(id)
		buffs_changed.emit()


func _tick_buffs() -> void:
	var t := now()
	var changed := false
	for id in s.buffs.keys():
		if t >= int(s.buffs[id]):
			s.buffs.erase(id)
			changed = true
	if changed:
		buffs_changed.emit()


# ---------------------------------------------------------------------------
# Presence
# ---------------------------------------------------------------------------

func set_at_desk(v: bool) -> void:
	s.pres.at_desk = v
	if v:
		touch()
	_update_presence()


func touch() -> void:
	## Register genuine keyboard/mouse activity at the workstation.
	s.pres.last_input = now()


func grant_cover(minutes: int, cat: String) -> void:
	## An accepted story that explains your absence for a while.
	s.cover.until = maxi(int(s.cover.until), now() + minutes)
	s.cover.cat = cat
	_update_presence()


func covered() -> bool:
	return now() < int(s.cover.until)


func keyboard_active() -> bool:
	## True when the corporate laptop is seeing input (real or faked).
	var p: Dictionary = s.pres
	if p.at_desk:
		return true
	if now() - int(p.last_input) <= Cfg.IDLE_LIMIT:
		return true
	if now() < int(p.mug_until):
		return true
	return Auto.jiggler_running()


func is_online() -> bool:
	return Interact.internet_up()


func can_notice() -> bool:
	## Does the player get told about new messages right now?
	if s.pres.at_desk and is_online():
		return true
	return Interact.phone_usable() or Auto.owns("smartwatch")


func _update_presence() -> void:
	var p: Dictionary = s.pres
	var st := "away"
	var t := now()
	if not is_online():
		st = "offline"
	elif t < int(s.things.get("laptop_until", -1)):
		st = "updating"
	elif p.in_call:
		st = "meeting"
	elif t < int(p.focus_until):
		st = "busy"
	elif keyboard_active():
		st = "online"
	elif s.t >= 720 and s.t < 765:
		st = "lunch"
	if st != p.status:
		p.status = st
		presence_changed.emit(st)


func absent() -> bool:
	## Not visibly working and no accepted story to explain it.
	var st: String = s.pres.status
	if st == "away" or st == "offline":
		return not covered()
	return false


func _passive() -> void:
	var p: Dictionary = s.pres
	if absent():
		add("susp", Cfg.SUSP_ABSENT, "Unexplained absence")
		p.absent_run = int(p.absent_run) + 1
		p.absent_total = int(p.absent_total) + 1
		bump("absent_min")
	else:
		p.absent_run = 0
		p.nagged = false
	# Productivity illusion fades unless something feeds it.
	if not p.in_call:
		var decay: float = Cfg.ILL_DECAY_DESK if p.at_desk else Cfg.ILL_DECAY
		add("ill", -decay * (0.6 + float(s.ill) / 100.0), "")
	# Staring at SynerOS is work-adjacent, and it slowly eats your soul.
	if p.at_desk and not busy():
		add("health", -Cfg.DESK_DRAIN * float(diff().stress), "")
	var ill: float = s.ill
	if ill < 25.0:
		add("susp", Cfg.SUSP_LOW_ILL, "Nobody knows what you do here")
	elif float(s.susp) > Cfg.SUSP_FLOOR:
		if ill > 85.0:
			add("susp", -Cfg.SUSP_RELIEF_ILL * 2.0, "")
		elif ill > 60.0:
			add("susp", -Cfg.SUSP_RELIEF_ILL, "")
	if not has_buff("fed"):
		add("energy", -Cfg.EN_DECAY, "")
	if p.at_desk and s.act.is_empty():
		bump("pretend_min")


# ---------------------------------------------------------------------------
# Activities (timed, fast-forwarded things the player commits to)
# ---------------------------------------------------------------------------

func busy() -> bool:
	return active and not s.get("act", {}).is_empty()


func start_activity(a: Dictionary) -> void:
	## a: {id, label, mins, speed, anim, thing, per: {stat: per_minute}, stat: "leisure_min"}
	if busy():
		stop_activity()
	a["left"] = int(a.mins)
	a["total"] = int(a.mins)
	s.act = a
	set_speed(float(a.get("speed", 8.0)))
	Bus.activity_started.emit(a)


func stop_activity() -> void:
	## Player (or the game) interrupts the current activity.
	if not busy():
		return
	var a: Dictionary = s.act
	s.act = {}
	set_speed(1.0)
	Bus.activity_ended.emit(a, false)


func _tick_activity() -> void:
	if not busy():
		return
	var a: Dictionary = s.act
	var per: Dictionary = a.get("per", {})
	for stat in per:
		add(stat, float(per[stat]), a.get("label", ""))
	if not active or s.phase == "over":
		return
	if a.has("stat"):
		bump(str(a.stat))
		if str(a.stat) == "leisure_min" and in_work_hours():
			bump("slack_min")          # leisure on company time: the whole point
	a.left = int(a.left) - 1
	if int(a.left) <= 0:
		s.act = {}
		set_speed(1.0)
		Bus.activity_ended.emit(a, true)


# ---------------------------------------------------------------------------
# Day flow
# ---------------------------------------------------------------------------

func _end_workday() -> void:
	stop_activity()
	Corp.close_day()
	var rep := build_report()
	# The boss's end-of-day gut feeling.
	if rep.ill < 25.0:
		add("susp", 8.0, "End of day: 'What does this person DO?'")
		rep.verdict = "Todd left the office wondering what you actually do."
	elif rep.ill >= 70.0:
		add("susp", -6.0, "End of day: looks like a busy bee")
		rep.verdict = "Todd left the office convinced you're a machine."
	else:
		rep.verdict = "Todd left the office thinking about lunch, not you."
	if not active or s.phase == "over":
		return
	add_money(int(rep.salary), "Salary")
	rep.susp_end = s.susp
	s.reports.append(rep)
	s.phase = "evening"
	s.pres.in_call = false
	phase_changed.emit("evening")
	workday_ended.emit(rep)


func build_report() -> Dictionary:
	var td: Dictionary = s.today
	var salary := Cfg.SALARY_BASE
	var lines: Array = [["Base salary", Cfg.SALARY_BASE]]
	if int(td.worked_min) == 0:
		salary += Cfg.BONUS_ZERO_WORK
		lines.append(["Zero-effort efficiency bonus", Cfg.BONUS_ZERO_WORK])
	if float(s.ill) >= 70.0:
		salary += Cfg.BONUS_ILLUSION
		lines.append(["Perceived-impact bonus", Cfg.BONUS_ILLUSION])
	if float(s.susp) >= 75.0:
		salary -= 60
		lines.append(["Docked: 'attendance concerns'", -60])
	td.salary = salary
	s.week.salary = int(s.week.salary) + salary
	var runs := int(td.auto_runs)
	var eff := -1.0
	if runs > 0:
		eff = 100.0 * float(td.auto_ok) / float(runs)
	return {
		"day": int(s.day),
		"hours_employed": 8.0,
		"worked_min": int(td.worked_min),
		"pretend_min": int(td.pretend_min),
		"leisure_min": int(td.leisure_min),
		"slack_min": int(td.slack_min),
		"excuses": int(td.excuses),
		"meetings_avoided": int(td.meetings_avoided),
		"meetings_attended": int(td.meetings_attended),
		"meetings_missed": int(td.meetings_missed),
		"salary": salary,
		"salary_lines": lines,
		"susp_gained": float(td.susp_gained),
		"susp_lost": float(td.susp_lost),
		"susp": float(s.susp),
		"health": float(s.health),
		"ill": float(s.ill),
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
	if worked == 0 and float(s.ill) >= 70.0:
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
	if not active or s.phase != "evening":
		return
	stop_activity()
	var hours := clampf((1440.0 + Cfg.DAY_START - float(s.t)) / 60.0, 3.0, 10.0)
	s.day = int(s.day) + 1
	s.t = float(Cfg.DAY_START)
	s.phase = "work"
	add("energy", hours * 11.0, "Sleep")
	add("health", hours * 1.5, "Sleep")
	s.today = _blank_stats()
	s.buffs = {}
	s.cover = {"until": -1, "cat": ""}
	var p: Dictionary = s.pres
	p.at_desk = false
	p.last_input = -999
	p.mug_until = -1
	p.focus_until = -1
	p.focus_used = 0
	p.absent_run = 0
	p.in_call = false
	p.nagged = false
	_acc = 0.0
	Interact.new_day()
	Auto.new_day()
	Director.plan_day()
	_update_presence()
	buffs_changed.emit()
	phase_changed.emit("work")
	day_started.emit(int(s.day))
	SaveSys.autosave()


func finish_week() -> void:
	## Called once the Friday report has been shown.
	if active and s.phase != "over":
		end_run("win", {})


func end_run(kind: String, info: Dictionary = {}) -> void:
	if not active or s.phase == "over":
		return
	stop_activity()
	s.phase = "over"
	set_speed(1.0)
	var res := build_result(kind, info)
	s.result = res
	phase_changed.emit("over")
	run_ended.emit(res)


func build_result(kind: String, info: Dictionary) -> Dictionary:
	var wk: Dictionary = s.week
	var d := diff()
	var worked := int(wk.worked_min)
	var won := kind == "win"
	var score := 0.0
	score += float(s.money) * 1.0
	score += float(wk.salary) * 0.5
	score += float(wk.slack_min) * 2.5
	score += float(wk.leisure_min) * 0.3
	score += float(wk.meetings_avoided) * 40.0
	score += float(wk.excuses) * 10.0
	score -= float(worked) * 3.0
	if won:
		score += 600.0 + (100.0 - float(s.susp)) * 6.0
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
	return {
		"kind": kind,
		"won": won,
		"day": int(s.day),
		"time": float(s.t),
		"grade": grade,
		"score": int(round(score)),
		"reason": str(info.get("reason", "")),
		"action": str(info.get("action", "")),
		"week": wk.duplicate(true),
		"money": int(s.money),
		"susp": float(s.susp),
		"health": float(s.health),
		"ill": float(s.ill),
		"diff": str(s.diff),
		"reports": s.reports.duplicate(true),
	}


# ---------------------------------------------------------------------------
# Small helpers used across systems
# ---------------------------------------------------------------------------

func next_id(prefix: String) -> String:
	var n := int(s.next_id)
	s.next_id = n + 1
	return "%s%d" % [prefix, n]


func chance(pct: float) -> bool:
	return rng.randf() * 100.0 < pct


func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[rng.randi() % arr.size()]


func flag(id: String) -> bool:
	return bool(s.get("flags", {}).get(id, false))


func set_flag(id: String, v: Variant = true) -> void:
	s.flags[id] = v


func player_name() -> String:
	return str(s.get("player", {}).get("name", "Alex"))
