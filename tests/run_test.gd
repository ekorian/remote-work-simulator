extends Node
## Headless full-run tests: four kinds of player across four difficulties,
## each playing whole weeks through the same API the UI uses. "ghost" is the
## skilled slacker who never answers a colleague: it measures what colleagues
## cost you when ignored and what they are worth when befriended.
##
## Verifies that the game reaches both victory and defeat, that all five days
## progress without softlocks, that invariants hold on every simulated
## minute, and that the balance has the intended shape.
##
##   godot --headless --path . res://tests/run_test.tscn [-- --runs=24] [--trace=slacker/senior]

const SAFE_FACTS := ["desk_message", "online_status", "social_post", "auto_message", "auto_report", "ticket_activity"]

var t := TestSuite.new()
var runs := 12
var trace := ""
var _last_fake := -99
var _last_react := -99
var _last_slack := -99
var _minutes := 0
var _violations: Dictionary = {}
var _why: Dictionary = {}
var _rel: Dictionary = {}          ## colleague -> summed final relationship (trace)
var _ghost := false                ## the slacker ignores every colleague


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = int(a.trim_prefix("--runs="))
		elif a.begins_with("--trace="):
			trace = a.trim_prefix("--trace=")
	Game.saves.enabled = false
	Prefs.persist = false
	Game.time.manual = true
	Game.time.minute_passed.connect(_invariants)
	if trace != "":
		_trace()
	else:
		_balance()
	Game.clear_run()
	print("")
	print("%d checks, %d failed" % [t.checks, t.fails])
	print("RESULT: %s" % ("FAIL" if t.fails > 0 else "PASS"))
	get_tree().quit(1 if t.fails > 0 else 0)


# ---------------------------------------------------------------------------
# Invariants, checked on every simulated minute of every run
# ---------------------------------------------------------------------------

func _violate(what: String) -> void:
	_violations[what] = int(_violations.get(what, 0)) + 1


func _invariants() -> void:
	_minutes += 1
	for stat in PlayerStats.STATS:
		var v := Game.stats.get_value(stat)
		if v < 0.0 or v > 100.0 or is_nan(v):
			_violate("%s out of range" % stat)
	var ringing := 0
	for m in Game.comms.meetings:
		if str(m.state) == "ringing":
			ringing += 1
	if ringing > 1:
		_violate("two calls ringing at once")
	if ringing > 0 and Game.comms.in_call():
		_violate("a call rings during another call")
	var per_thread := {}
	for p in Game.comms.prompts:
		if str(p.kind) == "chat":
			per_thread[p.thread] = int(per_thread.get(p.thread, 0)) + 1
			if int(per_thread[p.thread]) > 1:
				_violate("two prompts waiting in one conversation")
	if Game.comms.prompts.size() > EventDirector.MAX_PENDING + 3:
		_violate("too many prompts pending")
	if Game.time.minute > 1600.0:
		_violate("clock ran past bedtime")
	if Game.economy.money < 0:
		_violate("negative money")


# ---------------------------------------------------------------------------
# Balance matrix
# ---------------------------------------------------------------------------

