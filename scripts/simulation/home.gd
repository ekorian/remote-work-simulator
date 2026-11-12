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
	"bin": {"name": "Kitchen Bin", "room": "Kitchen"},
	# --- out in town ---
	"mart": {"name": "QuickStop", "room": "Town"},
	"diner": {"name": "Patty's Take-Away", "room": "Town"},
	"odds": {"name": "Odds & Ends", "room": "Town"},
	"cart": {"name": "Coffee Cart", "room": "Town"},
	"vending": {"name": "Vending Machine", "room": "Town"},
	"news_box": {"name": "Newspaper Box", "room": "Town"},
	"bench": {"name": "Park Bench", "room": "Town"},
	"hoop": {"name": "Basketball Hoop", "room": "Town"},
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
	"heat": {"thing": "microwave", "label": "Heat it up", "mins": 2, "speed": 1.5, "anim": "use", "per": {}},
	"bench": {"thing": "bench", "label": "Sit in the park", "mins": 25, "speed": 6.0, "anim": "lounge", "per": {"health": 0.5, "energy": 0.2}},
}

## Junk food. Where it turns up every morning (the apartment knows where
## each named spot is), and what the fridge hands out.
const MORNING_SPOTS := ["desk", "coffee_table", "counter_a", "counter_b", "kitchen_table", "nightstand", "sofa", "tv_stand"]
const MORNING_ITEMS := 5
const FRIDGE_GROUPS := ["drink", "frozen"]
const FRIDGE_STOCK := 3
const HOT_BONUS := 1.4            ## a heated item does this much more per bite
const FULL := 100.0               ## you cannot eat past this
const STUFFED_AT := 85.0          ## above this you waddle
const DIGEST := 0.45              ## fullness lost per game minute
const PIZZA_PRICE := 18
const PIZZA_MINUTES := 20
const MESS_MAX := 5.0             ## most health a filthy flat costs you in the morning
const TIDY_MAX := 4               ## bin this many a day for a point of health each
const MAX_ITEMS := 44
const SQUEEZES := 6               ## squeezes of the stress ball a day that still help
const POCKETS := 8                ## how many things fit in your pockets
const TOYS := {"stress_ball": "Stress Ball", "rubber_duck": "Rubber Duck"}     ## on your desk on Monday

## Things that are not food. `use`: what a click does with it in your hand.
## `big`: does not fit in a pocket. `decor`: looks good on a desk on camera.
const PROPS := {
	"stress_ball": {"name": "Stress Ball", "use": "squeeze", "price": 4, "blurb": "It has seen things."},
	"rubber_duck": {"name": "Rubber Duck", "use": "squeak", "price": 5, "decor": true, "blurb": "It listens. It does not judge. It squeaks."},
	"paper_ball": {"name": "Ball of Paper", "use": "", "price": 0, "blurb": "A first draft."},
	"basketball": {"name": "Basketball", "use": "", "price": 12, "big": true, "blurb": "There is a hoop in the park."},
	"book": {"name": "Airport Business Book", "use": "read", "price": 9, "decor": true, "blurb": "'Synergise or Die'. You will read the back."},
	"gnome": {"name": "Garden Gnome", "use": "", "price": 14, "big": true, "decor": true, "blurb": "He guards the lawn. He is not good at it."},
	"cactus": {"name": "Small Cactus", "use": "", "price": 7, "decor": true, "blurb": "The only thing in the flat that thrives on neglect. Apart from you."},
	"trophy": {"name": "Employee of the Month Trophy", "use": "", "price": 15, "decor": true, "blurb": "March 2019. Somebody else's name. Nobody checks."},
	"teddy": {"name": "Teddy Bear", "use": "squeeze", "price": 10, "decor": true, "blurb": "Emotional support, ages 3 and up."},
	"snow_globe": {"name": "Snow Globe", "use": "shake", "price": 8, "decor": true, "blurb": "A tiny office in a blizzard. Relatable."},
	"traffic_cone": {"name": "Traffic Cone", "use": "", "price": 0, "big": true, "blurb": "Property of the council. Was."},
	"flowers": {"name": "Bunch of Flowers", "use": "", "price": 9, "decor": true, "gift": 2.0, "blurb": "Somebody would love these."},
	"newspaper": {"name": "Newspaper", "use": "read", "price": 2, "blurb": "Yesterday's news, today's excuse."},
	"scratch_card": {"name": "Scratch Card", "use": "scratch", "price": 3, "blurb": "Statistically, a donation."},
}

