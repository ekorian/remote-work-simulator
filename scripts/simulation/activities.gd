class_name Activities
extends GameSystem
## Activities — the one timed thing the player is committed to right now
## (a nap, the console, a work session). Time fast-forwards while it runs
## and its per-minute effects are applied on every tick.

var current: Dictionary = {}     ## {id, label, mins, left, total, speed, anim, thing, per:{stat: per_minute}, stat}


func setup_run() -> void:
	current = {}


func save_state() -> Dictionary:
	return {"current": current}


func load_state(d: Dictionary) -> void:
	current = d.get("current", {})


func busy() -> bool:
	return Game.active and not current.is_empty()


func id() -> String:
	return str(current.get("id", ""))


func start(a: Dictionary) -> void:
	if busy():
		stop()
	a["left"] = int(a.mins)
	a["total"] = int(a.mins)
	current = a
	Game.time.set_speed(float(a.get("speed", 8.0)))
	Bus.activity_started.emit(a)


func stop() -> void:
	## The player (or the game) interrupts the current activity.
	if not busy():
		return
	var a := current
	current = {}
	Game.time.set_speed(1.0)
	Bus.activity_ended.emit(a, false)


func tick() -> void:
	if not busy():
		return
	var a := current
	var per: Dictionary = a.get("per", {})
	for stat in per:
		Game.stats.add(stat, float(per[stat]), str(a.get("label", "")))
	if not Game.time.running():
		return
	if a.has("stat"):
		Game.bump(str(a.stat))
		if str(a.stat) == "leisure_min" and Game.time.in_work_hours():
			Game.bump("slack_min")          # leisure on company time: the whole point
	a.left = int(a.left) - 1
	if int(a.left) <= 0:
		current = {}
		Game.time.set_speed(1.0)
		Bus.activity_ended.emit(a, true)