func _balance() -> void:
	t.section("full runs (%d per bot and difficulty)" % runs)
	print("  %-8s %-11s %5s %5s %6s %6s %7s %7s %6s  %-12s %s" % ["bot", "difficulty", "win%", "day", "susp", "hp", "worked", "money", "slack", "grades", "losses"])
	var table := {}
	var outcomes := {}
	var stuck := 0
	for bot in ["idle", "worker", "slacker", "ghost"]:
		for diff in Cfg.DIFF_ORDER:
			if bot == "ghost" and diff != "survivor":
				continue
			var wins := 0
			var sums := {"day": 0.0, "susp": 0.0, "hp": 0.0, "worked": 0.0, "money": 0.0, "slack": 0.0, "lies": 0.0, "caught": 0.0, "told": 0.0, "friends": 0.0, "gained": 0.0, "favours": 0.0, "calls": 0.0}
			var grades := {}
			var kinds := {}
			for i in runs:
				var r := _run(bot, diff, 1000 + i * 7919)
				outcomes[str(r.kind)] = true
				if str(r.kind) == "stuck":
					stuck += 1
				if bool(r.won):
					wins += 1
					grades[r.grade] = int(grades.get(r.grade, 0)) + 1
				else:
					kinds[r.kind] = int(kinds.get(r.kind, 0)) + 1
				sums.day += float(r.day)
				sums.susp += float(r.susp)
				sums.hp += float(r.health)
				sums.worked += float(r.week.worked_min)
				sums.money += float(r.money)
				sums.slack += float(r.week.get("slack_min", 0))
				sums.lies += float(r.claims)
				sums.caught += float(r.caught)
				sums.told += float(r.week.get("snitched", 0))
				sums.friends += float(r.get("friends", 0))
				sums.gained += float(r.week.susp_gained)
				sums.favours += float(r.week.get("favours_called", 0))
				sums.calls += float(r.week.get("calls_taken", 0))
			var n := float(runs)
			var rate := 100.0 * float(wins) / n
			table["%s/%s" % [bot, diff]] = {
				"rate": rate, "worked": sums.worked / n, "grades": grades, "lies": sums.lies / n, "caught": sums.caught / n,
				"told": sums.told / n, "friends": sums.friends / n, "gained": sums.gained / n, "favours": sums.favours / n, "calls": sums.calls / n,
			}
			var gtxt := ""
			for g in ["S", "A", "B", "C", "D"]:
				if grades.has(g):
					gtxt += "%s%d " % [g, int(grades[g])]
			print("  %-8s %-11s %5.0f %5.1f %6.0f %6.0f %7.0f %7.0f %6.0f  %-12s %s" % [bot, diff, rate, sums.day / n + 1.0, sums.susp / n, sums.hp / n, sums.worked / n, sums.money / n, sums.slack / n, gtxt, str(kinds)])
	print("  simulated %d game minutes" % _minutes)
	# Softlocks and invariants.
	t.check(stuck == 0, "every run reaches an ending: no softlocks (%d stuck)" % stuck)
	t.check(_violations.is_empty(), "invariants hold on every simulated minute (%s)" % str(_violations))
	# Both victory and every kind of defeat are reachable.
	for kind in ["win", "fired", "burnout", "worked"]:
		t.check(outcomes.has(kind), "the game can end in '%s'" % kind)
	# Standing still must never be a winning strategy.
	for diff in Cfg.DIFF_ORDER:
		t.check(float(table["idle/" + diff].rate) == 0.0, "idle bot never wins on %s" % diff)
	# Doing the job is lethal on the top difficulty and unhealthy on Senior.
	t.check(float(table["worker/unemployed"].rate) == 0.0, "an honest worker cannot win Professional Unemployed")
	t.check(float(table["worker/senior"].rate) <= 10.0, "an honest worker burns out on Senior Bullshitter")
	t.check(not table["worker/intern"].grades.has("S") and not table["worker/intern"].grades.has("A"), "doing the job never earns an A or S")
	# Skilled avoidance wins, and does so with zero work.
	t.check(float(table["slacker/intern"].rate) >= 90.0, "slacker reliably wins Intern (%.0f%%)" % float(table["slacker/intern"].rate))
	t.check(float(table["slacker/survivor"].rate) >= 60.0, "slacker usually wins Corporate Survivor (%.0f%%)" % float(table["slacker/survivor"].rate))
	t.check(float(table["slacker/senior"].rate) >= 15.0, "Senior Bullshitter is winnable (%.0f%%)" % float(table["slacker/senior"].rate))
	t.check(float(table["slacker/unemployed"].rate) >= 15.0, "Professional Unemployed is winnable (%.0f%%)" % float(table["slacker/unemployed"].rate))
	t.check(float(table["slacker/senior"].rate) < float(table["slacker/intern"].rate), "Senior is harder than Intern")
	for diff in Cfg.DIFF_ORDER:
		t.check(float(table["slacker/" + diff].worked) == 0.0, "slacker does zero real work on %s" % diff)
	t.check(float(table["slacker/survivor"].lies) >= 2.0, "the slacker actually uses the deception engine (%.1f claims per run)" % float(table["slacker/survivor"].lies))
	t.check(int(table["slacker/survivor"].grades.get("S", 0)) + int(table["slacker/survivor"].grades.get("A", 0)) > 0, "A or S is reachable on Corporate Survivor")
	# Colleagues: worth befriending, costly to ignore.
	var nice: Dictionary = table["slacker/survivor"]
	var cold: Dictionary = table["ghost/survivor"]
	print("  colleagues on survivor   told-on  friends  favours  calls  susp gained")
	print("    answers them           %7.1f  %7.1f  %7.1f  %5.1f  %11.0f" % [float(nice.told), float(nice.friends), float(nice.favours), float(nice.calls), float(nice.gained)])
	print("    ignores them           %7.1f  %7.1f  %7.1f  %5.1f  %11.0f" % [float(cold.told), float(cold.friends), float(cold.favours), float(cold.calls), float(cold.gained)])
	t.check(float(nice.calls) >= 6.0, "a week has plenty of colleague calls to take (%.1f)" % float(nice.calls))
	t.check(float(nice.friends) >= 2.0, "answering colleagues makes friends (%.1f per run)" % float(nice.friends))
	t.check(float(nice.favours) >= 2.0, "and friends get used (%.1f favours per run)" % float(nice.favours))
	t.check(float(cold.told) >= 2.0, "ignoring colleagues gets you told on (%.1f times per run)" % float(cold.told))
	t.check(float(cold.told) > float(nice.told) + 1.5, "far more than answering them does (%.1f vs %.1f)" % [float(cold.told), float(nice.told)])
	t.check(float(cold.friends) < float(nice.friends), "and makes no friends (%.1f vs %.1f)" % [float(cold.friends), float(nice.friends)])
	t.check(float(cold.gained) > float(nice.gained), "it costs suspicion (%.0f vs %.0f gained)" % [float(cold.gained), float(nice.gained)])