## Where things are sold in town. `sells`: food groups, or item ids outright.
const SHOPS := {
	"mart": {"name": "QuickStop", "open": 420, "close": 1410, "groups": ["sweet", "crunchy", "drink", "frozen"], "extra": ["scratch_card", "newspaper"], "shelf": 7, "lines": "clerk_mart"},
	"diner": {"name": "Patty's Take-Away", "open": 630, "close": 1320, "groups": ["hot"], "extra": [], "shelf": 7, "lines": "clerk_diner"},
	"odds": {"name": "Odds & Ends", "open": 600, "close": 1140, "groups": [], "extra": ["gnome", "cactus", "trophy", "teddy", "snow_globe", "basketball", "book", "flowers", "rubber_duck"], "shelf": 9, "lines": "clerk_odds"},
	"cart": {"name": "Coffee Cart", "open": 450, "close": 990, "groups": [], "extra": ["coffee_cup", "donut", "pretzel"], "shelf": 3, "lines": "clerk_cart"},
	"vending": {"name": "Vending Machine", "open": 0, "close": 1440, "groups": [], "extra": ["soda_can", "energy_can", "candy_bar", "chips"], "shelf": 4, "lines": ""},
}
const VENDING_EATS := 12.0        ## % chance the machine keeps your money
const TOWN_SPOTS := {"garden": "gnome", "roadworks": "traffic_cone", "park": "basketball", "bench": "teddy"}

const OUTFITS := {
	"casual": {"label": "Hoodie and jeans", "hint": "Neutral on camera."},
	"shirt": {"label": "Business on top, pajamas below", "hint": "+9% on video-call bluffs."},
	"pajamas": {"label": "Full pajamas", "hint": "+20% health from leisure. -10% on video-call bluffs."},
}


var things: Dictionary = {}      ## state of the objects in the flat
var outfit := "casual"
var items: Array = []            ## loose things you can pick up: [{id, food, bites, hot, trash, spot, at}]
var held := ""                   ## id of the item in your hand ("" = empty-handed)
var pockets: Array = []          ## ids of the items in your pockets, in order
var outside := false             ## out in town (set by the 3D world)
var decor := 0                   ## ornaments standing on your desk (set by the 3D world)


func _ready() -> void:
	Game.time.minute_passed.connect(_on_minute)
	Bus.activity_ended.connect(_on_activity_ended)


func save_state() -> Dictionary:
	return {"things": things, "outfit": outfit, "items": items, "held": held, "pockets": pockets}


func load_state(d: Dictionary) -> void:
	setup_run()
	for k in d.get("things", {}):
		things[k] = d.things[k]
	outfit = str(d.get("outfit", "casual"))
	items = d.get("items", [])
	held = str(d.get("held", ""))
	if item(held).is_empty():
		held = ""
	pockets = []
	for pid in d.get("pockets", []):
		if not item(str(pid)).is_empty():
			pockets.append(str(pid))
	Bus.items_changed.emit()


func setup_run() -> void:
	outfit = "casual"
	things = {
		"router_on": true, "router_cuts": 0, "router_off_at": -1,
		"laptop_until": -1, "laptop_updates": 0,
		"phone_bat": 85.0, "phone_docked": false,
		"notes": 0, "ink": 3, "jam": false,
		"mug": 1, "coffees": 0, "mug_wedges": 0,
		"snacks": FRIDGE_STOCK, "burritos": 2, "lunch": false,
		"staged_until": -1, "wiggle_at": -99, "outage_until": -1,
		"fullness": 0.0, "pizza_at": -1, "pizza_today": false, "tidied": 0, "squeezes": 0, "read": false, "hoops": 0,
	}
	items = []
	held = ""
	pockets = []
	outside = false
	decor = 0
	add_item("stress_ball", "desk_left")
	add_item("rubber_duck", "desk_right")
	for spot in TOWN_SPOTS:
		add_item(str(TOWN_SPOTS[spot]), str(spot))
	_restock()


