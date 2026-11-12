class_name Home
extends GameSystem
## Home — what every object in the apartment does, and the state of the flat
## (router, laptop, phone, fridge stock, what you are wearing).
##
## The 3D world only knows object ids. It asks `options(id)` what can be done
## and calls `use(id, option)`. All rules, stock and side effects live here,
## so headless tests and bots can use the apartment without any scene.

const THINGS := {
	"workstation": {"name": "Work Computer", "room": "Home office"},
	"keyboard": {"name": "Keyboard & Mouse", "room": "Home office"},
	"mug": {"name": "Coffee Mug", "room": "Home office"},
	"laptop": {"name": "Company Laptop", "room": "Home office"},
	"chair": {"name": "Office Chair", "room": "Home office"},
	"gaming_pc": {"name": "Gaming PC", "room": "Home office"},
	"printer": {"name": "Printer", "room": "Home office"},
	"router": {"name": "Router", "room": "Home office"},
	"sofa": {"name": "Sofa", "room": "Living room"},
	"tv": {"name": "Television", "room": "Living room"},
	"console": {"name": "Gaming Console", "room": "Living room"},
	"bookshelf": {"name": "Bookshelf", "room": "Living room"},
	"exercise": {"name": "Exercise Bike", "room": "Living room"},
	"fridge": {"name": "Refrigerator", "room": "Kitchen"},
	"coffee": {"name": "Coffee Machine", "room": "Kitchen"},
	"microwave": {"name": "Microwave", "room": "Kitchen"},
	"table": {"name": "Kitchen Table", "room": "Kitchen"},
	"bed": {"name": "Bed", "room": "Bedroom"},
	"wardrobe": {"name": "Wardrobe", "room": "Bedroom"},
	"charger": {"name": "Phone Charger", "room": "Bedroom"},
}

## Timed activities. `per` is applied every game minute while it runs.
const TIMED := {
	"desk_nap": {"thing": "chair", "label": "Nap in the chair", "mins": 20, "speed": 6.0, "anim": "sit_sleep", "per": {"energy": 0.6, "health": 0.15}},
	"lounge": {"thing": "sofa", "label": "Lounge on the sofa", "mins": 30, "speed": 8.0, "anim": "lounge", "per": {"energy": 0.55, "health": 0.27}},
	"tv": {"thing": "tv", "label": "Watch daytime TV", "mins": 40, "speed": 8.0, "anim": "lounge", "per": {"health": 0.35, "energy": 0.15}},
	"console": {"thing": "console", "label": "Play video games", "mins": 45, "speed": 8.0, "anim": "game", "per": {"health": 0.55, "energy": -0.08}},
	"study": {"thing": "bookshelf", "label": "Study the Buzzword Dictionary", "mins": 20, "speed": 6.0, "anim": "read", "per": {"energy": -0.1}},
	"workout": {"thing": "exercise", "label": "Ride the exercise bike", "mins": 20, "speed": 6.0, "anim": "workout", "per": {"energy": -0.7, "health": 0.6}},
	"snack": {"thing": "fridge", "label": "Grab a snack", "mins": 4, "speed": 2.0, "anim": "eat", "per": {"energy": 3.5, "health": 1.0}},
	"brew": {"thing": "coffee", "label": "Brew a coffee", "mins": 5, "speed": 2.5, "anim": "drink", "per": {"energy": 5.6}},
	"burrito": {"thing": "microwave", "label": "Microwave a burrito", "mins": 8, "speed": 3.0, "anim": "eat", "per": {"energy": 3.25, "health": 0.6}},
	"lunch": {"thing": "table", "label": "Sit down for a proper lunch", "mins": 30, "speed": 6.0, "anim": "sit_eat", "per": {"energy": 1.0, "health": 0.4}},
	"nap": {"thing": "bed", "label": "Take a long nap", "mins": 60, "speed": 10.0, "anim": "sleep", "per": {"energy": 0.67, "health": 0.3}},
	"power_nap": {"thing": "bed", "label": "Power nap", "mins": 25, "speed": 8.0, "anim": "sleep", "per": {"energy": 0.72, "health": 0.3}},
	"forge": {"thing": "printer", "label": "Forge a doctor's note", "mins": 6, "speed": 2.5, "anim": "use", "per": {}},
}

