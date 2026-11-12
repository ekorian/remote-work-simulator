class_name Presence
extends GameSystem
## Presence — your SynerTeams availability, and whether an absence is
## explained. "Absent" (away or offline with no accepted story) is what
## raises suspicion minute by minute.

signal changed(status: String)

var at_desk := false
var last_input := -999       ## absolute minute of the last real keyboard input
var status := "away"
var mug_until := -1          ## a mug on the spacebar fakes input until then
var focus_until := -1
var focus_used := 0
var absent_run := 0          ## consecutive unexplained minutes
var absent_total := 0
var in_call := false
var nagged := false
var cover_until := -1        ## an accepted story explains absence until then
var cover_cat := ""


func setup_run() -> void:
	at_desk = false
	last_input = -999
	status = "away"
	mug_until = -1
	focus_until = -1
	focus_used = 0
	absent_run = 0
	absent_total = 0
	in_call = false
	nagged = false
	cover_until = -1
	cover_cat = ""


func new_day() -> void:
	var total := absent_total
	setup_run()
	absent_total = total


func save_state() -> Dictionary:
	return {
		"at_desk": at_desk, "last_input": last_input, "status": status, "mug_until": mug_until,
		"focus_until": focus_until, "focus_used": focus_used, "absent_run": absent_run,
		"absent_total": absent_total, "nagged": nagged, "cover_until": cover_until, "cover_cat": cover_cat,
	}


func load_state(d: Dictionary) -> void:
	setup_run()
	for k in d:
		set(k, d[k])
	in_call = false


func set_at_desk(v: bool) -> void:
	at_desk = v
	if v:
		touch()
	update()


func touch() -> void:
	## Register genuine keyboard/mouse activity at the workstation.
	last_input = Game.time.now()


func grant_cover(minutes: int, cat: String) -> void:
	cover_until = maxi(cover_until, Game.time.now() + minutes)
	cover_cat = cat
	update()


func end_cover() -> void:
	cover_until = -1
	update()


func covered() -> bool:
	return Game.time.now() < cover_until


func keyboard_active() -> bool:
	## True when the corporate laptop is seeing input (real or faked).
	if at_desk:
		return true
	var t := Game.time.now()
	if t - last_input <= Cfg.IDLE_LIMIT:
		return true
	if t < mug_until:
		return true
	return Game.automation.jiggler_running()


func is_online() -> bool:
	return Game.home.internet_up()


func can_notice() -> bool:
	## Does the player get told about new messages right now?
	if at_desk and is_online():
		return true
	return Game.home.phone_usable()


func update() -> void:
	if not Game.active:
		return
	var st := "away"
	var t := Game.time.now()
	var m := Game.time.minute
	if not is_online():
		st = "offline"
	elif Game.home.laptop_updating():
		st = "updating"
	elif in_call:
		st = "meeting"
	elif t < focus_until:
		st = "busy"
	elif keyboard_active():
		st = "online"
	elif m >= 720 and m < 765:
		st = "lunch"
	if st != status:
		status = st
		changed.emit(st)


func absent() -> bool:
	## Not visibly working and no accepted story to explain it.
	if status == "away" or status == "offline":
		return not covered()
	return false


func passive() -> void:
	## Per-minute consequences during work hours.
	if absent():
		Game.stats.add("susp", Cfg.SUSP_ABSENT, "Unexplained absence")
		absent_run += 1
		absent_total += 1
		Game.bump("absent_min")
	else:
		absent_run = 0
		nagged = false
	if at_desk and not Game.activities.busy():
		Game.bump("pretend_min")