func _run(bot: String, diff: String, seed_v: int) -> Dictionary:
	Game.new_run(diff, {"name": "Bot"}, false, seed_v)
	_last_fake = -99
	_last_react = -99
	_last_slack = -99
	var guard := 0
	while Game.time.running() and guard < 30000:
		guard += 1
		match bot:
			"idle":
				_bot_idle()
			"worker":
				_bot_worker()
			"slacker", "ghost":
				_ghost = bot == "ghost"
				_bot_slacker()
		if not Game.time.running():
			break
		Game.time.advance(1)
	if Game.result.is_empty():
		print("  STUCK: %s/%s seed %d at day %d %s" % [bot, diff, seed_v, Game.time.day, Cfg.fmt_time(Game.time.minute)])
		return Game.build_result("stuck", {})
	return Game.result


func _evening() -> bool:
	## True while it is evening. Ends the week on Friday.
	if Game.time.phase != "evening":
		return false
	if Game.time.day >= 4:
		Game.finish_week()
	return true


# ---------------------------------------------------------------------------
# Bots
# ---------------------------------------------------------------------------

func _bot_idle() -> void:
	## Stands in the hallway all week. Must lose.
	if _evening():
		if Game.time.phase == "evening":
			Game.sleep()
		return
	if Game.comms.in_call():
		Game.comms.call_timeout()