const OUTFITS := {
	"casual": {"label": "Hoodie and jeans", "hint": "Neutral on camera."},
	"shirt": {"label": "Business on top, pajamas below", "hint": "+9% on video-call bluffs."},
	"pajamas": {"label": "Full pajamas", "hint": "+20% health from leisure. -10% on video-call bluffs."},
}


var things: Dictionary = {}      ## state of the objects in the flat
var outfit := "casual"


func _ready() -> void:
	Game.time.minute_passed.connect(_on_minute)
	Bus.activity_ended.connect(_on_activity_ended)


func save_state() -> Dictionary:
	return {"things": things, "outfit": outfit}


func load_state(d: Dictionary) -> void:
	setup_run()
	for k in d.get("things", {}):
		things[k] = d.things[k]
	outfit = str(d.get("outfit", "casual"))


func setup_run() -> void:
	outfit = "casual"
	things = {
		"router_on": true, "router_cuts": 0, "router_off_at": -1,
		"laptop_until": -1, "laptop_updates": 0,
		"phone_bat": 85.0, "phone_docked": false,
		"notes": 0, "ink": 3, "jam": false,
		"mug": 1, "coffees": 0, "mug_wedges": 0,
		"snacks": 3, "burritos": 2, "lunch": false,
		"staged_until": -1, "wiggle_at": -99, "outage_until": -1,
	}


func new_day() -> void:
	var th: Dictionary = things
	th.router_on = true
	th.router_cuts = 0
	th.laptop_until = -1
	th.laptop_updates = 0
	th.coffees = 0
	th.mug_wedges = 0
	th.snacks = 3
	th.burritos = 2
	th.lunch = false
	th.staged_until = -1
	th.outage_until = -1
	th.jam = false
	th.ink = mini(3, int(th.ink) + 1)
	if bool(th.phone_docked):
		th.phone_bat = 100.0


# --- State queries -----------------------------------------------------------

func router_on() -> bool:
	return bool(things.get("router_on", true))


func outage() -> bool:
	## The provider is down (nothing to do with your router).
	return Game.time.now() < int(things.get("outage_until", -1))


func internet_up() -> bool:
	return router_on() and not outage()


func start_outage(minutes: int) -> void:
	things.outage_until = Game.time.now() + minutes
	Game.presence.update()
	Bus.thing_changed.emit("router")


func laptop_updating() -> bool:
	return Game.time.now() < int(things.get("laptop_until", -1))


func desk_staged() -> bool:
	return Game.time.now() < int(things.get("staged_until", -1))


func phone_carried() -> bool:
	return not bool(things.get("phone_docked", false))


func phone_usable() -> bool:
	return phone_carried() and float(things.get("phone_bat", 0.0)) >= 5.0 and internet_or_mobile()


func internet_or_mobile() -> bool:
	return true   # the phone has mobile data; the router does not matter


func phone_spend(pct: float) -> void:
	var th: Dictionary = things
	th.phone_bat = maxf(0.0, float(th.phone_bat) - pct)
	Bus.thing_changed.emit("charger")


# --- Options ----------------------------------------------------------------

func _opt(id: String, label: String, act: String, hint: String = "", ok: bool = true, why: String = "") -> Dictionary:
	var check := Game.work.can(act)
	if ok and not check.ok:
		ok = false
		why = check.why
	return {"id": id, "label": label, "act": act, "hint": hint, "ok": ok, "why": why}