func new_day() -> void:
	var th: Dictionary = things
	th.router_on = true
	th.router_cuts = 0
	th.laptop_until = -1
	th.laptop_updates = 0
	th.coffees = 0
	th.mug_wedges = 0
	th.snacks = FRIDGE_STOCK
	th.burritos = 2
	th.pizza_today = false
	th.tidied = 0
	th.squeezes = 0
	th.read = false
	th.hoops = 0
	th.fullness = float(th.get("fullness", 0.0)) * 0.3
	_morning_mess()
	_restock()
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
			var price := Game.economy.price(PIZZA_PRICE)
			var waiting := int(th.get("pizza_at", -1)) >= 0
			var why := "It's on its way." if waiting else ("One pizza a day. Have some dignity." if bool(th.get("pizza_today", false)) else "You can't afford a pizza. That is a low point.")
			out.append(_opt("pizza", "Order a pizza ($%d)" % price, "use", "Eight slices at your door in %d minutes." % PIZZA_MINUTES, not waiting and not bool(th.get("pizza_today", false)) and Game.economy.can_afford(price), why))
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
			out.append(_opt("take", "Take something for later", "use", "A cold drink or a dessert, in your hand. %d left today." % int(th.snacks), int(th.snacks) > 0 and held == "", "Your hands are full." if held != "" else "The fridge is empty until tomorrow."))
		"coffee":
			out.append(_timed("brew", "Refills your desk mug. Too many cause jitters."))
		"microwave":
			out.append(_timed("burrito", "No passive energy drain for 2h. %d left." % int(th.burritos), int(th.burritos) > 0, "No burritos left today."))
			var mine := item(held)
			if not mine.is_empty() and not bool(mine.trash) and str(food(mine).get("group", "")) == "hot":
				out.append(_timed("heat", "Your %s gives %d%% more per bite." % [item_name(mine).to_lower(), int(round((HOT_BONUS - 1.0) * 100.0))], not bool(mine.hot), "It is already hot."))
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
		"bench":
			out.append(_timed("bench", "Fresh air. You are not at your desk, and it shows."))
		"hoop":
			out.append(_opt("look", "Look at the hoop", "use", "Throw a basketball through it (Q)."))
		"news_box":
			out.append(_buy_opt("news_box", "newspaper"))
		"mart", "diner", "odds", "cart", "vending":
			if not shop_open(thing):
				out.append(_opt("closed", "%s is closed" % str(SHOPS[thing].name), "use", "", false, "Open %s to %s." % [Cfg.fmt_time(float(SHOPS[thing].open)), Cfg.fmt_time(float(SHOPS[thing].close))]))
			else:
				for what in shop_stock(thing):
					out.append(_buy_opt(thing, str(what)))
		"bin":
			var junk := item(held)
			if junk.is_empty():
				out.append(_opt("bin", "Bin something", "use", "", false, "Nothing in your hand. Pick up some rubbish first."))
			else:
				out.append(_opt("bin", "Bin the %s" % item_name(junk).to_lower(), "use", "A tidy flat is good for you." if bool(junk.trash) else "It is still good. Mostly."))
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
			if thing == "fridge":
				th.snacks = int(th.snacks) - 1
				var options: Array = []
				for fid in Db.foods:
					if str(Db.foods[fid].group) in FRIDGE_GROUPS:
						options.append(fid)
				var got := add_item(str(Game.pick(options)), "hand")
				hold(str(got.id))
				Bus.toast.emit("You took: %s." % item_name(got), "info")
			else:
				th.phone_docked = false
				Bus.toast.emit("Phone in your pocket.", "info")
		"pizza":
			Game.economy.add_money(-Game.economy.price(PIZZA_PRICE), "Pizza")
			th.pizza_today = true
			th.pizza_at = Game.time.now() + PIZZA_MINUTES
			Bus.sfx.emit("buy")
			Bus.toast.emit("Pizza ordered. It will be at the front door in %d minutes." % PIZZA_MINUTES, "good")
		"bin":
			bin(held)
		"look", "closed":
			pass
		_:
			if opt_id.begins_with("buy_"):
				buy(thing, opt_id.trim_prefix("buy_"))
			elif opt_id.begins_with("flip_"):
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
		"heat":
			a["item"] = held
			a.erase("stat")
	Game.activities.start(a)
	Bus.thing_changed.emit(str(a.thing))


