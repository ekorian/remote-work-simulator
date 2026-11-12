class_name AutomationManager
extends GameSystem
## AutomationManager — gadgets, their upgrade levels, reliability, wear,
## detection heat, failures and combinations.
##
## The system is ability-driven: a gadget level lists what it `can` do
## ("presence", "auto_reply", "attend_meetings"...) and the rest of the
## game asks `can("presence")` or `provider("auto_reply")`. No gadget is
## ever referred to by name in code, so a new one is a new resource file.

const BRIBE_PRICE := 45
const REPORT_TIMES := [-1, 600, 780, 990]   ## off, 10:00, 13:00, 16:30
const SERVICE_WEAR := 15.0

var gadgets: Dictionary = {}     ## id -> {level, on, wear, broken, runs}
var autos: Dictionary = {}       ## scheduling state for timed automation


func _ready() -> void:
	Game.time.minute_passed.connect(_on_minute)


func setup_run() -> void:
	Db.load_all()
	gadgets = {}
	for id in Db.gadgets:
		gadgets[id] = {"level": 0, "on": false, "wear": 0.0, "broken": false, "runs": 0}
	autos = {"report_at": -1, "report_sent": false, "ai_task": "", "ai_left": 0, "update_at": -1, "chaos_day": -1}


func new_day() -> void:
	autos.report_sent = false
	autos.update_at = -1


func save_state() -> Dictionary:
	return {"gadgets": gadgets, "autos": autos}


func load_state(d: Dictionary) -> void:
	setup_run()
	var saved: Dictionary = d.get("gadgets", {})
	for id in saved:
		if gadgets.has(id):
			gadgets[id] = saved[id]
	for k in d.get("autos", {}):
		autos[k] = d.autos[k]


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

func def(id: String) -> Dictionary:
	return Db.gadgets.get(id, {})


func g(id: String) -> Dictionary:
	return gadgets.get(id, {})


func level(id: String) -> int:
	return int(g(id).get("level", 0))


func max_level(id: String) -> int:
	return def(id).get("levels", []).size()


func owns(id: String) -> bool:
	return Game.active and level(id) > 0


func data(id: String, at_level: int = -1) -> Dictionary:
	## The definition of the level this gadget is at (or of `at_level`).
	var lv := level(id) if at_level < 0 else at_level
	var levels: Array = def(id).get("levels", [])
	if lv < 1 or lv > levels.size():
		return {}
	return levels[lv - 1]


func is_on(id: String) -> bool:
	return owns(id) and bool(g(id).on)


func working(id: String) -> bool:
	if not owns(id):
		return false
	var st := g(id)
	var d := def(id)
	if bool(st.broken):
		return false
	if str(d.kind) != "passive" and not bool(st.on):
		return false
	if bool(d.needs_net) and not Game.home.internet_up():
		return false
	return true


func abilities(id: String) -> Array:
	return data(id).get("can", [])


func provider(ability: String) -> String:
	## The working gadget that provides an ability ("" if none).
	for id in gadgets:
		if working(id) and ability in abilities(id):
			return id
	return ""


func can(ability: String) -> bool:
	return provider(ability) != ""


func has(ability: String) -> bool:
	## Do you own a gadget with this ability (running or not)?
	for id in gadgets:
		if owns(id) and ability in abilities(id):
			return true
	return false


func owner_of(ability: String) -> String:
	## Display name of the gadget that would provide an ability (for hints).
	for id in Db.gadget_order():
		for lv in def(id).levels:
			if ability in lv.get("can", []):
				return str(def(id).display_name)
	return "a gadget"


func param(ability: String, key: String, fallback: float = 0.0) -> float:
	var id := provider(ability)
	if id == "":
		return fallback
	return float(data(id).get(key, fallback))


func jiggler_running() -> bool:
	return can("presence")


func unlocked(id: String) -> bool:
	return locked_reason(id) == ""


func locked_reason(id: String) -> String:
	var d := def(id)
	if Game.time.day < int(d.unlock_day):
		return "Ships %s" % Cfg.DAYS[int(d.unlock_day)]
	for other in d.get("requires", {}):
		if level(str(other)) < int(d.requires[other]):
			return "Needs %s (level %d)" % [str(def(str(other)).display_name), int(d.requires[other])]
	return ""


func price(id: String, at_level: int = -1) -> int:
	## Price of buying (level 1) or upgrading to `at_level`.
	var lv := level(id) + 1 if at_level < 0 else at_level
	var d := data(id, lv)
	if d.is_empty():
		return 0
	return Game.economy.price(int(d.price))


func can_upgrade(id: String) -> bool:
	return owns(id) and level(id) < max_level(id)


# --- Reliability, wear and heat ---------------------------------------------

func reliability(id: String) -> float:
	return float(data(id).get("reliability", 100.0))


func fail_chance(id: String) -> float:
	## Percent chance it fails on its next use (or next half hour, if it runs
	## continuously). Driven by wear: service them and they behave.
	if not owns(id):
		return 0.0
	var w := float(g(id).wear) / 40.0
	var factor := clampf(w * w, 0.04, 6.0) if str(def(id).kind) == "always" else 0.5 + w
	var base := 100.0 - reliability(id)
	base *= 1.0 + effect("fail", 0.0) / 100.0
	return clampf(base * factor * float(Game.diff().gadget_fail), 0.0, 90.0)