func _timed_hint(key: String) -> String:
	var a: Dictionary = TIMED[key]
	var parts: Array = []
	var rec := float(Game.diff().recover) if Game.active else 1.0
	for stat in a.per:
		var total := float(a.per[stat]) * float(a.mins)
		if total > 0.0:
			total *= rec
		if absf(total) >= 1.0:
			parts.append("%+d %s" % [int(round(total)), "Energy" if stat == "energy" else "Health"])
	parts.append(Cfg.fmt_dur(a.mins))
	return ", ".join(parts)


func _timed(key: String, extra_hint: String = "", ok: bool = true, why: String = "") -> Dictionary:
	var a: Dictionary = TIMED[key]
	var hint := _timed_hint(key)
	if extra_hint != "":
		hint += ". " + extra_hint
	return _opt(key, a.label, "forge_note" if key == "forge" else "leisure", hint, ok, why)


func options(thing: String) -> Array:
	if not Game.active:
		return []
	var th: Dictionary = things
	var evening: bool = Game.time.phase == "evening"
	var out: Array = []
	match thing:
		"workstation":
			out.append(_opt("open", "Log in to SynerOS", "use", "Messages, tasks, calendar, mail and your gadgets."))
		"keyboard":
			out.append(_opt("wiggle", "Wiggle the mouse", "use", "Shows you as Available for %d min." % Cfg.IDLE_LIMIT))
			for gid in Db.gadget_order():
				if Game.automation.owns(gid) and str(Game.automation.def(gid).kind) != "passive":
					var gs := Game.automation.g(gid)
					var gname := str(Game.automation.def(gid).display_name)
					out.append(_opt("flip_" + gid, "%s: switch %s" % [gname, "OFF" if bool(gs.on) else "ON"], "toggle_gadget", str(Game.automation.data(gid).text), not bool(gs.broken), "Broken. Service your gadgets."))
			if Game.automation.any_broken() or Game.automation.max_wear() >= 15.0:
				out.append(_opt("service", "Service all gadgets", "maintain", "Repairs breakage and resets wear (worn gadgets fail more). Worst wear: %d%%." % int(Game.automation.max_wear())))
		"mug":
			out.append(_opt("sip", "Sip the leftover coffee", "use", "+7 Energy. %d sip(s) left." % int(th.mug), int(th.mug) > 0, "The mug is empty. Brew a coffee to refill it."))
			out.append(_opt("wedge", "Wedge the mug on the spacebar", "wedge_mug", "Fakes typing for 25 min. Gets riskier each time today.", not evening, "Nobody is watching in the evening."))
		"laptop":
			var up := laptop_updating()
			out.append(_opt("update", "Force a system update", "force_update", "30 min of 'Updating...' status: nobody expects you online. Suspicious if repeated today.", not up and not evening, "Already updating." if up else "Nobody is watching in the evening."))
		"chair":
			out.append(_opt("stage", "Stage a busy-looking desk", "stage_desk", "Sticky notes, three open spreadsheets. +6% on video bluffs for 2h, +3 Illusion.", not desk_staged(), "The desk already looks frantic."))
			out.append(_timed("desk_nap", "You stay near the keyboard."))
		"gaming_pc":
			out.append(_opt("shop", "Browse ShadyDeals.biz", "use", "Buy gadgets and automation with your salary."))
		"printer":
			if bool(th.jam):
				out.append(_opt("fix", "Clear the paper jam", "fix_printer", "PC LOAD LETTER. Costs energy."))
			else:
				out.append(_timed("forge", "Evidence for the food-poisoning excuse. %d ink left." % int(th.ink), int(th.ink) > 0, "Out of ink until tomorrow."))
		"router":
			if router_on():
				out.append(_opt("off", "Pull the plug", "cut_router", "A REAL outage: evidence for outage excuses. You go Offline and gadgets that need internet stop."))
			else:
				out.append(_opt("on", "Plug it back in", "use", "Back online in a blink."))
		"sofa":
			out.append(_timed("lounge"))
		"tv":
			out.append(_timed("tv", "Might inspire your next excuse."))
		"console":
			out.append(_timed("console"))
		"bookshelf":
			out.append(_timed("study", "Fluent in Buzzword for 3h: +12% on jargon."))
		"exercise":
			out.append(_timed("workout", "Clears coffee jitters. Energy costs -40% for 2.5h."))
		"fridge":
			out.append(_timed("snack", "%d left today." % int(th.snacks), int(th.snacks) > 0, "The fridge is empty until tomorrow."))
		"coffee":
			out.append(_timed("brew", "Refills your desk mug. Too many cause jitters."))
		"microwave":
			out.append(_timed("burrito", "No passive energy drain for 2h. %d left." % int(th.burritos), int(th.burritos) > 0, "No burritos left today."))
		"table":
			out.append(_timed("lunch", "Well Fed for 3h. Once a day.", not bool(th.lunch), "You already had lunch today."))
		"bed":
			if evening:
				out.append(_opt("sleep", "Sleep until morning", "use", "Ends the day. More hours of sleep restore more Energy and Health."))
			else:
				out.append(_timed("nap"))
				out.append(_timed("power_nap"))
		"wardrobe":
			for oid in OUTFITS:
				var o: Dictionary = OUTFITS[oid]
				var cur: bool = str(outfit) == oid
				out.append(_opt("wear_" + oid, o.label, "use", o.hint, not cur, "You're wearing this."))
		"charger":
			if phone_carried():
				out.append(_opt("dock", "Put the phone on the charger", "use", "Charges fast, but you can't answer from the phone. Battery %d%%." % int(th.phone_bat)))
			else:
				out.append(_opt("take", "Take the phone", "use", "Answer chats and calls from anywhere. Battery %d%%." % int(th.phone_bat)))
	return out