func _on_activity_ended(a: Dictionary, completed: bool) -> void:
	if not completed or not Game.active:
		return
	var th: Dictionary = things
	match str(a.get("id", "")):
		"brew":
			th.mug = 3
			_caffeine()
		"heat":
			var warmed := item(str(a.get("item", "")))
			if not warmed.is_empty():
				warmed.hot = true
				Bus.sfx.emit("good")
				Bus.toast.emit("Your %s is now dangerously hot in the middle and cold at the edges." % item_name(warmed).to_lower(), "good")
				Bus.items_changed.emit()
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
	# Digestion, and the pizza you ordered.
	if not Game.time.running():
		return
	th.fullness = maxf(0.0, float(th.get("fullness", 0.0)) - DIGEST)
	if outside:
		Game.bump("outside_min")
		Game.tutor.hint("outside")
		Game.tutor.tick("town")
	if float(th.fullness) >= STUFFED_AT:
		Game.stats.add_buff("stuffed", 3)
	if int(th.get("pizza_at", -1)) >= 0 and Game.time.now() >= int(th.pizza_at):
		th.pizza_at = -1
		add_item("pizza_box", "doormat")
		Bus.sfx.emit("ring")
		Bus.toast.emit("Knock knock. Your pizza is on the doormat.", "good")


# ---------------------------------------------------------------------------
# Loose items: junk food, what is left of it, and things to fidget with
# ---------------------------------------------------------------------------

func item(id: String) -> Dictionary:
	if id == "":
		return {}
	for it in items:
		if str(it.id) == id:
			return it
	return {}


func food(it: Dictionary) -> Dictionary:
	return Db.foods.get(str(it.get("food", "")), {})


func item_name(it: Dictionary) -> String:
	var def := food(it)
	if def.is_empty():
		return str(PROPS.get(str(it.get("food", "")), {}).get("name", "Thing"))
	if bool(it.get("trash", false)):
		return str(def.trash_name) if str(def.trash_name) != "" else "Rubbish"
	return str(def.display_name)


func item_model(it: Dictionary) -> String:
	## Which FoodKit model shows this item right now.
	var def := food(it)
	if def.is_empty():
		return str(it.get("food", ""))          # a toy: the id is the model
	return str(def.trash) if bool(it.get("trash", false)) else str(def.model)


func fullness() -> float:
	return float(things.get("fullness", 0.0))


func add_item(food_id: String, spot: String = "", trash: bool = false) -> Dictionary:
	## Put something in the flat. `spot` names a place the apartment knows
	## ("desk", "doormat", "hand"...); the 3D world moves it from there.
	var def: Dictionary = Db.foods.get(food_id, {})
	var it := {
		"id": Game.next_id("i"), "food": food_id, "bites": int(def.get("bites", 0)),
		"hot": false, "trash": trash, "spot": spot, "at": [],
	}
	items.append(it)
	while items.size() > MAX_ITEMS:
		# Too much stuff: the oldest rubbish goes first, then the oldest food.
		# Never what you are carrying, and never an ornament.
		var drop: Dictionary = {}
		for pass_n in 2:
			for old in items:
				if str(old.id) == held or str(old.id) in pockets or old == it or is_prop(old):
					continue
				if bool(old.trash) or pass_n == 1:
					drop = old
					break
			if not drop.is_empty():
				break
		if drop.is_empty():
			break
		items.erase(drop)
	Bus.items_changed.emit()
	return it


func remove_item(id: String) -> void:
	var it := item(id)
	if it.is_empty():
		return
	items.erase(it)
	if held == id:
		held = ""
	pockets.erase(id)
	Bus.items_changed.emit()


func hold(id: String) -> bool:
	## Take something in your hand. What was there goes in a pocket if it fits.
	if item(id).is_empty():
		return false
	if held != "" and held != id:
		if not stow(held):
			return false
	pockets.erase(id)
	held = id
	item(id).spot = ""
	Bus.items_changed.emit()
	return true


# --- Pockets ---------------------------------------------------------------------