func _bot_worker() -> void:
	## The model employee: does everything asked, for real.
	if _evening():
		if Game.time.phase != "evening" or Game.activities.busy():
			return
		if Game.stats.get_value("health") < 95.0 and Game.time.minute < 1320.0:
			Game.home.use("console", "console")
		else:
			Game.sleep()
		return
	Game.presence.set_at_desk(true)
	var c := Game.comms
	if c.in_call():
		c.call_choose(_work_choice(c.call_choices()))
		return
	var ring := c.ringing()
	if not ring.is_empty():
		Game.activities.stop()
		c.join(str(ring.id))
		return
	for p in c.pending():
		if Game.activities.busy():
			break
		c.answer(str(p.id), _work_choice(c.choices_of(p)))
		return
	if Game.activities.busy():
		return
	if Game.stats.get_value("energy") < 20.0:
		if not Game.home.use("fridge", "snack"):
			Game.home.use("coffee", "brew")
		return
	for task in Game.work.open_tasks():
		if str(task.by) == "":
			Game.work.task_work(str(task.id))
			return
	if not Game.work.report_sent():
		Game.work.real_report()


func _work_choice(list: Array) -> int:
	for i in list.size():
		if Game.work.is_work(str(list[i].get("a", "ack"))):
			return i
	return 0


func _val(out: Dictionary) -> float:
	var v := -float(out.get("susp", 0)) + float(out.get("ill", 0)) * 0.4 + float(out.get("hp", 0)) * 0.5
	v += float(out.get("favor", 0)) * 3.0 + float(out.get("cover", 0)) * 0.05 + float(out.get("rel", 0)) * 0.2
	if out.has("task"):
		v -= 5.0
	if out.has("later") or out.has("event"):
		v -= 3.0
	if str(out.get("claim_status", "")) == "patched":
		v += 3.0
	if str(out.get("claim_status", "")) == "exposed":
		v -= 4.0
	if out.has("claim") and not _sustainable(str(out.claim)):
		v -= 6.0
	return v


func _sustainable(type: String) -> bool:
	## Can this bot (which lives at its desk) keep this story from falling apart?
	var def: Dictionary = Db.claims[type]
	for fact in def.contradicted_by:
		if fact in SAFE_FACTS:
			if str(fact) == "ticket_activity" and bool(def.get("ticket_scoped", false)):
				continue
			return false
	for f in def.followups:
		if str(f.kind) == "verify" and Game.deception.evidence_for(type).is_empty():
			return false
	return true


func _best_choice(list: Array, context: String, listener: String, claim_id: String = "") -> Array:
	## [index, excuse_id] of the best option that is NOT legitimate work.
	var best := -1
	var best_v := -INF
	var best_ex := ""
	var told := Game.deception.claim(claim_id)
	for i in list.size():
		var c: Dictionary = list[i]
		var act := str(c.get("a", "ack"))
		if Game.work.is_work(act):
			continue
		var view := Game.comms.choice_view(c, context, listener)
		if not view.ok:
			continue
		if bool(c.get("excuse", false)):
			for e in Game.deception.options(context, listener):
				if bool(e.burned) or str(e.conflict) != "" or not _sustainable(str(e.id)):
					continue
				var p := float(e.chance) / 100.0
				var ev := p * 2.0 + (1.0 - p) * -6.0 - 1.0 - float(e.uses) * 1.5
				if ev > best_v:
					best_v = ev
					best = i
					best_ex = str(e.id)
			continue
		var v := 0.0
		if c.has("match"):
			v = _val(c.get("ok", {})) if told != null and told.subject == str(c.match) else _val(c.get("ko", {}))
		elif float(view.odds) >= 0.0:
			var p := float(view.odds) / 100.0
			v = p * _val(c.get("ok", {})) + (1.0 - p) * _val(c.get("ko", c.get("ok", {})))
		else:
			v = _val(c.get("ok", {}))
		if Game.work.cls_of(act) == WorkSystem.Cls.STRESS:
			v -= Game.work.hp_cost(act) * 0.6
		if v > best_v:
			best_v = v
			best = i
			best_ex = ""
	return [best, best_ex]