func use(thing: String, opt_id: String) -> bool:
	## Perform an option. Returns true if something happened.
	var found: Dictionary = {}
	for o in options(thing):
		if o.id == opt_id:
			found = o
			break
	if found.is_empty():
		return false
	if not found.ok:
		Bus.toast.emit(str(found.why), "warn")
		return false
	if not Game.work.perform(str(found.act), {"label": found.label, "thing": thing}):
		return false
	var th: Dictionary = things
	if TIMED.has(opt_id):
		_start_timed(opt_id)
		return true
	match opt_id:
		"open":
			Bus.request_desktop.emit("")
		"shop":
			Bus.request_shop.emit()
		"wiggle":
			Game.presence.touch()
			if Game.time.now() - int(th.wiggle_at) >= 10 and Game.time.in_work_hours():
				th.wiggle_at = Game.time.now()
				Game.stats.add("ill", 1.0, "Mouse wiggle")
			Bus.sfx.emit("click")
		"sip":
			th.mug = int(th.mug) - 1
			Game.stats.add("energy", 7.0, "Cold coffee")
			Bus.sfx.emit("sip")
		"wedge":
			th.mug_wedges = int(th.mug_wedges) + 1
			Game.presence.mug_until = Game.time.now() + 25
			Game.bump("auto_runs")
			var risk := 12.0 * float(th.mug_wedges) * float(Game.diff().gadget_fail)
			if Game.chance(risk):
				Game.presence.mug_until = Game.time.now() + 6
				Game.stats.add("susp", 6.0, "The spacebar incident")
				Game.comms.say(Game.npcs.boss_id(), "Why did you just send 4,000 spaces to #general?")
				Game.deception.observe("social_post")
				Bus.toast.emit("The mug slipped. You spammed #general with spaces.", "bad")
			else:
				Game.bump("auto_ok")
				Bus.toast.emit("Mug wedged. The laptop thinks you're typing furiously.", "good")
		"update":
			th.laptop_updates = int(th.laptop_updates) + 1
			th.laptop_until = Game.time.now() + 30
			if int(th.laptop_updates) > 1:
				Game.stats.add("susp", 6.0, "Second 'update' today")
				Bus.toast.emit("Two updates in one day. IT raised an eyebrow.", "warn")
			else:
				Bus.toast.emit("Installing update 1 of 114... You're excused for 30 min.", "good")
		"stage":
			th.staged_until = Game.time.now() + 120
			Game.stats.add("ill", 3.0, "Staged desk")
			Bus.toast.emit("The desk now looks like a crime board. Convincing.", "good")
		"service":
			Game.automation.service()
		"fix":
			th.jam = false
			Bus.toast.emit("Jam cleared. The printer resents you.", "info")
		"off":
			th.router_on = false
			th.router_cuts = int(th.router_cuts) + 1
			th.router_off_at = Game.time.now()
			Bus.sfx.emit("unplug")
			Bus.toast.emit("Router unplugged. You are genuinely offline.", "warn")
		"on":
			th.router_on = true
			Bus.sfx.emit("plug")
			Bus.toast.emit("Router back on.", "info")
		"sleep":
			Game.sleep()
		"dock":
			th.phone_docked = true
			Bus.toast.emit("Phone on the charger.", "info")
		"take":
			th.phone_docked = false
			Bus.toast.emit("Phone in your pocket.", "info")
		_:
			if opt_id.begins_with("flip_"):
				Game.automation.flip(opt_id.trim_prefix("flip_"))
			elif opt_id.begins_with("wear_"):
				outfit = opt_id.trim_prefix("wear_")
				Bus.toast.emit("Changed into: %s." % str(OUTFITS[str(outfit)].label), "info")
	Game.presence.update()
	Bus.thing_changed.emit(thing)
	return true


