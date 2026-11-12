class_name PlayerStats
extends GameSystem
## PlayerStats — health, energy, suspicion and productivity illusion, plus
## the temporary modifiers (buffs) that act on them.
##
## add() is the single write path: it applies difficulty multipliers and
## buff modifiers, clamps to 0..100, records statistics, emits `changed`,
## and ends the run at 0 health or 100 suspicion.

signal changed(stat: String, value: float, delta: float, reason: String)
signal buffs_changed()

const STATS := ["health", "energy", "susp", "ill"]
const STAT_NAMES := {"health": "Health", "energy": "Energy", "susp": "Suspicion", "ill": "Productivity Illusion"}
const MIN := 0.0
const MAX := 100.0

const BUFFS := {
	"jitter": {"name": "Coffee Jitters", "desc": "Move faster, lie worse (-8% on bluffs).", "good": false},
	"wired": {"name": "Dangerously Wired", "desc": "Too much coffee. -16% on bluffs. Hands visibly shaking.", "good": false},
	"jargon": {"name": "Fluent in Buzzword", "desc": "+12% on jargon and bluffs.", "good": true},
	"endorphins": {"name": "Endorphins", "desc": "Energy costs reduced by 40%.", "good": true},
	"fed": {"name": "Well Fed", "desc": "No passive energy drain.", "good": true},
	"inspired": {"name": "Daytime-TV Inspired", "desc": "+10% on your next excuse.", "good": true},
}

var values := {"health": 100.0, "energy": 90.0, "susp": 8.0, "ill": 45.0}
var buffs: Dictionary = {}       ## id -> absolute minute it expires


func setup_run() -> void:
	values = {"health": 100.0, "energy": 90.0, "susp": 8.0, "ill": 45.0}
	buffs = {}


func new_day() -> void:
	buffs = {}
	buffs_changed.emit()


func save_state() -> Dictionary:
	return {"values": values, "buffs": buffs}


func load_state(d: Dictionary) -> void:
	values = d.get("values", values)
	buffs = d.get("buffs", {})


func get_value(stat: String) -> float:
	return float(values.get(stat, 0.0))


func add(stat: String, delta: float, reason: String = "") -> float:
	## Apply a change to one resource. Returns the delta actually applied.
	if not Game.time.running() or is_zero_approx(delta) or not values.has(stat):
		return 0.0
	var d := Game.diff()
	if stat == "susp" and delta > 0.0:
		delta *= float(d.susp)
	elif (stat == "health" or stat == "energy") and delta > 0.0:
		delta *= float(d.recover)
	elif stat == "energy" and delta < 0.0 and has_buff("endorphins"):
		delta *= 0.6
	elif stat == "ill" and delta > 0.0:
		# The more impressive you already look, the harder it is to look more so.
		delta *= clampf(1.3 - float(values.ill) / 100.0, 0.35, 1.0)
	var before: float = values[stat]
	var after: float = clampf(before + delta, MIN, MAX)
	var applied := after - before
	values[stat] = after
	if stat == "susp":
		if applied > 0.0:
			Game.bump("susp_gained", applied)
		else:
			Game.bump("susp_lost", -applied)
	if not is_zero_approx(applied):
		changed.emit(stat, after, applied, reason)
	if stat == "health" and after <= MIN:
		Game.end_run("burnout", {"reason": reason})
	elif stat == "susp" and after >= MAX:
		Game.end_run("fired", {"reason": reason})
	return applied


func passive() -> void:
	## Per-minute drift during work hours.
	var p := Game.presence
	# Productivity illusion fades unless something feeds it.
	if not p.in_call:
		var decay: float = Cfg.ILL_DECAY_DESK if p.at_desk else Cfg.ILL_DECAY
		add("ill", -decay * (0.6 + float(values.ill) / 100.0), "")
	# Staring at SynerOS is work-adjacent, and it slowly eats your soul.
	if p.at_desk and not Game.activities.busy():
		add("health", -Cfg.DESK_DRAIN * float(Game.diff().stress), "")
	var ill: float = values.ill
	if ill < 25.0:
		add("susp", Cfg.SUSP_LOW_ILL, "Nobody knows what you do here")
	elif float(values.susp) > Cfg.SUSP_FLOOR:
		if ill > 85.0:
			add("susp", -Cfg.SUSP_RELIEF_ILL * 2.0, "")
		elif ill > 60.0:
			add("susp", -Cfg.SUSP_RELIEF_ILL, "")
	if not has_buff("fed"):
		add("energy", -Cfg.EN_DECAY, "")


# --- Modifiers ---------------------------------------------------------------

func add_buff(id: String, minutes: int) -> void:
	buffs[id] = Game.time.now() + minutes
	buffs_changed.emit()


func has_buff(id: String) -> bool:
	return buffs.has(id)


func remove_buff(id: String) -> void:
	if buffs.has(id):
		buffs.erase(id)
		buffs_changed.emit()


func tick_buffs() -> void:
	var t := Game.time.now()
	var gone := false
	for id in buffs.keys():
		if t >= int(buffs[id]):
			buffs.erase(id)
			gone = true
	if gone:
		buffs_changed.emit()