func _scan_soon() -> bool:
	## A scan the player was warned about is coming up.
	for e in Game.time.timers:
		if str(e.ev) == "event" and str(e.args.get("id", "")) == "audit_scan" and int(e.at) - Game.time.now() <= 30 and int(e.at) >= Game.time.now():
			return true
	return false


func _bot_slacker() -> void:
	## A competent work-avoider. Never does legitimate work.
	if _evening():
		if Game.time.phase == "evening":
			_slacker_evening()
		return
	var c := Game.comms
	var auto := Game.automation
	var now := Game.time.now()
	var minute := int(Game.time.minute)
	if c.in_call():
		var beat := c.call_beat()
		var pick := _best_choice(c.call_choices(), c.call_context(), str(beat.get("who", t.boss())))
		if int(pick[0]) < 0:
			c.call_timeout()
		else:
			c.call_choose(int(pick[0]), str(pick[1]))
		return
	var ring := c.ringing()
	if not ring.is_empty() and _ghost and bool(ring.get("casual", false)):
		ring = {}                         # let it ring
	if not ring.is_empty():
		Game.activities.stop()
		Game.presence.set_at_desk(true)
		if c.can_dodge(ring) and c.conflicts(ring):
			c.decline_conflict(str(ring.id))
		elif c.can_send_clone(ring) == "":
			c.send_clone(str(ring.id))
		if str(ring.state) == "ringing":
			# On camera unless a story says the camera is broken.
			c.join(str(ring.id), "video_meeting" in Game.deception.forbidden_now())
		return
	# Answer whatever is pending, most urgent first.
	var pending := c.pending()
	if _ghost:
		pending = pending.filter(func(q): return not Game.social.is_colleague(str(q.from)))
	if not pending.is_empty():
		var p: Dictionary = pending[0]
		if not Game.activities.busy() or int(p.due) - now <= 6:
			Game.activities.stop()
			Game.presence.set_at_desk(true)
			var pick := _best_choice(c.choices_of(p), "chat", str(p.from), str(p.claim))
			if int(pick[0]) >= 0:
				c.answer(str(p.id), int(pick[0]), str(pick[1]), "desk")
			return
	if Game.activities.busy():
		return
	var th := Game.home.things
	# Self-care.
	if minute >= 720 and minute < 760 and not bool(th.lunch):
		Game.presence.set_at_desk(false)
		Game.home.use("table", "lunch")
		return
	if Game.stats.get_value("energy") < 30.0:
		Game.presence.set_at_desk(false)
		for pair in [["microwave", "burrito"], ["fridge", "snack"], ["coffee", "brew"], ["bed", "power_nap"]]:
			if Game.home.use(str(pair[0]), str(pair[1])):
				return
		return
	if Game.stats.get_value("health") < 50.0:
		Game.presence.set_at_desk(false)
		Game.home.use("console", "console")
		return
	# The point of the job: when the coast is clear, go and do nothing.
	var nerve := 40.0 - 36.0 * (float(Game.diff().susp) - 1.0)
	var safe := Game.stats.get_value("susp") < nerve and Game.stats.get_value("ill") > 52.0
	var covered: bool = auto.can("presence") or Game.presence.covered() or Game.presence.status in ["lunch", "updating", "busy", "meeting"]
	var nm0 := c.next_meeting()
	var clear := nm0.is_empty() or int(nm0.start) - minute > 50
	if safe and not covered and clear and not _ghost and minute < 930 and now - _last_slack >= 20:
		# Nobody is covering: ask a friend to.
		for who in Game.social.who_can("cover"):
			if Game.social.ask_type(str(who), "cover"):
				covered = true
				break
	if safe and covered and clear and not _scan_soon() and minute < 960 and now - _last_slack >= 20:
		Game.presence.set_at_desk(false)
		_last_slack = now + 45
		Game.home.use("console", "console")
		return
	# Desk chores.
	Game.presence.set_at_desk(true)
	if Game.home.outfit != "shirt":
		Game.home.use("wardrobe", "wear_shirt")
	if auto.any_broken() or auto.max_wear() > 28.0:
		auto.maintain()
		return
	var scan := _scan_soon()
	for id in auto.gadgets:
		if auto.owns(id) and not bool(auto.g(id).broken):
			if bool(auto.g(id).on) == scan:
				auto.toggle(id)
	if auto.can("auto_report") and int(auto.autos.report_at) < 0:
		auto.set_report_time(600)
	if minute >= 600 and not Game.work.report_sent() and not auto.can("auto_report"):
		Game.work.fake_report(false)
		return
	# Keep the colleagues warm.
	if not _ghost and Game.stats.get_value("energy") > 55.0 and minute > 560:
		for who in Game.social.colleagues():
			if not Game.social.talked_today(str(who)) and Game.comms.prompt_for_thread(str(who)).is_empty():
				Game.social.small_talk(str(who))
				return
	# The Tuesday trick: block the calendar over an optional meeting.
	var nm := c.next_meeting()
	if not nm.is_empty() and not bool(nm.mandatory) and not bool(nm.no_dodge) and not c.conflicts(nm) and int(nm.start) - minute <= 60 and int(nm.start) > minute:
		if c.add_block(int(nm.start), 30):
			return
	for task in Game.work.open_tasks():
		if str(task.by) != "":
			continue
		var id := str(task.id)
		if not _ghost and Game.economy.favors > 0 and int(task.effort) >= 2 and Game.work.task_delegate(id):
			return
		if auto.can("do_tickets") and str(auto.autos.ai_task) == "" and Game.work.task_ai(id):
			return
		# Paper trail first, then the story it backs up.
		if not bool(task.clarified) and str(task.blocked) == "" and int(task.due) - now < 240 and float(task.fake) < 60.0:
			if Game.work.task_clarify(id):
				return
		if bool(task.clarified) and str(task.blocked) == "" and int(task.due) - now < 200 and float(task.fake) < 60.0 and Game.deception.conflict_with("waiting_team", t.boss()) == null:
			if Game.work.task_block(id, "waiting_team").get("done", false):
				return
		if str(task.blocked) != "" and Game.deception.live(str(task.blocked)) != null:
			continue          # officially blocked: touching it would contradict the story
		if not Game.work.task_looks_done(task) and Game.stats.get_value("energy") > 38.0 and now - _last_fake >= 22:
			if Game.work.task_fake(id):
				_last_fake = now
				return
	if Game.stats.get_value("ill") < 60.0 and Game.stats.get_value("energy") > 45.0 and now - _last_react >= 25 and not "social_post" in Game.deception.forbidden_now():
		for thread in ["team", "general"]:
			if c.react(thread):
				_last_react = now
				return