func heat() -> float:
	## How suspicious your machine looks to a SynerWatch scan (0..100).
	var h := 0.0
	for id in gadgets:
		if working(id):
			h += float(data(id).get("heat", 0.0))
	if Game.time.now() < Game.presence.mug_until:
		h += 10.0
	h += effect("heat", 0.0)
	return clampf(h, 0.0, 100.0)


func hottest() -> String:
	var best := ""
	var top := -1.0
	for id in gadgets:
		if working(id) and float(data(id).get("heat", 0.0)) > top:
			top = float(data(id).heat)
			best = id
	return best


func any_broken() -> bool:
	for id in gadgets:
		if owns(id) and bool(g(id).broken):
			return true
	return false


func max_wear() -> float:
	var w := 0.0
	for id in gadgets:
		if owns(id) and str(def(id).kind) != "passive":
			w = maxf(w, float(g(id).wear))
	return w


# --- Combinations ------------------------------------------------------------

func combos_active() -> Array:
	var out: Array = []
	for cid in Db.combos:
		var c: Dictionary = Db.combos[cid]
		var ok := true
		for need in c.needs:
			if not working(str(need)):
				ok = false
				break
		if ok:
			out.append(c)
	return out


func combo_ready(cid: String) -> bool:
	for c in combos_active():
		if str(c.id) == cid:
			return true
	return false


func effect(key: String, fallback: float = 0.0) -> float:
	## Sum of a named modifier across every active combination.
	var total := fallback
	for c in combos_active():
		if c.effects.has(key):
			total += float(c.effects[key])
	return total


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

func buy(id: String) -> bool:
	## Buy a gadget, or upgrade one you own to its next level.
	if not gadgets.has(id) or level(id) >= max_level(id):
		return false
	var why := locked_reason(id)
	if why != "":
		Bus.toast.emit("%s." % why, "warn")
		return false
	var cost := price(id)
	if not Game.economy.can_afford(cost):
		Bus.toast.emit("You can't afford that. Payday is at 17:00.", "warn")
		return false
	var d := def(id)
	var st := g(id)
	var upgrade := int(st.level) > 0
	Game.economy.add_money(-cost, "%s%s" % [str(d.display_name), " upgrade" if upgrade else ""])
	st.level = int(st.level) + 1
	st.broken = false
	st.wear = 0.0
	if not upgrade:
		st.on = str(d.kind) == "passive"
	Bus.sfx.emit("buy")
	if upgrade:
		Bus.toast.emit("%s upgraded to level %d: %s" % [str(d.display_name), int(st.level), str(data(id).text)], "money")
	elif str(d.kind) == "passive":
		Bus.toast.emit("Bought: %s. Always on." % str(d.display_name), "money")
	else:
		Bus.toast.emit("Bought: %s. Switch it on at your keyboard, or in ShadowIT." % str(d.display_name), "money")
	Game.presence.update()
	Bus.gadget_changed.emit(id)
	return true


func toggle(id: String) -> bool:
	if not owns(id) or str(def(id).kind) == "passive":
		return false
	if bool(g(id).broken):
		Bus.toast.emit("It's broken. Service your gadgets first.", "warn")
		return false
	if not Game.work.perform("toggle_gadget", {"gadget": id}):
		return false
	flip(id)
	return true


func flip(id: String) -> void:
	## Switch a gadget without charging for the action (the caller already did).
	var st := g(id)
	if not owns(id) or bool(st.broken):
		return
	st.on = not bool(st.on)
	Bus.sfx.emit("gadget_on" if bool(st.on) else "switch")
	Game.presence.update()
	Bus.gadget_changed.emit(id)


func maintain() -> bool:
	## Service every gadget: resets wear and repairs breakage.
	if not Game.work.perform("maintain", {}):
		return false
	service()
	return true


func service() -> void:
	for id in gadgets:
		if owns(id):
			g(id).wear = 0.0
			g(id).broken = false
	Bus.toast.emit("Gadgets oiled, rebooted and threatened. Good as new.", "good")
	Game.presence.update()
	Bus.gadget_changed.emit("")


func use(id: String) -> bool:
	## One use of a gadget: rolls its reliability and adds wear.
	if not working(id):
		return false
	var st := g(id)
	st.runs = int(st.runs) + 1
	Game.bump("auto_runs")
	var failed := Game.chance(fail_chance(id))
	st.wear = minf(100.0, float(st.wear) + (12.0 if Game.flag("strain") else 8.0))
	if failed:
		fail(id)
		return false
	Game.bump("auto_ok")
	Bus.gadget_changed.emit(id)
	return true


func use_ability(ability: String) -> bool:
	var id := provider(ability)
	return id != "" and use(id)