func fits_pocket(it: Dictionary) -> String:
	## "" if this would go in a pocket, otherwise why not.
	if it.is_empty():
		return "Nothing to put away"
	if bool(PROPS.get(str(it.food), {}).get("big", false)) or item_model(it) in ["pizza_box", "trash_pizza_box", "drumsticks", "popcorn"]:
		return "%s does not fit in a pocket" % item_name(it)
	if pockets.size() >= POCKETS:
		return "Your pockets are full"
	return ""


func stow(id: String) -> bool:
	## Put an item (in your hand, or lying in front of you) in your pockets.
	var it := item(id)
	if str(id) in pockets:
		return true
	var why := fits_pocket(it)
	if why != "":
		Bus.toast.emit(why + ".", "warn")
		return false
	pockets.append(id)
	it.spot = ""
	if held == id:
		held = ""
	Game.tutor.hint("pockets")
	Bus.sfx.emit("pickup")
	Bus.items_changed.emit()
	return true


func draw(id: String) -> bool:
	## Take something out of a pocket.
	return str(id) in pockets and hold(id)


func draw_slot(i: int) -> bool:
	return i >= 0 and i < pockets.size() and draw(str(pockets[i]))


func cycle(dir: int) -> bool:
	## Swap what is in your hand for the next thing in your pockets.
	if pockets.is_empty():
		return false
	return draw(str(pockets[0] if dir > 0 else pockets[pockets.size() - 1]))


func carried() -> Array:
	## Everything on you: the hand first, then the pockets.
	var out: Array = []
	if held != "":
		out.append(item(held))
	for pid in pockets:
		out.append(item(str(pid)))
	return out


# --- Shops -------------------------------------------------------------------------

func shop_open(shop: String) -> bool:
	var s: Dictionary = SHOPS.get(shop, {})
	if s.is_empty():
		return true
	var m := fposmod(Game.time.minute, 1440.0)
	return m >= float(s.open) and m < float(s.close)


func price_of(what: String) -> int:
	if Db.foods.has(what):
		return int(Db.foods[what].price)
	return int(PROPS.get(what, {}).get("price", 0))


func name_of(what: String) -> String:
	if Db.foods.has(what):
		return str(Db.foods[what].display_name)
	return str(PROPS.get(what, {}).get("name", what))


func shop_stock(shop: String) -> Array:
	## What a shop has on the shelf today: the same all day, different tomorrow.
	var s: Dictionary = SHOPS.get(shop, {})
	var pool: Array = []
	for fid in Db.foods:
		if str(Db.foods[fid].group) in s.get("groups", []) and int(Db.foods[fid].price) > 0 and not fid in s.get("extra", []):
			pool.append(fid)
	pool.sort()
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([Game.rng.seed, Game.time.day, shop])
	var out: Array = []
	var extras: Array = s.get("extra", [])
	var room: int = int(s.get("shelf", 8)) - extras.size()
	if s.get("groups", []).is_empty():
		room = 0
		pool = []
	while out.size() < room and not pool.is_empty():
		var pick: String = pool[dice.randi() % pool.size()]
		pool.erase(pick)
		out.append(pick)
	out.sort()
	if s.get("groups", []).is_empty():
		var extra: Array = s.get("extra", []).duplicate()
		while extra.size() > int(s.get("shelf", 8)):
			extra.remove_at(dice.randi() % extra.size())
		return extra
	return out + s.get("extra", [])


func _buy_opt(shop: String, what: String) -> Dictionary:
	var cost := price_of(what)
	var hint := str(Db.foods[what].blurb) if Db.foods.has(what) else str(PROPS.get(what, {}).get("blurb", ""))
	if Db.foods.has(what):
		hint = "+%d Energy. %s" % [int(Db.foods[what].energy), hint]
	var room: bool = held == "" or fits_pocket(item(held)) == ""
	var ok: bool = Game.economy.can_afford(cost) and room
	var why := "You can't afford it." if not Game.economy.can_afford(cost) else "Your hands and pockets are full."
	return _opt("buy_" + what, "%s  -  $%d" % [name_of(what), cost], "use", hint, ok, why)


