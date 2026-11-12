class_name TimeManager
extends GameSystem
## TimeManager — the simulated clock, the calendar position, time advancement
## and timers (events scheduled for a future game minute).
##
## One call to tick() is one game minute. In play, _process calls it at
## Cfg.MIN_PER_SEC x speed; tests set `manual` and call advance().

signal minute_passed()
signal phase_changed(phase: String)
signal speed_changed(speed: float)
signal timer_fired(event: String, args: Dictionary)

const LATEST_BEDTIME := 1440 + 120   ## 02:00 — you pass out

var day := 0                 ## 0 = Monday
var minute := float(Cfg.DAY_START)
var phase := "over"          ## work | evening | over
var hold := false            ## tutorial: the clock waits for the first action
var timers: Array = []       ## [{at, ev, args}]
var speed := 1.0
var manual := false          ## tests and bots drive the clock themselves
var _acc := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup_run() -> void:
	day = 0
	minute = float(Cfg.DAY_START)
	phase = "work"
	hold = false
	timers = []
	speed = 1.0
	_acc = 0.0


func save_state() -> Dictionary:
	return {"day": day, "minute": minute, "phase": phase, "hold": hold, "timers": timers}


func load_state(d: Dictionary) -> void:
	day = int(d.get("day", 0))
	minute = float(d.get("minute", Cfg.DAY_START))
	phase = str(d.get("phase", "work"))
	hold = bool(d.get("hold", false))
	timers = d.get("timers", [])
	speed = 1.0
	_acc = 0.0


# --- Reading the clock -------------------------------------------------------

func now() -> int:
	## Absolute minute since Monday 00:00.
	return day * 1440 + int(minute)


func clock() -> float:
	## Minute of the day including the sub-minute fraction (for smooth UI).
	return minute + _acc


func abs_at(on_day: int, at_minute: int) -> int:
	return on_day * 1440 + at_minute


func in_work_hours() -> bool:
	return phase == "work" and minute >= Cfg.WORK_START and minute < Cfg.WORK_END


func day_name() -> String:
	return Cfg.DAYS[clampi(day, 0, 4)]


func running() -> bool:
	return Game.active and phase != "over"


func set_phase(p: String) -> void:
	if p != phase:
		phase = p
		phase_changed.emit(p)


# --- Advancing ---------------------------------------------------------------

func _process(delta: float) -> void:
	if not running() or Game.paused or manual or hold:
		return
	_acc += delta * Cfg.MIN_PER_SEC * speed * pace()
	var guard := 0
	while _acc >= 1.0 and guard < 60:
		_acc -= 1.0
		guard += 1
		tick()
		if Game.paused or not running():
			_acc = 0.0
			break


func pace() -> float:
	## The first tutorial morning runs slower so there is time to read.
	if Game.tutor.active() and day == 0 and speed <= 1.0:
		return 0.6
	return 1.0


func advance(minutes: int) -> void:
	## Step the simulation synchronously (tests, bots, meeting time-skips).
	for i in minutes:
		if not running():
			return
		tick()


func tick() -> void:
	## One game minute.
	var before := phase
	minute += 1.0
	Game.presence.update()
	if in_work_hours():
		Game.presence.passive()
		Game.stats.passive()
	Game.activities.tick()
	Game.stats.tick_buffs()
	_fire_timers()
	if not running():
		return
	minute_passed.emit()
	if not running():
		return
	Game.after_minute(before)


func set_speed(v: float) -> void:
	if is_equal_approx(speed, v):
		return
	speed = v
	speed_changed.emit(speed)


func alert() -> void:
	## Something wants the player's attention: drop out of fast-forward.
	if speed > 1.0:
		set_speed(1.0)


# --- Timers ------------------------------------------------------------------

func schedule(abs_minute: int, event: String, args: Dictionary = {}) -> void:
	timers.append({"at": abs_minute, "ev": event, "args": args})


func pending(event: String) -> Array:
	var out: Array = []
	for e in timers:
		if str(e.ev) == event:
			out.append(e)
	return out


func _fire_timers() -> void:
	if phase != "work":
		return
	var t := now()
	var due: Array = []
	for e in timers:
		if int(e.at) <= t:
			due.append(e)
	for e in due:
		timers.erase(e)
	for e in due:
		if not running():
			return
		timer_fired.emit(str(e.ev), e.args)