func fail(id: String, by_scan: bool = false) -> void:
	## The gadget breaks. Its failure event decides what the fallout is.
	var st := g(id)
	var d := def(id)
	st.broken = true
	st.on = false
	Game.stats.add("ill", -3.0, "%s failed" % str(d.display_name))
	Bus.toast.emit(str(d.fail_text) if not by_scan else "SynerWatch disabled your %s." % str(d.display_name), "bad")
	Bus.sfx.emit("gadget_fail")
	Game.time.alert()
	Game.presence.update()
	Bus.gadget_changed.emit(id)
	if str(d.fail_event) != "" and not by_scan:
		Game.events.fire(str(d.fail_event), {"gadget": id})


func set_report_time(minute: int) -> void:
	autos.report_at = minute
	Bus.gadget_changed.emit("")


func assign_ai(task_id: String) -> void:
	autos.ai_task = task_id
	autos.ai_left = 40
	Bus.gadget_changed.emit("")


func can_bribe() -> bool:
	return Game.active and not Game.flag("bribe_day_%d" % Game.time.day)


func bribe() -> bool:
	## A gift card "for the team". One favour per day, for cash.
	if not can_bribe():
		Bus.toast.emit("One suspiciously generous gift card per day is the limit.", "warn")
		return false
	var cost := Game.economy.price(BRIBE_PRICE)
	if not Game.economy.can_afford(cost):
		Bus.toast.emit("You can't afford that. Payday is at 17:00.", "warn")
		return false
	if not Game.work.perform("flatter", {"label": "Gift card for a colleague"}):
		return false
	Game.set_flag("bribe_day_%d" % Game.time.day)
	Game.economy.add_money(-cost, "Gift card")
	Game.economy.add_favor(1)
	Game.npcs.adjust("dave", 6.0)
	Bus.sfx.emit("buy")
	Bus.toast.emit("Dave got a gift card. Dave now owes you one.", "money")
	return true


# ---------------------------------------------------------------------------
# Autonomous behaviour
# ---------------------------------------------------------------------------

func try_attend(m: Dictionary) -> bool:
	## A clone that can attend meetings takes this one, if it is allowed to.
	if bool(m.get("no_dodge", false)) or not can("attend_meetings"):
		return false
	if bool(m.get("mandatory", false)) and effect("attend_mandatory", 0.0) <= 0.0:
		return false
	var id := provider("attend_meetings")
	if not use(id):
		return false
	Game.deception.observe("video_meeting")
	maybe_chaos("meeting")
	return true


func maybe_chaos(source: String) -> void:
	## An autonomous clone occasionally decides things on your behalf.
	var id := provider("autonomous")
	if id == "" or int(autos.chaos_day) == Game.time.day:
		return
	var pct := float(data(id).get("chaos", 0.0)) * (1.0 + effect("chaos", 0.0) / 100.0) * float(Game.diff().gadget_fail)
	if Game.chance(pct):
		autos.chaos_day = Game.time.day
		Game.events.fire("doppel_decision", {"gadget": id, "source": source})


func _on_minute() -> void:
	if not Game.time.in_work_hours():
		return
	var t := Game.time.now()
	# Continuous gadgets wear out and are rolled every half hour.
	for id in gadgets:
		if str(def(id).get("kind", "")) != "always" or not working(id):
			continue
		var st := g(id)
		st.wear = minf(100.0, float(st.wear) + (0.34 if Game.flag("strain") else 0.2))
		if t % 30 == 0:
			Game.bump("auto_runs")
			if Game.chance(fail_chance(id)):
				fail(id)
				continue
			Game.bump("auto_ok")
	if can("illusion"):
		Game.stats.add("ill", param("illusion", "ill", 0.08), "")
	# Scheduled status report.
	if int(autos.report_at) > 0 and not bool(autos.report_sent) and int(Game.time.minute) >= int(autos.report_at) and can("auto_report"):
		autos.report_sent = true
		if use_ability("auto_report"):
			Game.work.fake_report(true)
	# Fictional ticket updates.
	if can("auto_updates"):
		if int(autos.update_at) < 0:
			autos.update_at = t + int(param("auto_updates", "update_every", 90.0))
		elif t >= int(autos.update_at):
			autos.update_at = t + int(param("auto_updates", "update_every", 90.0))
			for task in Game.work.open_tasks():
				if str(task.by) == "" and not Game.work.task_looks_done(task):
					if use_ability("auto_updates"):
						Game.work.task_fake(str(task.id), true)
					break
	# A clone that does tickets.
	if str(autos.ai_task) != "" and can("do_tickets"):
		var task := Game.work.task(str(autos.ai_task))
		if task.is_empty() or str(task.status) != "open":
			autos.ai_task = ""
		else:
			autos.ai_left = int(autos.ai_left) - 1
			if int(autos.ai_left) <= 0:
				autos.ai_left = 40
				Game.work.task_progress(str(autos.ai_task), 1, 0.06, provider("do_tickets"))
				if str(Game.work.task(str(autos.ai_task)).get("status", "")) != "open":
					Bus.toast.emit("Your clone finished %s. You did nothing. Beautiful." % str(task.key), "good")
					autos.ai_task = ""
					maybe_chaos("ticket")
				Bus.gadget_changed.emit("")