func buy(shop: String, what: String) -> Dictionary:
	## Pay for something and walk away with it in your hand. Returns the item ({} if not).
	var cost := price_of(what)
	if not shop_open(shop) or not (what in shop_stock(shop) or shop == "news_box") or not Game.economy.can_afford(cost):
		return {}
	if held != "" and not stow(held):
		return {}
	Game.economy.add_money(-cost, name_of(what))
	Game.bump("bought")
	if shop == "vending" and Game.chance(VENDING_EATS):
		Bus.sfx.emit("bad")
		Bus.toast.emit("The machine took your $%d and gave you a noise." % cost, "bad")
		return {}
	var it := add_item(what, "hand")
	hold(str(it.id))
	Bus.sfx.emit("coin")
	var lines := Db.lines(str(SHOPS.get(shop, {}).get("lines", "")))
	if not lines.is_empty() and Game.chance(45.0):
		Bus.toast.emit("\"%s\"" % str(Game.pick(lines)), "info")
	return it


func release() -> void:
	if held != "":
		held = ""
		Bus.items_changed.emit()


func bite_view(it: Dictionary) -> Dictionary:
	## What the next bite would do: {ok, why, energy, health, verb}.
	var def := food(it)
	var v := {"ok": false, "why": "", "energy": 0.0, "health": 0.0, "verb": "Eat"}
	if def.is_empty() or bool(it.get("trash", false)) or int(it.get("bites", 0)) <= 0:
		v.why = "Not food"
		return v
	var n := float(maxi(1, int(def.bites)))
	var k := HOT_BONUS if bool(it.get("hot", false)) else 1.0
	v.verb = "Drink" if str(def.group) == "drink" else "Eat"
	v.energy = float(def.energy) / n * k
	v.health = float(def.health) / n * (k if float(def.health) > 0.0 else 1.0)
	if fullness() + float(def.fullness) / n > FULL:
		v.why = "You are stuffed. Give it a while."
		Game.tutor.hint("stuffed")
		return v
	v.ok = true
	return v


func eat(id: String) -> Dictionary:
	## One bite (or gulp). Returns {ok, done, why}: `done` when that was the last of it.
	var it := item(id)
	var view := bite_view(it)
	if not bool(view.ok):
		if str(view.why) != "":
			Bus.toast.emit(str(view.why), "warn")
		return {"ok": false, "done": false, "why": str(view.why)}
	var def := food(it)
	var label := item_name(it)
	if not Game.work.perform("eat", {"label": label}):
		return {"ok": false, "done": false, "why": ""}
	it.bites = int(it.bites) - 1
	things.fullness = fullness() + float(def.fullness) / float(maxi(1, int(def.bites)))
	Game.stats.add("energy", float(view.energy), label)
	Game.stats.add("health", float(view.health), label)
	Game.bump("bites")
	if not Game.time.running():
		return {"ok": true, "done": false, "why": ""}
	Bus.item_bitten.emit(it, int(it.bites))
	var done := int(it.bites) <= 0
	if done:
		Game.bump("junk_eaten")
		if bool(def.caffeine):
			_caffeine()
		if str(def.trash) != "":
			it.trash = true
			it.hot = false
			Game.tutor.hint("rubbish")
		else:
			remove_item(id)
	Bus.items_changed.emit()
	return {"ok": true, "done": done, "why": ""}


func bin(id: String) -> bool:
	## Throw an item away. Rubbish in the bin is good for the soul, up to a point.
	var it := item(id)
	if it.is_empty():
		return false
	if is_prop(it) and str(it.food) != "paper_ball":
		Bus.toast.emit("You would miss it by Thursday.", "info")
		return false
	var was_trash := bool(it.trash)
	var label := item_name(it)
	remove_item(id)
	Game.bump("binned")
	Bus.sfx.emit("pop")
	if was_trash and int(things.get("tidied", 0)) < TIDY_MAX:
		things.tidied = int(things.get("tidied", 0)) + 1
		Game.stats.add("health", 1.0, "Tidied up")
	elif not was_trash:
		Bus.toast.emit("You threw away a perfectly good %s." % label.to_lower(), "info")
	return true


func is_prop(it: Dictionary) -> bool:
	return PROPS.has(str(it.get("food", "")))


func is_toy(it: Dictionary) -> bool:
	return is_prop(it)


func prop(it: Dictionary) -> Dictionary:
	return PROPS.get(str(it.get("food", "")), {})


func prop_verb(it: Dictionary) -> String:
	return str(prop(it).get("use", ""))