func _start_timed(key: String) -> void:
	var a: Dictionary = TIMED[key].duplicate(true)
	var th: Dictionary = things
	a["id"] = key
	if key != "forge":
		a["stat"] = "leisure_min"
	if str(outfit) == "pajamas" and a.per.has("health") and float(a.per.health) > 0.0:
		a.per.health = float(a.per.health) * 1.2
	match key:
		"snack":
			th.snacks = int(th.snacks) - 1
		"burrito":
			th.burritos = int(th.burritos) - 1
		"lunch":
			th.lunch = true
		"forge":
			th.ink = int(th.ink) - 1
	Game.activities.start(a)
	Bus.thing_changed.emit(str(a.thing))


func _on_activity_ended(a: Dictionary, completed: bool) -> void:
	if not completed or not Game.active:
		return
	var th: Dictionary = things
	match str(a.get("id", "")):
		"brew":
			th.mug = 3
			th.coffees = int(th.coffees) + 1
			if int(th.coffees) >= 3:
				Game.stats.remove_buff("jitter")
				Game.stats.add_buff("wired", 90)
				Bus.toast.emit("Third coffee. You can hear colours.", "warn")
			elif int(th.coffees) == 2:
				Game.stats.add_buff("jitter", 75)
		"burrito":
			Game.stats.add_buff("fed", 120)
		"lunch":
			Game.stats.add_buff("fed", 180)
		"study":
			Game.stats.add_buff("jargon", 180)
			Bus.toast.emit("You can now say 'leverage' with a straight face.", "good")
		"workout":
			Game.stats.remove_buff("jitter")
			Game.stats.remove_buff("wired")
			Game.stats.add_buff("endorphins", 150)
		"tv":
			if Game.chance(55.0):
				Game.stats.add_buff("inspired", 240)
				Bus.toast.emit("A courtroom drama gave you an idea for an excuse.", "good")
		"forge":
			if Game.chance(18.0):
				th.jam = true
				Bus.toast.emit("PAPER JAM. The note is shredded.", "bad")
			else:
				th.notes = int(th.notes) + 1
				Bus.toast.emit("One very official doctor's note, hot off the press.", "good")
	Bus.thing_changed.emit(str(a.get("thing", "")))


func _on_minute() -> void:
	if not Game.active:
		return
	var th: Dictionary = things
	if bool(th.phone_docked):
		th.phone_bat = minf(100.0, float(th.phone_bat) + 1.6)
	else:
		th.phone_bat = maxf(0.0, float(th.phone_bat) - 0.03)