func _slacker_evening() -> void:
	if Game.activities.busy():
		return
	var auto := Game.automation
	# Buy first, then upgrade what breaks most.
	for id in ["mousemover", "chatbot", "duck", "assistant", "doppelganger"]:
		if not auto.owns(id) and auto.unlocked(id) and Game.economy.can_afford(auto.price(id)):
			auto.buy(id)
	for id in ["mousemover", "chatbot", "duck", "assistant", "doppelganger"]:
		if auto.can_upgrade(id) and Game.economy.can_afford(auto.price(id) + 150):
			auto.buy(id)
	if Game.time.minute < 1290.0:
		if Game.stats.get_value("energy") < 60.0 and Game.home.use("microwave", "burrito"):
			return
		if Game.stats.get_value("health") < 92.0:
			Game.home.use("console", "console")
			return
	Game.home.use("bed", "sleep")


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
	Game.stats.changed.connect(_on_stat)
	var days: Array = []
	for d in 5:
		days.append({"n": 0, "susp": 0.0, "ill": 0.0, "en": 0.0, "hp": 0.0, "absent": 0.0, "exc": 0.0, "avoid": 0.0, "missed": 0.0, "slack": 0.0})
	Game.workday_ended.connect(func(rep: Dictionary):
		var d: Dictionary = days[int(rep.day)]
		d.n += 1
		d.susp += Game.stats.get_value("susp")
		d.ill += float(rep.ill)
		d.en += Game.stats.get_value("energy")
		d.hp += float(rep.health)
		d.absent += float(rep.absent_min)
		d.exc += float(rep.excuses)
		d.avoid += float(rep.meetings_avoided)
		d.missed += float(rep.meetings_missed)
		d.slack += float(rep.slack_min)
	)
	var wins := 0
	var week := {}
	var statuses := {}
	var fired := {}
	for i in runs:
		var r := _run(bot, diff, 1000 + i * 7919)
		if bool(r.won):
			wins += 1
		for k in r.week:
			week[k] = float(week.get(k, 0.0)) + float(r.week[k])
		for c in Game.deception.claims:
			var key := "%s:%s" % [c.type, c.status]
			statuses[key] = int(statuses.get(key, 0)) + 1
		for id in Game.events.count:
			fired[id] = int(fired.get(id, 0)) + int(Game.events.count[id])
		for id in Game.social.colleagues():
			_rel[id] = float(_rel.get(id, 0.0)) + Game.npcs.relationship(id)
	print("TRACE %s/%s: %d/%d wins" % [bot, diff, wins, runs])
	print("  day  runs  susp   ill    en    hp  absent  excuses  avoided  missed  slack")
	for d in 5:
		var x: Dictionary = days[d]
		var n: float = maxf(1.0, float(x.n))
		print("  %s  %4d  %4.0f  %4.0f  %4.0f  %4.0f  %6.0f  %7.1f  %7.1f  %6.1f  %5.0f" % [Cfg.DAYS_SHORT[d], int(x.n), x.susp / n, x.ill / n, x.en / n, x.hp / n, x.absent / n, x.exc / n, x.avoid / n, x.missed / n, x.slack / n])
	var keys: Array = _why.keys()
	keys.sort_custom(func(a, b): return absf(float(_why[a])) > absf(float(_why[b])))
	print("  per-run totals by cause:")
	for k in keys.slice(0, 22):
		print("    %7.1f  %s" % [float(_why[k]) / float(runs), k])
	var parts: Array = []
	for k in ["excuses", "excuses_failed", "contradictions", "lies_landed", "prompts_answered", "prompts_ignored", "tasks_done", "tasks_faked", "tasks_delegated", "tasks_failed", "auto_runs", "auto_ok", "slack_min", "absent_min"]:
		parts.append("%s=%.1f" % [k, float(week.get(k, 0.0)) / float(runs)])
	print("  week avg: ", ", ".join(parts))
	var social: Array = []
	for k in ["calls_taken", "calls_dodged", "colleagues_ignored", "snitched", "favours_called", "small_talk", "gifts", "tipoffs", "tasks_lost", "susp_gained"]:
		social.append("%s=%.1f" % [k, float(week.get(k, 0.0)) / float(runs)])
	print("  colleagues: ", ", ".join(social))
	var ends: Array = []
	for id in _rel:
		ends.append("%s=%.0f" % [id, float(_rel[id]) / float(runs)])
	print("  relationship at the end: ", ", ".join(ends))
	print("  claims: ", statuses)
	var ids: Array = fired.keys()
	ids.sort_custom(func(a, b): return int(fired[a]) > int(fired[b]))
	var top: Array = []
	for id in ids.slice(0, 24):
		top.append("%s=%.1f" % [id, float(fired[id]) / float(runs)])
	var calls: Array = []
	for id in ids:
		if str(Db.events[id].kind) == "call":
			calls.append("%s=%.2f" % [id, float(fired[id]) / float(runs)])
	print("  calls per run: ", ", ".join(calls))
	print("  events per run: ", ", ".join(top))
	print("  invariant violations: ", _violations)