func fidget(id: String) -> bool:
	## The thing you do with an object that is not food. False if there is nothing to do.
	var it := item(id)
	if not is_prop(it) or not Game.time.running():
		return false
	match prop_verb(it):
		"squeeze":
			things.squeezes = int(things.get("squeezes", 0)) + 1
			if int(things.squeezes) <= SQUEEZES:
				Game.stats.add("health", 0.5, item_name(it))
			elif int(things.squeezes) == SQUEEZES + 1:
				Bus.toast.emit("That is all the comfort there is in it today.", "info")
			Bus.sfx.emit("pop")
		"squeak":
			Bus.sfx.emit("squeak")
		"shake":
			Bus.sfx.emit("whoosh")
			Bus.toast.emit("It snows on the tiny office. Nobody in there looks up.", "info")
		"read":
			if bool(things.get("read", false)):
				Bus.toast.emit("You have read enough for one day.", "info")
			else:
				things.read = true
				if str(it.food) == "newspaper":
					Game.stats.add_buff("inspired", 240)
					Bus.toast.emit("Page four: a burst water main. That is an excuse waiting to happen.", "good")
				else:
					Game.stats.add_buff("jargon", 90)
					Bus.toast.emit("You read the back cover. You can now say 'paradigm' out loud.", "good")
		"scratch":
			var roll := Game.rng.randf() * 100.0
			var won := 60 if roll < 1.0 else (12 if roll < 8.0 else (3 if roll < 28.0 else 0))
			remove_item(id)
			if won > 0:
				Game.economy.add_money(won, "Scratch card")
				Bus.sfx.emit("payday" if won >= 12 else "coin")
				Bus.toast.emit("Three cherries. You won $%d." % won, "money")
			else:
				Bus.sfx.emit("bad")
				Bus.toast.emit("Two cherries and a lemon. Nothing.", "info")
		_:
			return false
	return true


func hoop() -> void:
	## A basketball went through the hoop in the park.
	things.hoops = int(things.get("hoops", 0)) + 1
	Bus.sfx.emit("good")
	if int(things.hoops) <= 5:
		Game.stats.add("health", 2.0, "Nothing but net")
	Bus.toast.emit("Swish. That is %d today." % int(things.hoops), "good")


func rubbish() -> int:
	var n := 0
	for it in items:
		if bool(it.trash):
			n += 1
	return n


func _caffeine() -> void:
	var th: Dictionary = things
	th.coffees = int(th.coffees) + 1
	if int(th.coffees) >= 3:
		Game.stats.remove_buff("jitter")
		Game.stats.add_buff("wired", 90)
		Bus.toast.emit("That is a lot of caffeine. You can hear colours.", "warn")
	elif int(th.coffees) == 2:
		Game.stats.add_buff("jitter", 75)


func _morning_mess() -> void:
	## Yesterday's rubbish is still there when you wake up, and it shows.
	var n := rubbish()
	if n > 0:
		Game.stats.add("health", -minf(MESS_MAX, float(n)), "Woke up in a landfill")
		Bus.toast.emit("You woke up among %d piece%s of yesterday's rubbish. Bin it in the kitchen." % [n, "" if n == 1 else "s"], "warn")


func _restock() -> void:
	## Every morning there is junk food lying about. Nobody remembers buying it.
	if Db.foods.is_empty():
		return
	var taken := {}
	for it in items:
		if str(it.spot) in MORNING_SPOTS:
			taken[str(it.spot)] = true
	var spots: Array = []
	for s in MORNING_SPOTS:
		if not taken.has(s):
			spots.append(s)
	var pool: Array = []
	for fid in Db.foods:
		if fid != "pizza_box":
			pool.append(fid)
	# Its own dice, seeded from the run and the day: what is lying about
	# never changes what else happens in the week.
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([Game.rng.seed, Game.time.day, "junk"])
	# What nobody touched yesterday is still where it was: top up around it.
	for i in maxi(0, MORNING_ITEMS - taken.size()):
		if spots.is_empty() or pool.is_empty():
			break
		var spot: String = spots[dice.randi() % spots.size()]
		spots.erase(spot)
		var fid: String = pool[dice.randi() % pool.size()]
		pool.erase(fid)
		add_item(fid, spot)
