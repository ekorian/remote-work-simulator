extends Node
## Headless rules + balance tests. No scenes, no rendering: bots drive the
## simulation core through the same API the UI and the apartment use.
##
##   godot --headless --path . res://tests/sim_test.tscn
##   godot --headless --path . res://tests/sim_test.tscn -- --runs=40 --verbose

var fails := 0
var checks := 0
var runs := 16
var verbose := false
var _last_fake := -99
var _last_react := -99
var _last_slack := -99
var trace := ""
var _why: Dictionary = {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = int(a.trim_prefix("--runs="))
		elif a == "--verbose":
			verbose = true
		elif a.begins_with("--trace="):
			trace = a.trim_prefix("--trace=")
	SaveSys.enabled = false
	SaveSys.dir = "user://test_saves"
	Game.manual = true
	if trace != "":
		_trace()
		Game.clear_run()
		get_tree().quit(0)
		return
	_test_content()
	_test_classification()
	_test_rules()
	_test_save()
	_balance()
	Game.clear_run()
	print("")
	print("%d checks, %d failed" % [checks, fails])
	print("RESULT: %s" % ("FAIL" if fails > 0 else "PASS"))
	get_tree().quit(1 if fails > 0 else 0)


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("  FAIL: ", what)
	elif verbose:
		print("  ok: ", what)


# ---------------------------------------------------------------------------
# Content integrity
# ---------------------------------------------------------------------------

func _check_choices(list: Array, where: String) -> void:
	check(not list.is_empty(), "%s has choices" % where)
	var has_safe := false
	for c in list:
		var act: String = str(c.get("a", "ack"))
		check(Actions.DEFS.has(act), "%s: action '%s' is declared" % [where, act])
		if not Actions.is_work(act):
			has_safe = true
		for key in ["ok", "ko"]:
			var out: Dictionary = c.get(key, {})
			if out.has("task"):
				check(Content.TASKS.has(str(out.task)), "%s: ticket '%s' exists" % [where, str(out.task)])
		if c.has("gadget"):
			check(Auto.GADGETS.has(str(c.gadget)), "%s: gadget '%s' exists" % [where, str(c.gadget)])
		if c.has("p"):
			check(float(c.p) > 0.0 and float(c.p) <= 100.0, "%s: sane base chance" % where)
	check(has_safe, "%s can be answered without doing real work" % where)


func _test_content() -> void:
	print("== content integrity")
	for id in Content.PINGS:
		var def: Dictionary = Content.PINGS[id]
		_check_choices(def.choices, "ping:%s" % id)
		check(Content.PEOPLE.has(str(def.from)), "ping:%s sender exists" % id)
	for id in Content.MAILS:
		if Content.MAILS[id].has("choices"):
			_check_choices(Content.MAILS[id].choices, "mail:%s" % id)
	for id in Content.CALLS:
		var def: Dictionary = Content.CALLS[id]
		for i in def.beats.size():
			_check_choices(def.beats[i].choices, "call:%s#%d" % [id, i])
		for k in def.get("pool", []):
			check(Content.BEAT_POOL.has(k), "call:%s pool beat '%s' exists" % [id, k])
	for id in Content.BEAT_POOL:
		_check_choices(Content.BEAT_POOL[id].choices, "beat:%s" % id)
	for day in 5:
		for e in Content.WEEK_EVENTS[day]:
			match str(e[1]):
				"ping":
					check(Content.PINGS.has(str(e[2].id)), "day %d ping '%s' exists" % [day, str(e[2].id)])
				"task":
					check(Content.TASKS.has(str(e[2].id)), "day %d ticket '%s' exists" % [day, str(e[2].id)])
				"mail":
					check(Content.MAILS.has(str(e[2].id)), "day %d mail '%s' exists" % [day, str(e[2].id)])
		for m in Content.WEEK_MEETINGS[day]:
			check(str(m.script) == "review" or Content.CALLS.has(str(m.script)), "day %d meeting script '%s' exists" % [day, str(m.script)])
	for id in Interact.TIMED:
		check(Interact.THINGS.has(str(Interact.TIMED[id].thing)), "activity '%s' is attached to a real object" % id)
	check(Auto.GADGETS.size() >= 5, "at least 5 gadgets (%d)" % Auto.GADGETS.size())
	check(Interact.THINGS.size() >= 20, "at least 20 interactive objects (%d)" % Interact.THINGS.size())


# ---------------------------------------------------------------------------
# Work classification
# ---------------------------------------------------------------------------

func _test_classification() -> void:
	print("== work classification")
	# The examples from the design brief.
	check(Actions.is_work("write_report"), "writing a real report is work")
	check(not Actions.is_work("fake_report"), "generating a fake report is not work")
	check(Actions.is_work("fix_bug"), "fixing the actual bug is work")
	check(not Actions.is_work("pretend_investigate"), "pretending to investigate is not work")
	check(Actions.is_work("work_task"), "completing a legitimate task is work")
	check(not Actions.is_work("delegate_ai"), "delegating to the AI assistant is not work")
	# Every legitimate-work action must be lethal on Professional Unemployed,
	# and no other action may be.
	for id in Actions.DEFS:
		Game.new_run("unemployed", {"name": "T"}, false, 7)
		Game.s.energy = 100.0
		var alive := Actions.perform(id, {})
		var over: bool = Game.s.phase == "over"
		if Actions.is_work(id):
			check(over and not alive and str(Game.s.result.kind) == "worked", "unemployed: '%s' ends the run" % id)
		else:
			check(not over and alive, "unemployed: '%s' is allowed" % id)
	# Health penalties per difficulty.
	for pair in [["intern", 2.0], ["survivor", 8.0], ["senior", 20.0]]:
		Game.new_run(str(pair[0]), {"name": "T"}, false, 7)
		Game.s.health = 100.0
		Actions.perform("work_task", {})
		check(is_equal_approx(Game.get_stat("health"), 100.0 - float(pair[1])), "%s: work costs %d HP (got %.1f)" % [pair[0], int(pair[1]), 100.0 - Game.get_stat("health")])
		check(int(Game.s.today.worked_min) > 0, "%s: worked minutes are logged" % pair[0])
		Game.s.health = 100.0
		Actions.perform("fake_report", {})
		check(is_equal_approx(Game.get_stat("health"), 100.0), "%s: fake work costs no health" % pair[0])


# ---------------------------------------------------------------------------
# Rules
# ---------------------------------------------------------------------------

func _test_rules() -> void:
	print("== rules")
	# Suspicion multiplier and loss at 100.
	Game.new_run("senior", {"name": "T"}, false, 1)
	var before := Game.get_stat("susp")
	Game.add("susp", 10.0, "test")
	check(is_equal_approx(Game.get_stat("susp") - before, 17.0), "senior: suspicion gains are x1.7")
	Game.add("susp", 100.0, "test")
	check(Game.s.phase == "over" and str(Game.s.result.kind) == "fired", "suspicion 100 = fired")
	# Health 0 = burnout.
	Game.new_run("survivor", {"name": "T"}, false, 1)
	Game.add("health", -200.0, "test")
	check(Game.s.phase == "over" and str(Game.s.result.kind) == "burnout", "health 0 = burnout")
	# Presence.
	Game.new_run("survivor", {"name": "T"}, false, 1)
	Game.advance(5)
	check(str(Game.s.pres.status) == "away", "nobody at the desk = Away")
	Game.set_at_desk(true)
	check(str(Game.s.pres.status) == "online", "at the desk = Available")
	Game.set_at_desk(false)
	Game.advance(Cfg.IDLE_LIMIT + 2)
	check(str(Game.s.pres.status) == "away", "status decays to Away after leaving the desk")
	# Router.
	Interact.use("router", "off")
	check(str(Game.s.pres.status) == "offline" and Deception.has_evidence("internet"), "unplugged router = Offline + outage evidence")
	Interact.use("router", "on")
	check(Interact.router_on(), "router can be plugged back in")
	# Jiggler keeps you green.
	Game.s.money = 9999
	check(Auto.buy("jiggler") and Auto.toggle("jiggler"), "can buy and switch on the jiggler")
	Game.advance(20)
	check(str(Game.s.pres.status) == "online", "jiggler keeps the status Available")
	# Excuse fatigue.
	Game.new_run("survivor", {"name": "T"}, false, 1)
	var c0 := Deception.chance(46.0, [], "family")
	Deception.attempt("family", "chat", "t")
	var c1 := Deception.chance(46.0, [], "family")
	check(c1 < c0, "reusing an excuse makes it less believable (%.0f -> %.0f)" % [c0, c1])
	# Tickets: fake progress never becomes real progress.
	Game.new_run("unemployed", {"name": "T"}, false, 3)
	Game.set_at_desk(true)
	var t := Corp.add_task("button")
	for i in 6:
		Game.s.energy = 100.0
		Corp.task_fake(str(t.id))
	check(int(t.real) == 0 and float(t.fake) >= 100.0 and Game.s.phase != "over", "fake updates fill the bar without real work")
	check(int(Game.s.week.worked_min) == 0, "fake updates log zero worked minutes")
	# Activities restore and can be interrupted.
	Game.new_run("survivor", {"name": "T"}, false, 1)
	Game.s.health = 40.0
	Interact.use("console", "console")
	check(Game.busy(), "console starts a timed activity")
	Game.advance(60)
	check(not Game.busy() and Game.get_stat("health") > 55.0, "console restores health (%.0f)" % Game.get_stat("health"))
	# Day rollover.
	Game.new_run("intern", {"name": "T"}, false, 1)
	Game.set_at_desk(true)
	var guard := 0
	while str(Game.s.phase) == "work" and guard < 800:
		guard += 1
		_drain_blocking()
		Game.advance(1)
	check(str(Game.s.phase) == "evening" and Game.s.reports.size() == 1, "17:00 ends the workday with a report")
	check(int(Game.s.reports[0].salary) >= Cfg.SALARY_BASE, "salary is paid")
	Interact.use("bed", "sleep")
	check(int(Game.s.day) == 1 and str(Game.s.phase) == "work" and int(Game.s.t) == Cfg.DAY_START, "sleeping starts Tuesday at 08:59")


func _drain_blocking() -> void:
	## Keep a test run moving: sit through calls, answer nothing.
	if Corp.in_call():
		Corp.call_timeout()
	var ring := Corp.ringing()
	if not ring.is_empty():
		Corp.join(str(ring.id))


func _test_save() -> void:
	print("== save / load")
	SaveSys.enabled = true
	Game.new_run("senior", {"name": "Saver", "skin": 2}, false, 99)
	Game.set_at_desk(true)
	Game.advance(140)
	_drain_blocking()
	while Corp.in_call():
		Corp.call_timeout()
	Game.s.money = 777
	Auto.buy("jiggler")
	var snap_t := int(Game.s.t)
	var snap_susp := Game.get_stat("susp")
	var snap_tasks: int = Game.s.tasks.size()
	check(SaveSys.save("slot3"), "save succeeds")
	check(not SaveSys.meta("slot3").is_empty(), "save has readable metadata")
	Game.new_run("intern", {"name": "Other"}, false, 5)
	check(SaveSys.load_game("slot3"), "load succeeds")
	check(int(Game.s.t) == snap_t and is_equal_approx(Game.get_stat("susp"), snap_susp), "clock and suspicion restored")
	check(Game.s.tasks.size() == snap_tasks and Auto.owns("jiggler"), "tickets and gadgets restored")
	check(str(Game.s.diff) == "senior" and Game.player_name() == "Saver", "difficulty and player restored")
	check(typeof(Game.s.t) == TYPE_FLOAT and typeof(Game.s.day) == TYPE_INT, "numeric types survive the round trip")
	Game.advance(30)
	check(Game.active and int(Game.s.t) == snap_t + 30, "simulation continues after loading")
	SaveSys.delete("slot3")
	check(SaveSys.meta("slot3").is_empty(), "save can be deleted")
	SaveSys.enabled = false


# ---------------------------------------------------------------------------
# Balance: three kinds of player across four difficulties
# ---------------------------------------------------------------------------

func _balance() -> void:
	print("== balance (%d runs each)" % runs)
	print("  %-8s %-11s %5s %5s %6s %6s %7s %7s %6s  %-7s %s" % ["bot", "difficulty", "win%", "day", "susp", "hp", "worked", "money", "slack", "grades", "losses"])
	var table := {}
	for bot in ["idle", "worker", "slacker"]:
		for diff in Cfg.DIFF_ORDER:
			var wins := 0
			var day_sum := 0.0
			var susp_sum := 0.0
			var hp_sum := 0.0
			var worked_sum := 0.0
			var money_sum := 0.0
			var slack_sum := 0.0
			var grades := {}
			var kinds := {}
			for i in runs:
				var r := _run(bot, diff, 1000 + i * 7919)
				if bool(r.won):
					wins += 1
				else:
					kinds[r.kind] = int(kinds.get(r.kind, 0)) + 1
				day_sum += float(r.day)
				susp_sum += float(r.susp)
				hp_sum += float(r.health)
				worked_sum += float(r.week.worked_min)
				money_sum += float(r.money)
				slack_sum += float(r.week.get("slack_min", 0))
				grades[r.grade] = int(grades.get(r.grade, 0)) + 1
			var n := float(runs)
			var rate := 100.0 * float(wins) / n
			table["%s/%s" % [bot, diff]] = {"rate": rate, "worked": worked_sum / n, "slack": slack_sum / n, "grades": grades}
			var gtxt := ""
			for g in ["S", "A", "B", "C", "D"]:
				if grades.has(g):
					gtxt += "%s%d " % [g, int(grades[g])]
			print("  %-8s %-11s %5.0f %5.1f %6.0f %6.0f %7.0f %7.0f %6.0f  %-7s %s" % [bot, diff, rate, day_sum / n + 1.0, susp_sum / n, hp_sum / n, worked_sum / n, money_sum / n, slack_sum / n, gtxt, str(kinds)])
	# Standing still must never be a winning strategy.
	for diff in Cfg.DIFF_ORDER:
		check(float(table["idle/" + diff].rate) == 0.0, "idle bot never wins on %s" % diff)
	# Doing the job is lethal on the top difficulty and unhealthy on Senior.
	check(float(table["worker/unemployed"].rate) == 0.0, "an honest worker cannot win Professional Unemployed")
	check(float(table["worker/senior"].rate) <= 10.0, "an honest worker burns out on Senior Bullshitter")
	# Skilled avoidance wins, and does so with zero work.
	check(float(table["slacker/intern"].rate) >= 90.0, "slacker reliably wins Intern (%.0f%%)" % float(table["slacker/intern"].rate))
	check(float(table["slacker/survivor"].rate) >= 65.0, "slacker usually wins Corporate Survivor (%.0f%%)" % float(table["slacker/survivor"].rate))
	check(float(table["slacker/senior"].rate) >= 25.0, "Senior Bullshitter is winnable (%.0f%%)" % float(table["slacker/senior"].rate))
	check(float(table["slacker/unemployed"].rate) >= 25.0, "Professional Unemployed is winnable (%.0f%%)" % float(table["slacker/unemployed"].rate))
	check(float(table["slacker/senior"].rate) < float(table["slacker/intern"].rate), "Senior is harder than Intern")
	for diff in Cfg.DIFF_ORDER:
		check(float(table["slacker/" + diff].worked) == 0.0, "slacker does zero real work on %s" % diff)
	# The top grades are earned by slacking on company time, and are reachable.
	check(not table["worker/intern"].grades.has("S") and not table["worker/intern"].grades.has("A"), "doing the job never earns an A or S")
	check(int(table["slacker/survivor"].grades.get("S", 0)) + int(table["slacker/survivor"].grades.get("A", 0)) > 0, "A or S is reachable on Corporate Survivor")


func _run(bot: String, diff: String, seed_v: int) -> Dictionary:
	Game.new_run(diff, {"name": "Bot"}, false, seed_v)
	_last_fake = -99
	_last_react = -99
	_last_slack = -99
	var guard := 0
	while Game.active and str(Game.s.phase) != "over" and guard < 30000:
		guard += 1
		match bot:
			"idle":
				_bot_idle()
			"worker":
				_bot_worker()
			"slacker":
				_bot_slacker()
		if not Game.active or str(Game.s.phase) == "over":
			break
		Game.advance(1)
	var res: Dictionary = Game.s.get("result", {})
	if res.is_empty():
		fails += 1
		print("  FAIL: run did not finish (%s/%s seed %d, day %d t %d)" % [bot, diff, seed_v, int(Game.s.day), int(Game.s.t)])
		res = Game.build_result("stuck", {})
	return res


func _evening_done() -> bool:
	## Returns true if the bot should stop acting this minute.
	if str(Game.s.phase) != "evening":
		return false
	if int(Game.s.day) >= 4:
		Game.finish_week()
	return true


func _bot_idle() -> void:
	## Stands in the hallway all week. Must lose.
	if _evening_done():
		if Game.active and str(Game.s.phase) == "evening":
			Game.sleep()
		return
	if Corp.in_call():
		Corp.call_timeout()


func _bot_worker() -> void:
	## The model employee: does everything asked, for real.
	if _evening_done():
		if not Game.active or str(Game.s.phase) != "evening":
			return
		if Game.busy():
			return
		if Game.get_stat("health") < 95.0 and int(Game.s.t) < 1320:
			Interact.use("console", "console")
		else:
			Game.sleep()
		return
	Game.set_at_desk(true)
	if Corp.in_call():
		var list := Corp.call_choices()
		Corp.call_choose(_work_choice(list))
		return
	var ring := Corp.ringing()
	if not ring.is_empty():
		Game.stop_activity()
		Corp.join(str(ring.id))
		return
	for p in Corp.prompts():
		if Game.busy():
			break
		Corp.answer(str(p.id), _work_choice(Corp.choices_of(p)))
		return
	if Game.busy():
		return
	if Game.get_stat("energy") < 20.0:
		Interact.use("fridge", "snack")
		if not Game.busy():
			Interact.use("coffee", "brew")
		return
	for t in Corp.open_tasks():
		if str(t.by) == "":
			Corp.task_work(str(t.id))
			return
	if not Game.flag("report_day_%d" % int(Game.s.day)):
		Corp.real_report()


func _work_choice(list: Array) -> int:
	for i in list.size():
		if Actions.is_work(str(list[i].get("a", "ack"))):
			return i
	return 0


func _val(out: Dictionary) -> float:
	var v := 0.0
	v -= float(out.get("susp", 0)) * 1.0
	v += float(out.get("ill", 0)) * 0.4
	v += float(out.get("hp", 0)) * 0.5
	v += float(out.get("favor", 0)) * 3.0
	v += float(out.get("cover", 0)) * 0.05
	if out.has("task"):
		v -= 5.0
	if out.has("later"):
		v -= 3.0
	return v


func _best_choice(list: Array, context: String) -> Array:
	## [index, excuse_id] of the best option that is NOT legitimate work.
	var best := -1
	var best_v := -INF
	var best_ex := ""
	for i in list.size():
		var c: Dictionary = list[i]
		var act: String = str(c.get("a", "ack"))
		if Actions.is_work(act):
			continue
		var view := Corp.choice_view(c, context)
		if not view.ok:
			continue
		if bool(c.get("excuse", false)):
			for e in Deception.options(context):
				if bool(e.burned):
					continue
				var p := float(e.chance) / 100.0
				var ev := p * 1.0 + (1.0 - p) * -7.0 - 1.5
				if str(e.id) in ["internet", "power"]:
					ev -= 8.0          # this bot never unplugs the router
				if ev > best_v:
					best_v = ev
					best = i
					best_ex = str(e.id)
			continue
		var v := 0.0
		if float(view.odds) >= 0.0:
			var p := float(view.odds) / 100.0
			v = p * _val(c.get("ok", {})) + (1.0 - p) * _val(c.get("ko", c.get("ok", {})))
		else:
			v = _val(c.get("ok", {}))
		if Actions.cls_of(act) == Actions.Cls.STRESS:
			v -= Actions.hp_cost(act) * 0.6
		if v > best_v:
			best_v = v
			best = i
			best_ex = ""
	return [best, best_ex]


func _audit_soon() -> bool:
	for e in Game.s.queue:
		if str(e.ev) == "audit" and bool(e.args.get("warned", false)) and int(e.at) - Game.now() <= 30 and int(e.at) >= Game.now():
			return true
	return false


func _bot_slacker() -> void:
	## A competent work-avoider. Never does legitimate work.
	var s: Dictionary = Game.s
	if _evening_done():
		if Game.active and str(s.phase) == "evening":
			_slacker_evening()
		return
	if Corp.in_call():
		var pick := _best_choice(Corp.call_choices(), Corp.call_context())
		if int(pick[0]) < 0:
			Corp.call_timeout()
		else:
			Corp.call_choose(int(pick[0]), str(pick[1]))
		return
	var ring := Corp.ringing()
	if not ring.is_empty():
		Game.stop_activity()
		Game.set_at_desk(true)
		if Corp.can_dodge(ring) and Corp.conflicts(ring):
			Corp.decline_conflict(str(ring.id))
		elif Corp.can_dodge(ring) and not bool(ring.mandatory) and Auto.working("loopcam") and Interact.loop_ready():
			Corp.send_loop(str(ring.id))
		if str(ring.state) == "ringing":
			Corp.join(str(ring.id))
		return
	var now := Game.now()
	var t := int(s.t)
	# Answer whatever is pending, most urgent first.
	var pending := Corp.prompts()
	if not pending.is_empty():
		var p: Dictionary = pending[0]
		if not Game.busy() or int(p.due) - now <= 6:
			Game.stop_activity()
			Game.set_at_desk(true)
			var pick := _best_choice(Corp.choices_of(p), "chat")
			if int(pick[0]) >= 0:
				Corp.answer(str(p.id), int(pick[0]), str(pick[1]))
			return
	if Game.busy():
		return
	var th: Dictionary = s.things
	# Self-care.
	if t >= 720 and t < 760 and not bool(th.lunch):
		Game.set_at_desk(false)
		Interact.use("table", "lunch")
		return
	if Game.get_stat("energy") < 30.0:
		Game.set_at_desk(false)
		for pair in [["microwave", "burrito"], ["fridge", "snack"], ["coffee", "brew"], ["bed", "power_nap"]]:
			if Interact.use(str(pair[0]), str(pair[1])):
				return
		return
	if Game.get_stat("health") < 50.0:
		Game.set_at_desk(false)
		Interact.use("console", "console")
		return
	# The point of the job: when the coast is clear, go and do nothing.
	var nerve := 40.0 - 36.0 * (float(Game.diff().susp) - 1.0)      # bolder when suspicion is cheap
	var safe := Game.get_stat("susp") < nerve and Game.get_stat("ill") > 52.0
	var covered: bool = Auto.jiggler_running() or Game.covered() or str(s.pres.status) in ["lunch", "updating", "busy", "meeting"]
	var nm0 := Corp.next_meeting()
	var clear := nm0.is_empty() or int(nm0.start) - t > 50
	if safe and covered and clear and not _audit_soon() and t < 960 and now - _last_slack >= 20:
		Game.set_at_desk(false)
		_last_slack = now + 45
		Interact.use("console", "console")
		return
	# Desk chores.
	Game.set_at_desk(true)
	if str(s.outfit) != "shirt":
		Interact.use("wardrobe", "wear_shirt")
	if Auto.any_broken() or Auto.max_wear() > 28.0:
		Auto.maintain()
		return
	var audit := _audit_soon()
	for id in ["jiggler", "pecker", "replyguy", "reportomatic", "delegatron", "loopcam", "fakescreen"]:
		if Auto.owns(id) and not bool(Auto.g(id).broken):
			var want: bool = not audit
			if bool(Auto.g(id).on) != want:
				Auto.toggle(id)
	if Auto.owns("reportomatic") and int(s.autos.report_at) < 0:
		Auto.set_report_time(600)
	if Auto.owns("loopcam") and not Interact.loop_ready():
		Interact.use("laptop", "record")
	if t >= 600 and not Game.flag("report_day_%d" % int(s.day)) and not Auto.working("reportomatic"):
		Corp.fake_report(false)
		return
	# The Tuesday trick: block the calendar over an optional meeting.
	var nm := Corp.next_meeting()
	if not nm.is_empty() and not bool(nm.mandatory) and not bool(nm.no_dodge) and not Corp.conflicts(nm) and int(nm.start) - t <= 60 and int(nm.start) > t:
		if Corp.add_block(int(nm.start), 30):
			return
	for task in Corp.open_tasks():
		if str(task.by) != "":
			continue
		if int(s.favor) > 0 and int(task.effort) >= 2:
			if Corp.task_delegate(str(task.id)):
				return
		if Auto.working("delegatron") and str(s.autos.ai_task) == "":
			if Corp.task_ai(str(task.id)):
				return
		if not bool(task.clarified) and int(task.due) - now < 200 and float(task.fake) < 60.0:
			if Corp.task_clarify(str(task.id)):
				return
		if not Corp.task_looks_done(task) and Game.get_stat("energy") > 38.0 and now - _last_fake >= 22:
			if Corp.task_fake(str(task.id)):
				_last_fake = now
				return
	if Game.get_stat("ill") < 60.0 and Game.get_stat("energy") > 45.0 and now - _last_react >= 25:
		for thread in ["team", "general"]:
			if Corp.react(thread):
				_last_react = now
				return


func _slacker_evening() -> void:
	if Game.busy():
		return
	for id in ["jiggler", "pecker", "replyguy", "reportomatic", "buzzword", "delegatron", "loopcam", "fakescreen", "smartwatch"]:
		if not Auto.owns(id) and Auto.unlocked(id) and int(Game.s.money) >= Auto.price(id):
			Auto.buy(id)
	var t := int(Game.s.t)
	if t < 1290:
		if Game.get_stat("energy") < 60.0 and Interact.use("microwave", "burrito"):
			return
		if Game.get_stat("health") < 92.0:
			Interact.use("console", "console")
			return
	Interact.use("bed", "sleep")


# ---------------------------------------------------------------------------
# Diagnostics:  -- --trace=slacker/senior --runs=20
# ---------------------------------------------------------------------------

func _on_stat(stat: String, _value: float, delta: float, reason: String) -> void:
	if stat != "susp" and stat != "ill":
		return
	var key := "%s %s %s" % [stat, "+" if delta > 0.0 else "-", reason.get_slice(":", 0) if reason != "" else "(passive)"]
	_why[key] = float(_why.get(key, 0.0)) + delta


func _trace() -> void:
	var bot := trace.get_slice("/", 0)
	var diff := trace.get_slice("/", 1)
	Game.stat_changed.connect(_on_stat)
	var days: Array = []
	for d in 5:
		days.append({"n": 0, "susp": 0.0, "ill": 0.0, "en": 0.0, "hp": 0.0, "absent": 0.0, "exc": 0.0, "avoid": 0.0, "missed": 0.0, "ign": 0.0})
	Game.workday_ended.connect(func(rep: Dictionary):
		var d: Dictionary = days[int(rep.day)]
		d.n += 1
		d.susp += float(Game.s.susp)
		d.ill += float(rep.ill)
		d.en += float(Game.s.energy)
		d.hp += float(rep.health)
		d.absent += float(rep.absent_min)
		d.exc += float(rep.excuses)
		d.avoid += float(rep.meetings_avoided)
		d.missed += float(rep.meetings_missed)
		d.ign += float(Game.s.today.prompts_ignored)
	)
	var wins := 0
	var week := {}
	for i in runs:
		var r := _run(bot, diff, 1000 + i * 7919)
		if bool(r.won):
			wins += 1
		for k in r.week:
			week[k] = float(week.get(k, 0.0)) + float(r.week[k])
	print("TRACE %s/%s: %d/%d wins" % [bot, diff, wins, runs])
	print("  day  runs  susp   ill    en    hp  absent  excuses  avoided  missed  ignored")
	for d in 5:
		var x: Dictionary = days[d]
		var n: float = maxf(1.0, float(x.n))
		print("  %s  %4d  %4.0f  %4.0f  %4.0f  %4.0f  %6.0f  %7.1f  %7.1f  %6.1f  %7.1f" % [Cfg.DAYS_SHORT[d], int(x.n), x.susp / n, x.ill / n, x.en / n, x.hp / n, x.absent / n, x.exc / n, x.avoid / n, x.missed / n, x.ign / n])
	var keys: Array = _why.keys()
	keys.sort_custom(func(a, b): return absf(float(_why[a])) > absf(float(_why[b])))
	print("  per-run totals by cause:")
	for k in keys.slice(0, 26):
		print("    %7.1f  %s" % [float(_why[k]) / float(runs), k])
	var parts: Array = []
	for k in ["excuses", "excuses_failed", "contradictions", "lies", "prompts_answered", "prompts_ignored", "tasks_done", "tasks_faked", "tasks_delegated", "tasks_failed", "auto_runs", "auto_ok", "leisure_min", "pretend_min", "absent_min"]:
		parts.append("%s=%.1f" % [k, float(week.get(k, 0.0)) / float(runs)])
	print("  week avg: ", ", ".join(parts))
