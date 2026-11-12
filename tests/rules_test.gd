extends Node
## Headless rules tests: every gameplay invariant from the spec's testing
## list, run against the simulation core with no scenes and no rendering.
##
##   godot --headless --path . res://tests/rules_test.tscn [-- --verbose]

var t := TestSuite.new()


func _ready() -> void:
	t.verbose = "--verbose" in OS.get_cmdline_user_args()
	Game.saves.enabled = false
	Game.saves.dir = "user://test_saves"
	Prefs.persist = false
	Game.time.manual = true
	_content()
	_resources()
	_stats()
	_work()
	_deception()
	_claim_categories()
	_gadgets()
	_gadget_failures()
	_combos()
	_events()
	_pacing()
	_npcs()
	_colleague_content()
	_colleague_rules()
	_colleague_favours()
	_colleague_calls()
	_junk_food()
	_economy()
	_save_load()
	_day_flow()
	Game.clear_run()
	print("")
	print("%d checks, %d failed" % [t.checks, t.fails])
	print("RESULT: %s" % ("FAIL" if t.fails > 0 else "PASS"))
	get_tree().quit(1 if t.fails > 0 else 0)


# ---------------------------------------------------------------------------
# Static content
# ---------------------------------------------------------------------------

func _check_choices(list: Array, where: String) -> void:
	t.check(not list.is_empty(), "%s has choices" % where)
	var safe := false
	for c in list:
		var act := str(c.get("a", "ack"))
		t.check(WorkSystem.DEFS.has(act), "%s: action '%s' is declared" % [where, act])
		if not Game.work.is_work(act):
			safe = true
		for key in ["ok", "ko"]:
			var out: Dictionary = c.get(key, {})
			if out.has("task"):
				t.check(Db.tasks.has(str(out.task)), "%s: ticket '%s' exists" % [where, str(out.task)])
			if out.has("claim"):
				t.check(Db.claims.has(str(out.claim)), "%s: claim '%s' exists" % [where, str(out.claim)])
			for k in ["event", "later"]:
				if out.has(k):
					var eid := str(out[k]) if k == "event" else str(out[k].ev)
					t.check(Db.events.has(eid), "%s: follow-up event '%s' exists" % [where, eid])
		if c.has("p"):
			t.check(float(c.p) > 0.0 and float(c.p) <= 100.0, "%s: sane base chance" % where)
	t.check(safe, "%s can be answered without doing real work" % where)


func _content() -> void:
	t.section("content integrity")
	t.check(Db.errors.is_empty(), "every resource loads (%s)" % str(Db.errors))
	t.check(Db.claims.size() >= 10, "at least 10 deception categories (%d)" % Db.claims.size())
	t.check(Db.gadgets.size() >= 5, "at least 5 gadgets (%d)" % Db.gadgets.size())
	t.check(Home.THINGS.size() >= 20, "at least 20 interactive objects (%d)" % Home.THINGS.size())
	for id in ["internet_outage", "computer_crash", "medical", "family_emergency", "conflicting_meeting", "prod_incident", "data_validation", "waiting_team", "process_blocker", "hardware_malfunction"]:
		t.check(Db.claims.has(id), "claim category '%s' exists" % id)
	for id in ["mousemover", "duck", "chatbot", "assistant", "doppelganger"]:
		t.check(Db.gadgets.has(id), "gadget '%s' exists" % id)
	for id in Db.events:
		var e: Dictionary = Db.events[id]
		if str(e.kind) in ["chat", "mail"] and not e.choices.is_empty():
			_check_choices(e.choices, "event:%s" % id)
		if str(e.kind) in ["chat", "say", "call", "meeting", "mail"]:
			t.check(Db.npcs.has(str(e.from)), "event:%s sender '%s' exists" % [id, str(e.from)])
		if str(e.kind) == "task":
			t.check(Db.tasks.has(str(e.task)), "event:%s ticket exists" % id)
		if str(e.kind) == "system":
			t.check(Game.events.has_method("_sys_" + str(e.action)), "event:%s action '%s' is implemented" % [id, str(e.action)])
		if str(e.kind) in ["meeting", "call"]:
			var script := str(e.meeting.script)
			t.check(script == "review" or Db.dialogues.has(script), "event:%s dialogue '%s' exists" % [id, script])
	for id in Db.dialogues:
		var d: Dictionary = Db.dialogues[id]
		for i in d.beats.size():
			_check_choices(d.beats[i].choices, "dialogue:%s#%d" % [id, i])
			t.check(Db.npcs.has(str(d.beats[i].who)), "dialogue:%s speaker exists" % id)
		for k in d.pool:
			t.check(Db.dialogues.has(str(k)), "dialogue:%s pool entry '%s' exists" % [id, str(k)])
	for id in Db.claims:
		var c: Dictionary = Db.claims[id]
		_check_choices(c.recoveries, "claim:%s recoveries" % id)
		t.check(str(c.strength) != "" and str(c.weakness) != "", "claim:%s documents a strength and a weakness" % id)
		for f in c.contradicted_by:
			t.check(DeceptionManager.FACTS.has(str(f)), "claim:%s fact '%s' is known" % [id, str(f)])
		for f in c.followups:
			if str(f.kind) == "event":
				t.check(Db.events.has(str(f.event)), "claim:%s follow-up event '%s' exists" % [id, str(f.event)])
		for other in c.conflicts:
			t.check(Db.claims.has(str(other)), "claim:%s conflict '%s' exists" % [id, str(other)])
	for id in Db.gadgets:
		var g: Dictionary = Db.gadgets[id]
		t.check(g.levels.size() >= 2, "gadget:%s has upgrade levels" % id)
		t.check(str(g.fail_event) != "" and Db.events.has(str(g.fail_event)), "gadget:%s has a failure event" % id)
		for lv in g.levels:
			t.check(lv.has("price") and lv.has("reliability") and lv.has("heat") and lv.has("can"), "gadget:%s level defines cost, reliability, risk, effects" % id)
	for id in Db.combos:
		for need in Db.combos[id].needs:
			t.check(Db.gadgets.has(str(need)), "combo:%s part '%s' exists" % [id, str(need)])
	for id in Home.TIMED:
		t.check(Home.THINGS.has(str(Home.TIMED[id].thing)), "activity '%s' is attached to a real object" % id)
	# The ten events the design calls for.
	for id in ["quick_q", "standup", "urgent_task", "screen_share", "vpn_trouble", "mousemover_detected", "surprise_call", "productivity_audit", "skip_level", "review"]:
		t.check(Db.events.has(id), "required event '%s' exists" % id)


func _resources() -> void:
	t.section("scenes and resource references")
	var n := 0
	for path in _scan("res://resources", ".tres") + _scan("res://scenes", ".tscn"):
		n += 1
		t.check(ResourceLoader.exists(path) and load(path) != null, "loads: %s" % path)
	t.check(n > 100, "found the resource and scene files (%d)" % n)
	for path in _scan("res://scenes", ".tscn"):
		var inst: Node = (load(path) as PackedScene).instantiate()
		t.check(inst != null and inst.get_script() != null, "instantiates with its script: %s" % path)
		inst.free()
	for sfx in ["click", "ping", "boss", "ring", "good", "bad", "gadget_on", "gadget_fail", "win", "fired", "amb_day", "amb_night", "music_day"]:
		t.check(ResourceLoader.exists("res://assets/audio/%s.wav" % sfx), "audio cue '%s' exists" % sfx)


func _scan(dir: String, ext: String) -> Array:
	var out: Array = []
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with("/"):
			out.append_array(_scan(dir + "/" + f.trim_suffix("/"), ext))
		elif f.ends_with(ext):
			out.append(dir + "/" + f)
	return out


# ---------------------------------------------------------------------------
# PlayerStats
# ---------------------------------------------------------------------------

func _stats() -> void:
	t.section("player stats")
	t.run()
	var s := Game.stats
	s.add("health", 500.0, "test")
	t.near(s.get_value("health"), 100.0, "health cannot exceed 100")
	s.add("energy", 500.0, "test")
	t.near(s.get_value("energy"), 100.0, "energy cannot exceed 100")
	s.add("energy", -500.0, "test")
	t.near(s.get_value("energy"), 0.0, "energy cannot go below 0")
	s.add("ill", 500.0, "test")
	t.check(s.get_value("ill") <= 100.0, "illusion is clamped at 100")
	s.add("susp", -500.0, "test")
	t.near(s.get_value("susp"), 0.0, "suspicion is clamped at 0")
	s.add("susp", 60.0, "test")
	t.near(s.get_value("susp"), 60.0, "suspicion adds up on Survivor")
	s.add("susp", 500.0, "test")
	t.near(s.get_value("susp"), 100.0, "suspicion is clamped at 100")
	t.check(Game.time.phase == "over" and str(Game.result.kind) == "fired", "suspicion 100 = fired")
	t.check(is_zero_approx(s.add("susp", -10.0, "test")), "stats are frozen once the run is over")
	t.run()
	s.add("health", -500.0, "test")
	t.near(s.get_value("health"), 0.0, "health is clamped at 0")
	t.check(Game.time.phase == "over" and str(Game.result.kind) == "burnout", "health 0 = burnout")
	t.run("senior")
	var before := s.get_value("susp")
	s.add("susp", 10.0, "test")
	t.near(s.get_value("susp") - before, 17.0, "Senior Bullshitter: suspicion gains are x1.7")
	s.add("susp", -5.0, "test")
	t.near(s.get_value("susp") - before, 12.0, "the multiplier does not apply to suspicion relief")
	t.run()
	var heard := []
	var cb := func(stat: String, _v: float, delta: float, _r: String): heard.append([stat, delta])
	s.changed.connect(cb)
	s.add("energy", -5.0, "test")
	s.changed.disconnect(cb)
	t.check(heard.size() == 1 and heard[0][0] == "energy", "changes are announced by signal")
	s.add_buff("jargon", 30)
	t.check(s.has_buff("jargon"), "a buff can be added")
	Game.time.advance(31)
	t.check(not s.has_buff("jargon"), "buffs expire")


# ---------------------------------------------------------------------------
# WorkSystem
# ---------------------------------------------------------------------------

func _work() -> void:
	t.section("work classification")
	var w := Game.work
	t.check(w.is_work("write_report"), "writing a real report is work")
	t.check(not w.is_work("fake_report"), "generating a fake report is not work")
	t.check(w.is_work("fix_bug"), "fixing the actual bug is work")
	t.check(not w.is_work("pretend_investigate"), "pretending to investigate is not work")
	t.check(w.is_work("work_task"), "completing a legitimate task is work")
	t.check(not w.is_work("delegate_ai"), "delegating to the AI clone is not work")
	# Extreme: every legitimate-work action is an instant defeat, and nothing else is.
	for id in WorkSystem.DEFS:
		t.run("unemployed", 7)
		Game.stats.values.energy = 100.0
		var alive := w.perform(id, {})
		var over := Game.time.phase == "over"
		if w.is_work(id):
			t.check(over and not alive and str(Game.result.kind) == "worked", "Extreme: '%s' ends the run at once" % id)
		else:
			t.check(not over and alive, "Extreme: '%s' is allowed" % id)
	# Penalties vary by difficulty.
	var seen := {}
	for pair in [["intern", 2.0], ["survivor", 8.0], ["senior", 20.0]]:
		t.run(str(pair[0]), 7)
		Game.stats.values.health = 100.0
		w.perform("work_task", {})
		var lost := 100.0 - Game.stats.get_value("health")
		seen[lost] = true
		t.near(lost, float(pair[1]), "%s: one work action costs %d HP" % [pair[0], int(pair[1])])
		t.check(int(Game.today.worked_min) > 0, "%s: worked minutes are logged" % pair[0])
		Game.stats.values.health = 100.0
		w.perform("fake_report", {})
		t.near(Game.stats.get_value("health"), 100.0, "%s: fake work costs no health" % pair[0])
	t.check(seen.size() == 3, "work penalties differ between difficulties")
	t.run("unemployed", 7)
	t.check(w.lethal("work_task") and bool(w.badge("work_task").warn), "Extreme: work is flagged as lethal in the UI")
	t.check(str(w.badge("work_task").text).contains("ENDS YOUR RUN"), "Extreme: the badge says so")
	# Tickets: fake progress never becomes real progress.
	t.run("unemployed", 3)
	t.at_work()
	Game.presence.set_at_desk(true)
	var task := w.add_task("button")
	for i in 6:
		Game.stats.values.energy = 100.0
		w.task_fake(str(task.id))
	t.check(int(task.real) == 0 and float(task.fake) >= 100.0 and Game.time.running(), "fake updates fill the bar with no real work")
	t.check(int(Game.week.worked_min) == 0, "fake updates log zero worked minutes")
	# A deadline with nothing to show fails the ticket.
	t.run("survivor", 3)
	t.at_work()
	var t2 := w.add_task("button")
	t2.due = Game.time.now() + 3
	var susp := Game.stats.get_value("susp")
	Game.time.advance(5)
	t.check(str(t2.status) == "failed" and Game.stats.get_value("susp") > susp, "a missed deadline fails the ticket and raises suspicion")


# ---------------------------------------------------------------------------
# DeceptionManager
# ---------------------------------------------------------------------------

func _tell(type: String, context: String = "chat") -> Claim:
	## Tell a lie that is certain to be believed.
	var res := Game.deception.attempt(type, context, t.boss(), "test", "", true)
	return res.claim


func _deception() -> void:
	t.section("deception: claims and contradictions")
	var d := Game.deception
	# The example from the design: internet down at 10:00, online meeting at 10:15.
	t.run("survivor", 11)
	t.at_work(600)
	Game.home.use("router", "off")
	var c := _tell("internet_outage")
	t.check(c != null and c.status == Claim.ACTIVE, "a believed lie becomes an active claim")
	t.check(c.id != "" and c.type == "internet_outage" and c.made_at == Game.time.now(), "claim has an id, a type and a timestamp")
	t.check(c.expires_at == c.made_at + 60, "claim has an expiration")
	t.check(t.boss() in c.witnesses, "claim records who heard it")
	t.check("video_meeting" in c.contradicted_by, "claim lists its contradicting actions")
	t.check("router_off" in c.evidence, "claim records its supporting evidence")
	t.check(c.risk > 0, "claim has an associated risk")
	t.check(d.claims.size() == 1 and d.claim(c.id) == c, "the claim is in the central ledger")
	t.check(Game.npcs.knows(t.boss(), c.id), "the manager remembers the claim")
	t.check(Game.presence.covered(), "an accepted story explains your absence")
	Game.home.use("router", "on")
	Game.time.advance(15)
	t.check(c.status == Claim.CONTRADICTED and c.contradiction == "router_on", "IT pings the router: story contradicted")
	t.run("survivor", 11)
	t.at_work(600)
	Game.home.use("router", "off")
	c = _tell("internet_outage")
	Game.home.things.router_on = true
	Game.time.minute = 615.0
	var susp := Game.stats.get_value("susp")
	var contradictions := int(Game.week.contradictions)
	d.observe("video_meeting")
	t.check(c.status == Claim.CONTRADICTED and c.contradiction == "video_meeting", "joining an online meeting contradicts 'internet outage'")
	t.check(Game.stats.get_value("susp") > susp, "the contradiction raises suspicion")
	t.check(int(Game.week.contradictions) == contradictions + 1, "the contradiction is counted")
	t.check(not Game.presence.covered(), "the cover story ends with it")
	t.check(not Game.time.pending("claim_confront").is_empty(), "a follow-up confrontation is scheduled")
	Game.time.advance(8)
	var p := Game.comms.prompt_for_thread(t.boss())
	t.check(not p.is_empty() and str(p.text).contains("internet"), "the manager asks: 'I thought your internet wasn't working?'")
	t.check(str(p.claim) == c.id and p.choices.size() >= 2, "the player must explain, with several ways to try")
	# Talking your way out (forced success), or not.
	var ok_choice := -1
	for i in p.choices.size():
		if p.choices[i].get("ok", {}).get("claim_status", "") == "patched":
			ok_choice = i
	t.check(ok_choice >= 0, "one of the explanations can patch the story")
	Game.stats.values.susp = 0.0
	Game.stats.values.ill = 100.0
	var tries := 0
	while c.status == Claim.CONTRADICTED and tries < 1:
		tries += 1
		Game.comms.answer(str(p.id), p.choices.size() - 1)        # "Come clean"
	t.check(c.status == Claim.EXPOSED, "coming clean ends the story as exposed")
	# Facts that a claim does not forbid are harmless.
	t.run("survivor", 12)
	t.at_work(600)
	Game.home.use("router", "off")
	c = _tell("internet_outage")
	Game.time.advance(3)
	d.observe("phone_message")
	d.observe("phone_meeting")
	t.check(c.status == Claim.ACTIVE, "answering from the phone does not contradict an outage")
	# Expiry.
	t.run("survivor", 13)
	t.at_work(600)
	c = _tell("data_validation")
	var landed := int(Game.week.lies_landed)
	Game.presence.set_at_desk(true)
	Game.time.advance(int(Db.claims["data_validation"].duration) - 1)
	t.check(c.is_live(Game.time.now()), "a claim is live until it expires")
	Game.time.advance(2)
	t.check(c.status == Claim.EXPIRED and not c.is_live(Game.time.now()), "claims expire on time")
	t.check(int(Game.week.lies_landed) == landed + 1, "a claim that expires unchallenged counts as a successful deception")
	d.observe("desk_message")
	t.check(c.status == Claim.EXPIRED, "facts cannot contradict an expired claim")
	# Reuse wears a story out.
	t.run("survivor", 14)
	t.at_work(600)
	var c0 := d.claim_chance("family_emergency", "chat", t.boss())
	_tell("family_emergency")
	var c1 := d.claim_chance("family_emergency", "chat", t.boss())
	t.check(c1 < c0, "reusing a story makes it less believable (%.0f%% -> %.0f%%)" % [c0, c1])
	_tell("family_emergency")
	_tell("family_emergency")
	var res := d.attempt("family_emergency", "chat", t.boss(), "test", "", true)
	t.check(bool(res.contradiction) and (res.claim as Claim).status == Claim.EXPOSED, "a fourth use of the same story backfires on its own")
	# Contradictory excuses.
	t.run("survivor", 15)
	t.at_work(600)
	_tell("medical")
	res = d.attempt("prod_incident", "chat", t.boss(), "test", "", true)
	t.check(bool(res.contradiction), "claiming a production incident while 'at the doctor' is caught at once")
	# Evidence.
	t.run("survivor", 16)
	t.at_work(600)
	var bare := d.claim_chance("internet_outage", "chat", t.boss())
	Game.home.use("router", "off")
	t.check(d.claim_chance("internet_outage", "chat", t.boss()) > bare, "supporting evidence makes a lie more believable")
	# The manager's knowledge persists across days, and across save/load.
	c = _tell("conflicting_meeting")
	var saved := Game.save_state()
	t.run("intern", 99)
	t.check(Game.load_state(saved), "state loads")
	t.check(d.claims.size() == 1 and d.claims[0].type == "conflicting_meeting" and Game.npcs.knows(t.boss(), d.claims[0].id), "the ledger and NPC knowledge survive save/load")


func _claim_categories() -> void:
	t.section("deception: every category")
	var d := Game.deception
	for type in Db.claims:
		var def: Dictionary = Db.claims[type]
		t.run("survivor", 21)
		t.at_work(600)
		var c := _tell(type, "chat")
		t.check(c != null and c.status == Claim.ACTIVE, "%s: can be told" % type)
		# Each forbidden fact really does expose it.
		for fact in def.contradicted_by:
			t.run("survivor", 21)
			t.at_work(600)
			c = _tell(type, "chat")
			Game.time.minute = 600.0 + 12.0
			if str(fact) in ["router_on", "calendar_free", "no_incident", "team_denies", "no_form"]:
				t.check(d.fact_holds(str(fact), c), "%s: '%s' is true when nobody prepared for it" % [type, str(fact)])
				continue
			d.observe(str(fact))
			t.check(c.status == Claim.CONTRADICTED, "%s: contradicted by %s" % [type, str(fact)])
		# With its evidence in place, a check-up confirms the story instead.
		for f in def.followups:
			if str(f.kind) != "verify":
				continue
			t.run("survivor", 22)
			t.at_work(600)
			match str(f.fact):
				"router_on":
					Game.home.use("router", "off")
				"calendar_free":
					Game.comms.add_block(600, 30)
				"no_incident":
					Game.flags["incident_until"] = Game.time.now() + 60
				"team_denies":
					var tk := Game.work.add_task("pipeline")
					Game.work.task_clarify(str(tk.id))
				"no_form":
					Game.set_flag("cr_day_0")
			c = _tell(type, "chat")
			t.check(not c.evidence.is_empty(), "%s: evidence is recorded" % type)
			t.check(not d.fact_holds(str(f.fact), c), "%s: with evidence, '%s' is false" % [type, str(f.fact)])
	# Subjects: the player has to remember what they said.
	t.run("survivor", 23)
	t.at_work(600)
	var fam := _tell("family_emergency")
	t.check(fam.subject in Db.claims["family_emergency"].subjects, "family emergency records who it was about")
	Game.events.fire("family_checkin", {"claim": fam.id, "subject": fam.subject, "urgent": true})
	var p := Game.comms.prompt_for_thread(t.boss())
	t.check(not p.is_empty(), "the manager asks about your relative later")
	var wrong := -1
	for i in p.choices.size():
		if str(p.choices[i].get("match", "")) != fam.subject:
			wrong = i
	Game.comms.answer(str(p.id), wrong)
	t.check(fam.status == Claim.EXPOSED, "naming the wrong relative exposes the story")


# ---------------------------------------------------------------------------
# AutomationManager
# ---------------------------------------------------------------------------

func _own(id: String, level: int = 1, on: bool = true) -> void:
	Game.automation.gadgets[id].level = level
	Game.automation.gadgets[id].on = on
	Game.automation.gadgets[id].broken = false
	Game.automation.gadgets[id].wear = 0.0


func _gadgets() -> void:
	t.section("gadgets")
	var a := Game.automation
	t.run("survivor", 31)
	Game.economy.money = 5000
	t.check(not a.unlocked("mousemover") and not a.buy("mousemover"), "MouseMover is not for sale on Monday")
	Game.time.day = 1
	t.check(a.unlocked("mousemover"), "MouseMover unlocks on Tuesday")
	var cash := Game.economy.money
	t.check(a.buy("mousemover") and a.owns("mousemover") and a.level("mousemover") == 1, "a gadget can be bought")
	t.check(Game.economy.money == cash - a.price("mousemover", 1), "buying costs its price")
	t.check(not a.working("mousemover") and not a.can("presence"), "a new gadget is off")
	t.at_work(600)
	Game.time.advance(Cfg.IDLE_LIMIT + 3)
	t.check(Game.presence.status == "away", "without it, an empty desk shows Away")
	t.check(a.toggle("mousemover") and a.working("mousemover") and a.can("presence"), "a gadget can be activated")
	t.check(Game.presence.status == "online", "MouseMover keeps the status Available")
	t.check(a.heat() > 0.0, "a running gadget generates detection heat")
	t.check(a.toggle("mousemover") and not a.working("mousemover"), "a gadget can be deactivated")
	t.check(Game.presence.status == "away" and is_zero_approx(a.heat()), "switched off: Away again, no heat")
	# Upgrades.
	var r1 := a.reliability("mousemover")
	t.check(a.can_upgrade("mousemover") and a.buy("mousemover") and a.level("mousemover") == 2, "a gadget can be upgraded")
	t.check(a.reliability("mousemover") > r1, "upgrades improve reliability")
	a.buy("mousemover")
	t.check(a.level("mousemover") == 3 and not a.can_upgrade("mousemover") and not a.buy("mousemover"), "upgrades stop at the top level")
	t.check("pass_scan" in a.abilities("mousemover"), "higher levels unlock new abilities")
	# Unlock conditions.
	Game.time.day = 4
	t.check(not a.unlocked("doppelganger") and a.locked_reason("doppelganger") != "", "the Doppelganger needs its prerequisites")
	a.buy("chatbot")
	a.buy("assistant")
	t.check(a.unlocked("doppelganger") and a.buy("doppelganger"), "owning Chatbot Team and Meeting Assistant unlocks it")
	# Wear.
	t.run("survivor", 32)
	t.at_work(600)
	_own("duck")
	var f0 := a.fail_chance("duck")
	a.gadgets["duck"].wear = 80.0
	t.check(a.fail_chance("duck") > f0 * 4.0, "worn gadgets fail far more often")
	a.service()
	t.check(is_zero_approx(float(a.gadgets["duck"].wear)), "servicing resets wear")
	# Passive effect.
	var ill := Game.stats.get_value("ill")
	Game.presence.set_at_desk(true)
	Game.time.advance(30)
	var with_duck := Game.stats.get_value("ill") - ill
	t.run("survivor", 32)
	t.at_work(600)
	Game.presence.set_at_desk(true)
	ill = Game.stats.get_value("ill")
	Game.time.advance(30)
	t.check(with_duck > Game.stats.get_value("ill") - ill, "the Keyboard Duck raises Productivity Illusion over time")
	# Chatbot answers routine messages.
	t.run("survivor", 33)
	t.at_work(600)
	_own("chatbot")
	Game.events.fire("quick_q", {"urgent": true})
	t.check(Game.comms.prompts.size() == 1, "a routine ping arrives")
	Game.time.advance(30)
	t.check(Game.comms.prompts.is_empty() and int(Game.today.prompts_ignored) == 0, "Chatbot Team answered it")
	# Meeting Assistant.
	t.run("survivor", 34)
	t.at_work(569)
	Game.comms.add_meeting({"title": "Daily Standup", "start": 570, "dur": 15, "script": "standup", "mandatory": true})
	_own("assistant")
	Game.time.advance(2)
	var m := Game.comms.ringing()
	Game.comms.join(str(m.id), true)
	var has_option := false
	for c in Game.comms.call_choices():
		if str(c.get("ability", "")) == "meeting_answers":
			has_option = true
	t.check(has_option, "the Meeting Assistant offers to answer in meetings")
	# A clone attends optional meetings.
	t.run("survivor", 35)
	t.at_work(835)
	var plan := Game.comms.add_meeting({"title": "Sprint Planning", "start": 840, "dur": 50, "script": "planning", "mandatory": false})
	_own("doppelganger")
	Game.time.advance(8)
	t.check(str(plan.state) == "looped" and int(Game.today.meetings_avoided) == 1, "the AI Doppelganger attends an optional meeting for you")


func _gadget_failures() -> void:
	t.section("gadget failures")
	var a := Game.automation
	for id in Db.gadgets:
		t.run("survivor", 41)
		t.at_work(700)
		Game.presence.set_at_desk(true)
		_own(id)
		var ill := Game.stats.get_value("ill")
		a.fail(id)
		t.check(bool(a.gadgets[id].broken) and not a.working(id), "%s: a failure breaks it" % id)
		t.check(Game.stats.get_value("ill") < ill, "%s: a failure costs Productivity Illusion" % id)
		var ev := str(Db.gadgets[id].fail_event)
		t.check(Game.events.last_fired.has(ev) or _deferred(ev), "%s: its failure event '%s' fires" % [id, ev])
		t.check(not a.toggle(id), "%s: a broken gadget cannot be switched on" % id)
		a.service()
		t.check(not bool(a.gadgets[id].broken), "%s: servicing repairs it" % id)
	# The specific consequences.
	t.run("survivor", 42)
	t.at_work(700)
	_own("mousemover")
	a.fail("mousemover")
	var p := Game.comms.prompt_for_thread("it")
	t.check(not p.is_empty() and str(p.text).contains("circle"), "MouseMover: repetitive movement is detected and IT asks about it")
	t.check(Game.presence.status == "away", "MouseMover: your status drops to Away")
	t.run("survivor", 43)
	t.at_work(700)
	_own("duck")
	a.fail("duck")
	p = Game.comms.prompt_for_thread("team")
	t.check(not p.is_empty() and str(p.text).contains("jjjj"), "Keyboard Duck: gibberish lands in a corporate chat")
	t.run("survivor", 44)
	t.at_work(700)
	_own("chatbot")
	a.fail("chatbot")
	p = Game.comms.prompt_for_thread(t.boss())
	t.check(not p.is_empty() and str(p.text).contains("Project Halibut"), "Chatbot Team: it hallucinated a project and a customer")
	t.run("survivor", 45)
	t.at_work(700)
	_own("assistant")
	a.fail("assistant")
	p = Game.comms.prompt_for_thread(t.boss())
	t.check(not p.is_empty() and str(p.text).contains("banana bread"), "Meeting Assistant: a contextually absurd answer")
	# Failures also expose stories.
	t.run("survivor", 46)
	t.at_work(700)
	var c := _tell("family_emergency")
	Game.time.advance(4)
	_own("duck")
	a.fail("duck")
	t.check(c.status == Claim.CONTRADICTED, "a gadget posting to chat contradicts a story that forbids it")
	# A scan finds running gadgets; switched off, it finds nothing.
	var caught := 0
	for i in 40:
		t.run("survivor", 100 + i)
		t.at_work(700)
		Game.presence.set_at_desk(false)
		Game.presence.grant_cover(60, "test")
		_own("mousemover")
		_own("duck")
		_own("chatbot")
		Game.events.fire("audit_surprise", {})
		if a.any_broken():
			caught += 1
	t.check(caught > 5 and caught < 40, "a scan sometimes catches running gadgets (%d/40)" % caught)
	caught = 0
	for i in 20:
		t.run("survivor", 200 + i)
		t.at_work(700)
		Game.presence.set_at_desk(true)
		_own("mousemover", 1, false)
		_own("duck", 1, false)
		Game.events.fire("audit_surprise", {})
		if a.any_broken():
			caught += 1
	t.check(caught == 0, "a scan finds nothing when gadgets are switched off")


func _deferred(ev: String) -> bool:
	for e in Game.events.deferred:
		if str(e.id) == ev:
			return true
	return false


func _combos() -> void:
	t.section("gadget combinations")
	var a := Game.automation
	t.run("survivor", 51)
	t.at_work(600)
	t.check(a.combos_active().is_empty(), "no combination without gadgets")
	_own("mousemover")
	t.check(not a.combo_ready("ghost_shift"), "one half of a combination does nothing")
	_own("chatbot")
	t.check(a.combo_ready("ghost_shift"), "MouseMover + Chatbot Team = Ghost Shift")
	t.check(Game.presence.status == "online" or a.can("presence"), "Ghost Shift: you stay online")
	Game.events.fire("quick_q", {"urgent": true})
	var p: Dictionary = Game.comms.prompts[0]
	Game.time.advance(int(float(p.window) * 0.2) + 2)
	t.check(Game.comms.prompts.is_empty(), "Ghost Shift: routine messages are answered at once, with no manual intervention")
	a.gadgets["chatbot"].on = false
	t.check(not a.combo_ready("ghost_shift"), "a combination ends when a part is switched off")
	# Empty Chair.
	t.run("survivor", 52)
	t.at_work(600)
	_own("doppelganger")
	var standup := {"mandatory": true, "no_dodge": false, "state": "ringing", "title": "x"}
	t.check(Game.comms.can_send_clone(standup) != "", "a clone alone cannot take a mandatory meeting")
	_own("assistant")
	t.check(a.combo_ready("empty_chair") and Game.comms.can_send_clone(standup) == "", "Meeting Assistant + Doppelganger handles mandatory meetings")
	t.check(a.effect("chaos") > 0.0 and a.heat() > float(a.data("doppelganger").heat) + float(a.data("assistant").heat), "...at a higher risk of disaster and detection")
	t.check(Game.comms.can_send_clone({"mandatory": true, "no_dodge": true, "state": "ringing"}) != "", "nothing gets you out of the performance review")
	t.run("survivor", 53)
	t.at_work(600)
	_own("mousemover")
	var alone := a.heat()
	_own("duck")
	t.check(a.combo_ready("desk_theatre") and a.heat() < alone + float(a.data("duck").heat), "Desk Theatre lowers combined heat")


# ---------------------------------------------------------------------------
# EventDirector
# ---------------------------------------------------------------------------

func _events() -> void:
	t.section("events: preconditions")
	var e := Game.events
	t.run("survivor", 61)
	t.at_work(600)
	t.check(not e.fire("urgent_task", {"urgent": true}), "'urgent unfinished task' needs a ticket about to be due")
	var tk := Game.work.add_task("button")
	t.check(not e.fire("urgent_task", {"urgent": true}), "...and does not fire while the deadline is far away")
	tk.due = Game.time.now() + 60
	t.check(e.fire("urgent_task", {"urgent": true}), "it fires once a deadline is close and nothing is done")
	t.check(str(Game.comms.prompts[0].text).contains(str(tk.key)), "the event names the actual ticket")
	t.check(bool(tk.nagged), "the ticket is marked so the event does not repeat for it")
	t.run("survivor", 62)
	t.at_work(600)
	t.check(not e.fire("screen_check", {"urgent": true}), "screen checks need SynerWatch to be live")
	Game.set_flag("synerwatch")
	t.check(e.fire("screen_check", {"urgent": true}), "...and fire once it is")
	t.run("survivor", 63)
	t.at_work(600)
	t.check(not e.fire("why_away", {"urgent": true}), "'where are you?' needs a long unexplained absence")
	Game.time.advance(Cfg.UNCOVERED_ALERT + Cfg.IDLE_LIMIT + 8)
	t.check(e.last_fired.has("why_away"), "after 45 unexplained minutes the manager asks by himself")
	t.run("survivor", 64)
	t.at_work(600)
	t.check(not e.fire("numbers", {"urgent": true}), "day conditions are respected (not on Monday)")
	Game.time.day = 1
	t.check(e.fire("numbers", {"urgent": true}), "...and allow it later in the week")
	t.run("survivor", 65)
	Game.time.minute = 1100.0
	Game.time.phase = "evening"
	t.check(not e.fire("quick_q", {"urgent": true}), "nothing fires after hours")
	t.run("survivor", 66)
	t.at_work(600)
	t.check(e.fire("vpn_trouble", {"urgent": true}), "a one-off event fires")
	Game.comms.prompts.clear()
	t.check(not e.fire("vpn_trouble", {"urgent": true}), "...and only once per run")
	t.run("survivor", 67)
	t.at_work(600)
	Game.npcs.escalation = 0
	t.check(not e.check(Db.events["status_line"].conditions), "hourly status lines need a micromanaging boss")
	Game.npcs.escalation = 2
	t.check(e.check(Db.events["status_line"].conditions), "...and start once he is")
	# Difficulty modifiers.
	t.run("intern", 68, false)
	var intern_events: int = Game.time.timers.size()
	t.run("senior", 68, false)
	t.check(Game.time.timers.size() > intern_events, "harder difficulties schedule more interruptions (%d vs %d)" % [Game.time.timers.size(), intern_events])
	# Consequences: resources, new claims, NPC reactions, follow-ups.
	t.run("survivor", 69)
	t.at_work(626)
	e.fire("vpn_trouble", {"urgent": true})
	var p: Dictionary = Game.comms.prompts[0]
	var rel := Game.npcs.relationship(t.boss())
	Game.comms.answer(str(p.id), 0)
	t.check(Game.deception.live("internet_outage") != null, "an event choice can create a new claim")
	t.check(not Game.time.pending("claim_followup").is_empty(), "...which schedules its own follow-up")
	t.check(not is_equal_approx(Game.npcs.relationship(t.boss()), rel), "the NPC reacts to the answer")
	t.run("survivor", 70)
	t.at_work(600)
	e.fire("volunteer", {"urgent": true})
	var tasks: int = Game.work.tasks.size()
	var hp := Game.stats.get_value("health")
	Game.comms.answer(str(Game.comms.prompts[0].id), 0)
	t.check(Game.work.tasks.size() == tasks + 1 and Game.stats.get_value("health") < hp, "volunteering assigns a ticket and costs health")
	t.run("survivor", 71)
	t.at_work(600)
	e.fire("quick_q", {"urgent": true})
	var susp := Game.stats.get_value("susp")
	Game.time.advance(60)
	t.check(Game.stats.get_value("susp") > susp and int(Game.today.prompts_ignored) == 1, "ignoring a message has consequences")


func _pacing() -> void:
	t.section("events: pacing and modal conflicts")
	var e := Game.events
	var c := Game.comms
	t.run("survivor", 81)
	t.at_work(600)
	t.check(e.fire("quick_q", {}), "a first interruption fires")
	t.check(not e.fire("thoughts", {}), "a second one in the same conversation waits")
	t.check(_deferred("thoughts"), "...and is deferred, not lost")
	t.check(not e.fire("kevin_brag", {}), "filler events respect the minimum gap between interruptions")
	c.prompts.clear()
	Game.time.advance(EventDirector.MIN_GAP + EventDirector.DEFER_MINUTES + 1)
	t.check(e.last_fired.has("thoughts") or e.last_fired.has("kevin_brag"), "deferred events fire once there is room")
	# Never two calls at once.
	t.run("survivor", 82)
	t.at_work(569)
	Game.comms.add_meeting({"title": "Daily Standup", "start": 570, "dur": 15, "script": "standup", "mandatory": true})
	Game.time.advance(2)
	var ring := c.ringing()
	t.check(not ring.is_empty(), "the standup rings")
	t.check(not e.fire("surprise_call", {"urgent": true}), "a surprise call cannot start while another call is ringing")
	var ringing := 0
	for m in c.meetings:
		if str(m.state) == "ringing":
			ringing += 1
	t.check(ringing == 1, "only one call rings at a time")
	c.join(str(ring.id), false)
	t.check(c.in_call(), "joined the call")
	t.check(not e.fire("quick_q", {"urgent": true}), "no new messages demand attention during a call")
	t.check(not e.fire("surprise_call", {"urgent": true}), "no second call during a call")
	t.check(not c.join(str(ring.id), false), "a call cannot be joined twice")
	# Messages wait while you are in a meeting.
	t.run("survivor", 83)
	t.at_work(560)
	Game.comms.add_meeting({"title": "Daily Standup", "start": 570, "dur": 15, "script": "standup", "mandatory": true})
	e.fire("quick_q", {"urgent": true})
	var p: Dictionary = c.prompts[0]
	var due := int(p.due)
	Game.time.advance(11)
	ring = c.ringing()
	c.join(str(ring.id), false)
	var ignored := int(Game.today.prompts_ignored)
	while c.in_call():
		c.call_timeout()
	t.check(int(p.due) > due and int(Game.today.prompts_ignored) == ignored, "message deadlines are pushed back while you are in a meeting")
	# Two meetings scheduled for the same minute do not both ring.
	t.run("survivor", 84)
	t.at_work(700)
	c.add_meeting({"title": "A", "start": 705, "dur": 10, "script": "sync"})
	c.add_meeting({"title": "B", "start": 705, "dur": 10, "script": "sync"})
	Game.time.advance(7)
	ringing = 0
	for m in c.meetings:
		if str(m.state) == "ringing":
			ringing += 1
	t.check(ringing == 1, "overlapping meetings never ring simultaneously")
	# A whole week never has more than the allowed number of pending prompts or two rings.
	var worst_prompts := 0
	var worst_rings := 0
	t.run("senior", 85, false)
	Game.stats.values.susp = 0.0
	var guard := 0
	while Game.time.running() and Game.time.day == 0 and Game.time.phase == "work" and guard < 600:
		guard += 1
		Game.stats.values.susp = 0.0
		Game.time.advance(1)
		worst_prompts = maxi(worst_prompts, c.prompts.size())
		ringing = 0
		for m in c.meetings:
			if str(m.state) == "ringing":
				ringing += 1
		worst_rings = maxi(worst_rings, ringing)
	t.check(worst_rings <= 1, "a full day of ignoring everything never has two calls ringing (max %d)" % worst_rings)
	t.check(worst_prompts <= EventDirector.MAX_PENDING + 2, "...and unanswered messages are capped (max %d)" % worst_prompts)


# ---------------------------------------------------------------------------
# NPCManager, EconomyManager
# ---------------------------------------------------------------------------

func _npcs() -> void:
	t.section("npcs")
	var n := Game.npcs
	t.run("survivor", 91)
	t.check(n.boss_id() == "martin" and n.boss_name() == "Martin", "Martin is the manager")
	t.check(n.state.size() == Db.npcs.size(), "every NPC resource gets a runtime record")
	t.check(n.mood("martin") in NPCManager.MOOD_INFO, "the manager has a mood")
	var trust := n.trust("martin")
	n.caught_lying("martin")
	t.check(n.trust("martin") < trust and int(n.record("martin").caught) == 1, "being caught lying costs his trust")
	t.at_work(600)
	Game.stats.values.susp = 45.0
	Game.time.advance(2)
	t.check(n.escalation == 1, "suspicion escalates the manager's state")
	Game.stats.values.susp = 85.0
	Game.time.advance(2)
	t.check(n.escalation == 3 and n.frequency() > 1.5, "at high suspicion he contacts you far more often")
	t.check(n.mood("martin") in ["suspicious", "furious"], "and his mood shows it")
	Game.stats.values.susp = 10.0
	Game.time.advance(3)
	t.check(n.escalation < 3, "he calms down, slowly, when suspicion falls")
	t.run("survivor", 92)
	t.at_work(600)
	var base := Game.deception.chance(60.0, [], "martin")
	n.adjust("martin", 30.0)
	t.check(Game.deception.chance(60.0, [], "martin") > base, "a manager who likes you is easier to lie to")
	t.check(not is_equal_approx(n.trust("priya"), n.trust("dave")), "different people are differently gullible")
	n.contacted("kevin")
	t.check(int(n.record("kevin").contacts) == 1, "communication frequency is tracked per person")


# ---------------------------------------------------------------------------
# Colleagues: friendship, telling on you, favours, calls
# ---------------------------------------------------------------------------

func _voice_ok(id: String) -> bool:
	for i in range(1, 4):
		if not ResourceLoader.exists("res://assets/audio/voice_%s_%d.wav" % [id, i]):
			return false
	return true


func _colleague_content() -> void:
	t.section("colleagues: content")
	var s := Game.social
	t.run("survivor", 201)
	var people := s.colleagues()
	t.check(people.size() >= 4, "there are colleagues to befriend (%d)" % people.size())
	var known := ["ticket", "bury", "cover", "vouch", "intel", "distract", "skip_meeting", "wingman", "tipoff", "hype"]
	var scripted := {}
	var strange := 0
	for id in Db.events:
		var e: Dictionary = Db.events[id]
		if str(e.kind) != "call":
			continue
		if s.is_colleague(str(e.from)):
			scripted[str(e.from)] = int(scripted.get(str(e.from), 0)) + 1
		if str(e.pool) == "weird":
			strange += 1
			t.check(bool(e.once), "strange call '%s' happens at most once a week" % id)
		var voice := str(e.meeting.get("voice_id", ""))
		t.check(voice == "" or _voice_ok(voice), "event:%s voice '%s' has recordings" % [id, voice])
		for who in e.meeting.get("cast", []):
			t.check(Db.npcs.has(str(who)), "event:%s cast member '%s' exists" % [id, str(who)])
		if bool(e.meeting.get("ask", false)):
			t.check(s.is_colleague(str(e.from)), "event:%s only a colleague asks before calling" % id)
		t.check(str(e.tip) in ["", "call", "scan", "screen"], "event:%s tip is a known kind" % id)
	t.check(strange >= 5, "at least five strange calls exist (%d)" % strange)
	for id in people:
		var d: Dictionary = Db.npcs[id]
		t.check(int(scripted.get(id, 0)) >= 1, "%s has a scripted call (%d)" % [id, int(scripted.get(id, 0))])
		t.check(_voice_ok(str(d.voice)), "%s has a voice" % id)
		t.check(not d.favours.is_empty(), "%s can do something for you" % id)
		for f in d.favours:
			t.check(str(f.type) in known, "%s favour '%s' has a known type" % [id, str(f.id)])
			t.check(str(f.title) != "" and str(f.hint) != "", "%s favour '%s' explains itself" % [id, str(f.id)])
			t.check(bool(f.get("passive", false)) or WorkSystem.DEFS.has(str(Social.ACTIONS.get(str(f.type), "ask_favor"))), "%s favour '%s' is a declared action" % [id, str(f.id)])
		for key in ["small_talk", "missed_call", "friendly", "friend", "hostile"]:
			t.check(not s.lines_for(id, key).is_empty(), "%s has '%s' lines" % [id, key])
		if float(d.snitch) > 0.0:
			t.check(not s.lines_for(id, "snitch").is_empty(), "%s has something for the manager to say when they tell" % id)
	for id in Db.npcs:
		var v := str(Db.npcs[id].voice)
		t.check(v == "" or _voice_ok(v), "npc:%s voice '%s' has recordings" % [id, v])
		if str(Db.npcs[id].kind) == "stranger":
			t.check(not bool(Db.npcs[id].has_dm) and not bool(Db.npcs[id].colleague), "stranger '%s' is not in your contacts" % id)
	# Everything the new dialogue refers to exists.
	var flags_set := {}
	var flags_read := {}
	var lists: Array = []
	for id in Db.dialogues:
		for b in Db.dialogues[id].beats:
			lists.append(["dialogue:%s" % id, b.choices])
			var voice := str(b.get("voice", ""))
			t.check(voice == "" or _voice_ok(voice), "dialogue:%s voice '%s' has recordings" % [id, voice])
			for key in ["flag", "not_flag"]:
				if b.get("if", {}).has(key):
					flags_read[str(b["if"][key])] = "dialogue:%s" % id
	for id in Db.events:
		lists.append(["event:%s" % id, Db.events[id].choices])
		for key in ["flag", "not_flag"]:
			if Db.events[id].conditions.has(key):
				flags_read[str(Db.events[id].conditions[key])] = "event:%s" % id
	lists.append(["leverage", Db.lines("leverage")])
	for pair in lists:
		var where := str(pair[0])
		for c in pair[1]:
			for cond_key in ["tier_min", "tier_max"]:
				for who in c.get("if", {}).get(cond_key, {}):
					t.check(Db.npcs.has(str(who)), "%s: condition names a real person (%s)" % [where, str(who)])
			for key in ["flag", "not_flag"]:
				if c.get("if", {}).has(key):
					flags_read[str(c["if"][key])] = where
			for key in ["ok", "ko"]:
				var out: Dictionary = c.get(key, {})
				for who in out.get("rels", {}):
					t.check(str(who) == "{who}" or Db.npcs.has(str(who)), "%s: 'rels' names a real person (%s)" % [where, str(who)])
				if out.has("give"):
					t.check(s.is_colleague(str(out.give)), "%s: tickets are handed to colleagues (%s)" % [where, str(out.give)])
				if out.has("call"):
					t.check(Db.events.has(str(out.call)), "%s: call '%s' exists" % [where, str(out.call)])
				if out.has("flag"):
					flags_set[str(out.flag)] = true
				for f in out.get("flags", []):
					flags_set[str(f)] = true
	for card in Db.lines("leverage"):
		t.check(Db.npcs.has(str(card.on)) and WorkSystem.DEFS.has(str(card.a)), "leverage on '%s' is well-formed" % str(card.on))
		t.check(flags_set.has("dirt_" + str(card.on)), "there is a way to learn something about %s" % str(card.on))
		t.check(str(card.ok.get("flag", "")) == "dirt_%s_used" % str(card.on), "leverage on '%s' can be used once" % str(card.on))
	for f in flags_read:
		if str(flags_read[f]).begins_with("dialogue:") or str(f).begins_with("dirt_"):
			t.check(flags_set.has(f), "%s reads flag '%s', which something sets" % [str(flags_read[f]), str(f)])
	for id in ["snitch_followup", "priya_resigned"]:
		t.check(Db.events.has(id), "event '%s' exists" % id)
	for sfx in ["ring_peer", "ring_weird"]:
		t.check(ResourceLoader.exists("res://assets/audio/%s.wav" % sfx), "audio cue '%s' exists" % sfx)
	# The director actually finds room for the strange calls.
	var planned := 0
	for i in 12:
		t.run("survivor", 300 + i, false)
		for day in range(1, 5):
			Game.time.day = day
			Game.time.timers.clear()
			Game.comms.meetings.clear()
			Game.events.plan_day()
			for e in Game.time.timers:
				if str(e.ev) == "event" and str(Db.events[str(e.args.id)].pool) == "weird":
					planned += 1
	t.check(planned >= 24, "a week has a couple of strange calls in it (%.1f on average)" % (float(planned) / 12.0))


func _colleague_rules() -> void:
	t.section("colleagues: friendship and telling on you")
	var s := Game.social
	var n := Game.npcs
	t.run("survivor", 210)
	t.at_work(600)
	# Tiers follow the relationship.
	n.state.kevin.rel = 10.0
	t.check(s.tier("kevin") == Social.Tier.HOSTILE, "a relationship of 10 is hostile")
	n.state.kevin.rel = 50.0
	t.check(s.tier("kevin") == Social.Tier.NEUTRAL, "50 is an ordinary colleague")
	n.state.kevin.rel = 70.0
	t.check(s.tier("kevin") == Social.Tier.FRIENDLY, "70 is friendly")
	n.state.kevin.rel = 90.0
	t.check(s.tier("kevin") == Social.Tier.FRIEND and s.to_next_tier("kevin") == 0, "90 is a friend, and that is the top")
	var changes: Array = []
	var on_tier := func(id: String, tier: int, up: bool): changes.append([id, tier, up])
	s.tier_changed.connect(on_tier)
	n.state.priya.rel = 60.0
	s.tiers["priya"] = s.tier("priya")
	n.adjust("priya", 5.0)
	t.check(changes.size() == 1 and str(changes[0][0]) == "priya" and int(changes[0][1]) == Social.Tier.FRIENDLY and bool(changes[0][2]), "crossing a threshold announces the new tier")
	n.adjust("priya", 1.0)
	t.check(changes.size() == 1, "...once")
	s.tier_changed.disconnect(on_tier)
	# How likely each of them is to tell.
	n.state.kevin.rel = 50.0
	n.state.dave.rel = 50.0
	t.check(s.snitch_chance("kevin") > s.snitch_chance("dave"), "Kevin tells on you far more readily than Dave")
	var neutral := s.snitch_chance("kevin")
	n.state.kevin.rel = 10.0
	t.check(s.snitch_chance("kevin") > neutral, "someone who dislikes you tells more readily")
	n.state.kevin.rel = 70.0
	t.check(is_zero_approx(s.snitch_chance("kevin")), "a friend never tells on you")
	t.check(is_zero_approx(s.snitch_chance("martin")) and is_zero_approx(s.snitch_chance("nana")), "only colleagues tell on you")
	t.check(s.gossip_factor("kevin") == 0.0, "a friend keeps your stories to themselves")
	n.state.kevin.rel = 10.0
	t.check(s.gossip_factor("kevin") > 1.0, "an enemy passes them on faster")
	# Leaving a hostile Kevin hanging, many times over.
	var told := 0
	for i in 40:
		s.told = {}
		Game.stats.values.susp = 20.0
		if s.unanswered("kevin", "message"):
			told += 1
	t.check(told >= 30, "a hostile Kevin nearly always tells (%d of 40)" % told)
	told = 0
	for i in 40:
		s.told = {}
		Game.stats.values.susp = 20.0
		n.state.kevin.rel = 10.0
		if s.unanswered("kevin", "call", true):
			told += 1
	t.check(told >= 8 and told <= 30, "rejecting his call outright halves the risk (%d of 40)" % told)
	n.state.kevin.rel = 70.0
	told = 0
	for i in 40:
		s.told = {}
		if s.unanswered("kevin", "message"):
			told += 1
	t.check(told == 0, "a friendly Kevin never does")
	# What being told on costs.
	t.run("survivor", 211)
	t.at_work(600)
	n.state.kevin.rel = 5.0
	var susp := Game.stats.get_value("susp")
	var guard := 0
	while int(Game.week.snitched) == 0 and guard < 30:
		guard += 1
		s.told = {}
		s.unanswered("kevin", "message")
	t.check(int(Game.week.snitched) == 1 and Game.stats.get_value("susp") > susp, "being told on raises suspicion")
	t.check(int(n.record("kevin").snitched) == 1, "and it is remembered who did it")
	# The cap, and cover.
	s.told = {"kevin": Social.SNITCH_PER_DAY}
	told = 0
	for i in 20:
		if s.unanswered("kevin", "message"):
			told += 1
	t.check(told == 0, "one colleague tells on you at most %d times a day" % Social.SNITCH_PER_DAY)
	s.told = {}
	Game.presence.grant_cover(30, "story")
	told = 0
	for i in 20:
		if s.unanswered("kevin", "message"):
			told += 1
	t.check(told == 0, "nobody tells on someone who is officially out")
	# The manager follows up, naming them.
	t.run("survivor", 212)
	t.at_work(600)
	t.check(Game.events.fire("snitch_followup", {"who": "kevin", "urgent": true}), "the manager asks about it")
	var p: Dictionary = Game.comms.prompts[0]
	t.check(str(p.from) == "martin" and str(p.text).contains("Kevin") and not str(p.text).contains("{who}"), "naming who told him")
	var worded := true
	for c in Game.comms.choices_of(p):
		if str(c.t).contains("{who}") or str(c.get("ok", {}).get("say", "")).contains("{who}"):
			worded = false
	t.check(worded, "and every answer is worded for that person")
	var rel := n.relationship("kevin")
	Game.comms.apply({"rels": {"{who}": -6}}, "test", Game.comms.prompt_ctx(p))
	t.near(n.relationship("kevin"), rel - 6.0, "blaming them costs you with them")
	# An ignored message goes through the same door.
	t.run("survivor", 213)
	t.at_work(600)
	n.state.kevin.rel = 5.0
	Game.events.fire("favor_kevin", {"urgent": true})
	p = Game.comms.prompts[0]
	Game.time.advance(int(p.due) - Game.time.now() + 1)
	t.check(int(Game.week.colleagues_ignored) == 1, "a colleague's message left to expire counts as ignoring them")
	# Someone who has it in for you watches your status.
	var noticed := 0
	for i in 12:
		t.run("survivor", 220 + i)
		t.at_work(600)
		Game.presence.set_at_desk(false)
		Game.presence.last_input = -999
		n.state.kevin.rel = 5.0
		Game.time.advance(Social.WATCH_AFTER + 3)
		noticed += int(Game.week.snitched)
	t.check(noticed >= 3, "a hostile colleague reports a long absence (%d of 12 runs)" % noticed)
	noticed = 0
	for i in 12:
		t.run("survivor", 220 + i)
		t.at_work(600)
		Game.presence.set_at_desk(false)
		Game.presence.last_input = -999
		Game.time.advance(Social.WATCH_AFTER + 3)
		noticed += int(Game.week.snitched)
	t.check(noticed == 0, "ordinary colleagues do not")
	# Being nice on purpose.
	t.run("survivor", 240)
	t.at_work(600)
	Game.presence.set_at_desk(true)
	rel = n.relationship("priya")
	t.check(s.small_talk("priya") and n.relationship("priya") > rel, "small talk makes them like you more")
	rel = n.relationship("priya")
	t.check(not s.small_talk("priya") and is_equal_approx(n.relationship("priya"), rel), "once a day per person")
	t.check(not s.small_talk("martin"), "you do not make small talk with the manager")
	Game.economy.money = 500
	rel = n.relationship("kevin")
	var favors := Game.economy.favors
	t.check(s.gift("kevin") and Game.economy.money == 500 - s.gift_price() and Game.economy.favors == favors + 1, "a gift card costs money and earns a favour")
	t.near(n.relationship("kevin"), rel + Social.GIFT_REL, "and a lot of goodwill")
	t.check(not s.can_gift() and not s.gift("priya"), "one gift card a day")
	t.check(s.is_colleague(s.gift_target()), "a gift without a name goes to a colleague")
	# Knowing something about someone.
	t.run("survivor", 241)
	t.at_work(600)
	Game.events.fire("kevin_brag", {"urgent": true})
	p = Game.comms.prompts[0]
	var before := Game.comms.choices_of(p).size()
	Game.set_flag("dirt_kevin")
	var with_card := Game.comms.choices_of(p)
	t.check(with_card.size() == before + 1, "knowing something about Kevin adds an answer to anything he asks")
	var idx := -1
	for i in with_card.size():
		if str(with_card[i].get("on", "")) == "kevin":
			idx = i
	Game.comms.answer(str(p.id), idx)
	t.check(Game.flag("dirt_kevin_used") and s.leverage("kevin").is_empty(), "the card works once")
	# Stories that come with a witness.
	t.run("survivor", 242)
	t.at_work(600)
	var plain := Game.deception.claim_chance("family_emergency", "chat", "martin")
	Game.set_flag("nana_alibi")
	t.check(Game.deception.has_evidence("family_alibi") and Game.deception.claim_chance("family_emergency", "chat", "martin") > plain, "a grandmother who will swear to it is evidence")
	t.check(not Game.deception.has_evidence("form_filed"), "no form on file")
	Game.set_flag("fax_form")
	t.check(Game.deception.has_evidence("form_filed"), "a faxed Form 27-B is a form on file")


func _colleague_favours() -> void:
	t.section("colleagues: favours")
	var s := Game.social
	var n := Game.npcs
	var c := Game.comms
	t.run("survivor", 250)
	t.at_work(600)
	Game.presence.set_at_desk(true)
	# Locked until they like you enough.
	n.state.dave.rel = 50.0
	var view := s.favour_view("dave", s.favour("dave", "cover"))
	t.check(not bool(view.ok) and bool(view.locked), "Dave will not cover for a mere colleague")
	t.check(not s.ask("dave", "cover") and not Game.presence.covered(), "so asking does nothing")
	n.state.dave.rel = 70.0
	view = s.favour_view("dave", s.favour("dave", "cover"))
	t.check(bool(view.ok) and int(view.cost) == 0, "a friendly Dave covers for free")
	t.check(s.ask("dave", "cover") and Game.presence.covered(), "and then your absence is explained")
	t.check(int(Game.week.favours_called) == 1, "favours called in are counted")
	Game.presence.end_cover()
	t.check(not s.ask("dave", "cover"), "once a day")
	t.check(not bool(s.favour_view("dave", s.favour("dave", "afternoon")).ok), "the long cover needs a closer friend")
	# Tickets.
	Game.work.add_task("pipeline")
	var task: Dictionary = Game.work.tasks[0]
	n.state.priya.rel = 50.0
	Game.economy.favors = 0
	t.check(not s.ask("priya", "ticket", {"task": str(task.id)}), "a ticket costs a favour you do not have")
	Game.economy.favors = 2
	t.check(s.ask("priya", "ticket", {"task": str(task.id)}) and str(task.by) == "priya" and Game.economy.favors == 1, "Priya takes the ticket for one favour")
	t.check(not s.ask("dave", "ticket", {"task": str(task.id)}), "a ticket somebody is doing cannot be handed over again")
	var per := int(s.favour("priya", "ticket").speed)
	Game.time.advance(int(task.effort) * per + 2)
	t.check(str(task.status) == "done" and str(task.how) == "priya", "and finishes it without you")
	Game.work.add_task("button")
	var second: Dictionary = Game.work.tasks[1]
	t.check(Game.work.task_delegate(str(second.id)) and str(second.by) != "", "delegating without a name goes to whoever would do it")
	t.check(s.is_colleague(str(second.by)), "and that is a colleague")
	# Gerald loses things.
	Game.work.add_task("deck")
	var third: Dictionary = Game.work.tasks[2]
	n.state.gerald.rel = 70.0
	Game.economy.favors = 1
	t.check(s.ask("gerald", "misfile", {"task": str(third.id)}) and str(third.status) == "cancelled" and str(third.how) == "lost", "Gerald can make a ticket stop existing")
	t.check(int(Game.week.tasks_lost) == 1 and int(Game.week.tasks_failed) == 0, "which is not a failure")
	# A good word.
	t.run("survivor", 251)
	t.at_work(600)
	n.state.priya.rel = 90.0
	Game.economy.favors = 1
	Game.stats.values.susp = 40.0
	t.check(s.ask("priya", "vouch") and Game.stats.get_value("susp") < 40.0, "a friend vouching for you lowers suspicion")
	# Meetings.
	t.run("survivor", 252)
	t.at_work(600)
	n.state.brenda.rel = 70.0
	Game.economy.favors = 2
	c.add_meeting({"title": "Mandatory", "start": 620, "dur": 15, "script": "sync", "mandatory": true})
	c.add_meeting({"title": "Optional", "start": 660, "dur": 15, "script": "sync"})
	t.check(s.ask("brenda", "invite"), "Brenda can lose an invite")
	t.check(str(c.meetings[0].state) == "upcoming" and str(c.meetings[1].state) == "excused", "the optional one, never the mandatory one")
	n.state.brenda.rel = 90.0
	t.check(Game.events.can_interrupt(Db.events["quick_q"], {}) == "", "the manager checks in as usual")
	t.check(s.ask("brenda", "distract"), "Brenda can keep the manager busy")
	t.check(Game.events.can_interrupt(Db.events["quick_q"], {}) != "", "and then his check-ins wait")
	t.check(Game.events.can_interrupt(Db.events["favor_kevin"], {}) == "", "but colleagues still reach you")
	# Knowing what is coming.
	t.run("survivor", 253)
	t.at_work(600)
	n.state.kevin.rel = 70.0
	t.check(Game.events.forecast().is_empty(), "nothing is planned")
	Game.time.schedule(Game.time.now() + 90, "event", {"id": "audit_surprise"})
	Game.time.schedule(Game.time.now() + 150, "event", {"id": "surprise_call"})
	var seen := Game.events.forecast()
	t.check(seen.size() == 2 and str(seen[0]).contains("11:30") and str(seen[0]).contains("SynerWatch"), "the forecast lists today's surprise checks, in order (%s)" % str(seen))
	t.check(s.ask("kevin", "intel"), "Kevin will read it to you")
	var last: Dictionary = c.threads["kevin"].msgs.back()
	t.check(str(last.text).contains("11:30"), "in his chat")
	# Tip-offs.
	t.run("survivor", 254)
	t.at_work(600)
	n.state.dave.rel = 90.0
	Game.time.schedule(Game.time.now() + EventDirector.TIP_LEAD + 3, "event", {"id": "surprise_call"})
	Game.time.advance(2)
	t.check(int(Game.week.tipoffs) == 0, "no warning while it is still far off")
	Game.time.advance(3)
	t.check(int(Game.week.tipoffs) == 1, "a close friend warns you shortly before a surprise call")
	Game.time.advance(4)
	t.check(int(Game.week.tipoffs) == 1, "once")
	t.check(c.ringing().is_empty(), "before it rings")
	t.run("survivor", 255)
	t.at_work(600)
	Game.time.schedule(Game.time.now() + 5, "event", {"id": "surprise_call"})
	Game.time.advance(3)
	t.check(int(Game.week.tipoffs) == 0, "nobody warns a stranger")
	# Talked up in public.
	t.run("survivor", 256)
	t.at_work(Social.HYPE_AT - 2)
	n.state.kevin.rel = 70.0
	Game.stats.values.ill = 30.0
	var posts: int = c.threads["team"].msgs.size()
	Game.time.advance(3)
	t.check(c.threads["team"].msgs.size() == posts + 1 and Game.stats.get_value("ill") > 30.0, "a friendly Kevin talks you up in the team channel")
	# A friend in the meeting.
	t.run("survivor", 257)
	t.at_work(569)
	c.add_meeting({"title": "Daily Standup", "start": 570, "dur": 15, "script": "standup", "mandatory": true})
	Game.time.advance(2)
	c.join(str(c.ringing().id), false)
	var has_wing := func() -> int:
		var list := c.call_choices()
		for i in list.size():
			if list[i].has("wing"):
				return i
		return -1
	t.check(has_wing.call() < 0, "nobody takes questions for a mere colleague")
	n.state.priya.rel = 70.0
	var wing: int = has_wing.call()
	t.check(wing >= 0 and not Game.work.is_work(str(c.call_choices()[wing].a)), "a friendly Priya will take a question for you")
	c.call_choose(wing)
	t.check(not c.in_call() or has_wing.call() < 0, "once per meeting")
	while c.in_call():
		c.call_timeout()
	t.run("survivor", 258)
	t.at_work(600)
	n.state.priya.rel = 70.0
	Game.events.fire("one_on_one", {"urgent": true})
	Game.time.advance(2)
	c.join(str(c.ringing().id), false)
	t.check(has_wing.call() < 0, "she is not in your one-to-one")
	while c.in_call():
		c.call_timeout()
	# Outcomes that only colleagues and strangers hand out.
	t.run("survivor", 259)
	t.at_work(600)
	c.apply({"block": {"title": "Vendor call", "dur": 25}}, "test")
	t.check(c.calendar_block_now() and Game.deception.has_evidence("calendar_block"), "a meeting someone books for you is real evidence")
	c.apply({"flags": ["a_flag", "b_flag"], "boss_busy": 30}, "test")
	t.check(Game.flag("a_flag") and Game.flag("b_flag"), "an outcome can set several flags")
	t.check(Game.events.can_interrupt(Db.events["quick_q"], {}) != "", "and can keep the manager busy")
	Game.work.add_task("pipeline")
	c.apply({"lose_task": true}, "test")
	t.check(str(Game.work.tasks[0].status) == "cancelled", "and can lose a ticket")


func _colleague_calls() -> void:
	t.section("colleagues: calls")
	var s := Game.social
	var n := Game.npcs
	var c := Game.comms
	# A colleague rings: not a meeting.
	t.run("survivor", 270)
	t.at_work(680)
	Game.presence.set_at_desk(true)
	t.check(Game.events.fire("brenda_hello", {}), "Brenda calls")
	Game.time.advance(1)
	var m := c.ringing()
	t.check(not m.is_empty() and bool(m.casual) and str(m.who) == "brenda", "it rings, as a casual call")
	t.check(c.ring_sound(m) == "ring_peer", "with a colleague's ring tone")
	t.check(c.can_send_clone(m) != "", "your clone does not take it for you")
	t.check(c.call_cast(m) == ["brenda"], "it is one-to-one")
	var susp := Game.stats.get_value("susp")
	var rel := n.relationship("brenda")
	n.state.brenda.rel = 70.0             # friendly: missing it stays between the two of you
	rel = 70.0
	Game.time.advance(int(m.ring_until) - int(Game.time.minute) + 2)
	t.check(str(m.state) == "missed" and int(Game.week.calls_dodged) == 1 and int(Game.week.meetings_missed) == 0, "letting it ring out is a missed call, not a missed meeting")
	t.near(Game.stats.get_value("susp"), susp, "which the manager never hears about", 0.6)
	t.check(n.relationship("brenda") < rel, "though she likes you less for it")
	var retry := false
	for e in Game.time.timers:
		if str(e.ev) == "event" and str(e.args.id) == "brenda_hello" and bool(e.args.get("ctx", {}).get("retry", false)):
			retry = true
			Game.time.minute = float(int(e.at) % 1440 - 1)
	t.check(retry, "she tries again later")
	Game.time.advance(3)
	m = c.ringing()
	t.check(not m.is_empty() and bool(m.retry), "and it rings a second time")
	rel = n.relationship("brenda")
	c.reject_call(str(m.id))
	t.check(str(m.state) == "missed" and n.relationship("brenda") < rel and n.relationship("brenda") >= rel - 2.5, "rejecting it costs less than ignoring it")
	t.check(Game.time.pending("event").filter(func(e): return str(e.args.id) == "brenda_hello").is_empty(), "she does not try a third time")
	# Taking it.
	t.run("survivor", 271)
	t.at_work(680)
	Game.presence.set_at_desk(true)
	Game.events.fire("brenda_hello", {})
	Game.time.advance(1)
	m = c.ringing()
	rel = n.relationship("brenda")
	c.join(str(m.id), false)
	t.check(c.in_call() and c.call_context() == "video", "a colleague's video call is on camera")
	var hp := Game.stats.get_value("health")
	var slack := int(Game.week.slack_min)
	var worked := int(Game.week.worked_min)
	c.call_choose(0)
	t.near(Game.stats.get_value("health"), hp, "it costs no health", 0.5)
	t.check(int(Game.week.slack_min) > slack, "and counts as paid time off")
	var guard := 0
	while c.in_call() and guard < 10:
		guard += 1
		c.call_choose(0)
	t.check(str(m.state) == "done" and int(Game.week.calls_taken) == 1 and int(Game.week.meetings_attended) == 0, "finishing it is a call taken, not a meeting attended")
	t.check(n.relationship("brenda") > rel and int(Game.week.worked_min) == worked, "she likes you more, and no work was done")
	# Hanging up.
	t.run("survivor", 272)
	t.at_work(680)
	Game.presence.set_at_desk(true)
	Game.events.fire("brenda_hello", {})
	Game.time.advance(1)
	c.join(str(c.ringing().id), false)
	susp = Game.stats.get_value("susp")
	rel = n.relationship("brenda")
	c.call_hang_up()
	t.check(not c.in_call() and n.relationship("brenda") < rel, "hanging up on a colleague is rude")
	t.near(Game.stats.get_value("susp"), susp, "but not suspicious", 0.6)
	# Voice-only lines.
	t.run("survivor", 273)
	Game.time.day = 1
	t.at_work(875)
	Game.presence.set_at_desk(true)
	Game.events.fire("dave_range", {})
	Game.time.advance(1)
	m = c.ringing()
	t.check(not bool(m.video) and str(m.voice_id) == "choppy", "Dave rings from the driving range, audio only, on a bad line")
	c.join(str(m.id), false)
	t.check(c.call_context() == "phone", "no camera, so no outfit bonus or penalty")
	# Beats that depend on what you said.
	c.call_choose(0)                       # "I'm the vendor"
	t.check(Game.flag("dave_pact") and str(c.call_beat().text).contains("Say it back"), "agreeing leads to the briefing")
	while c.in_call():
		c.call_choose(0)
	t.check(Game.presence.covered(), "and the alibi covers you too")
	t.run("survivor", 274)
	Game.time.day = 1
	t.at_work(875)
	Game.presence.set_at_desk(true)
	Game.events.fire("dave_range", {})
	Game.time.advance(1)
	c.join(str(c.ringing().id), false)
	c.call_choose(2)                       # "you're going to get us both fired"
	t.check(not Game.flag("dave_pact") and str(c.call_beat().text).contains("Two words"), "refusing leads somewhere else")
	while c.in_call():
		c.call_choose(1)
	# Answers that only exist once you know something.
	t.run("survivor", 275)
	Game.time.day = 2
	t.at_work(850)
	Game.presence.set_at_desk(true)
	Game.events.fire("kevin_dashboard", {})
	Game.time.advance(1)
	c.join(str(c.ringing().id), false)
	var plain := c.call_choices().size()
	Game.set_flag("dirt_kevin")
	t.check(c.call_choices().size() == plain + 1, "knowing about the database adds an answer on Kevin's call")
	while c.in_call():
		c.call_timeout()
	# Asking first.
	t.run("survivor", 276)
	Game.time.day = 1
	t.at_work(940)
	Game.presence.set_at_desk(true)
	t.check(Game.events.fire("priya_vent", {}) and c.ringing().is_empty() and c.prompts.size() == 1, "Priya asks before she calls")
	var p: Dictionary = c.prompts[0]
	t.check(str(p.from) == "priya" and not bool(p.no_excuse), "it is a message from her, and excuses are welcome")
	c.answer(str(p.id), 0)
	Game.time.advance(2)
	t.check(not c.ringing().is_empty() and str(c.ringing().who) == "priya", "saying yes makes her call")
	t.run("survivor", 277)
	Game.time.day = 1
	t.at_work(940)
	Game.presence.set_at_desk(true)
	Game.events.fire("priya_vent", {})
	p = c.prompts[0]
	c.answer(str(p.id), 1)
	Game.time.advance(5)
	t.check(c.ringing().is_empty(), "asking for twenty minutes holds her off")
	Game.time.advance(17)
	t.check(not c.ringing().is_empty(), "for twenty minutes")
	t.run("survivor", 278)
	Game.time.day = 1
	t.at_work(940)
	Game.events.fire("priya_vent", {})
	p = c.prompts[0]
	Game.time.advance(int(p.due) - Game.time.now() + 2)
	t.check(c.ringing().is_empty() and int(Game.week.colleagues_ignored) == 1, "ignoring the question is ignoring her")
	# Strangers.
	t.run("survivor", 279)
	Game.time.day = 2
	t.at_work(700)
	Game.presence.set_at_desk(true)
	var story := _tell("internet_outage")
	t.check(story != null and story.is_active(), "you told the manager your internet is down")
	Game.events.fire("weird_nana", {"urgent": true})
	Game.time.advance(1)
	m = c.ringing()
	t.check(bool(m.casual) and c.ring_sound(m) == "ring_weird" and n.kind(str(m.who)) == "stranger", "an unknown number rings differently")
	c.join(str(m.id), false)
	t.check(story.is_active(), "a stranger on your own line contradicts nothing")
	var excuse := false
	for ch in c.call_choices():
		if bool(ch.get("excuse", false)):
			excuse = true
	t.check(not excuse, "and you owe a stranger no excuses")
	susp = Game.stats.get_value("susp")
	c.call_hang_up()
	t.near(Game.stats.get_value("susp"), susp, "hanging up on one costs nothing", 0.6)
	c.meetings.clear()                     # (no pause between calls, for the test)
	Game.events.fire("brenda_dirt", {"asked": true, "urgent": true})
	Game.time.advance(1)
	c.join(str(c.ringing().id), false)
	t.check(not story.is_active(), "a video call with a colleague does contradict it")
	while c.in_call():
		c.call_timeout()
	t.run("survivor", 280)
	Game.time.day = 2
	t.at_work(700)
	Game.events.fire("weird_fax", {"urgent": true})
	Game.time.advance(1)
	m = c.ringing()
	susp = Game.stats.get_value("susp")
	Game.time.advance(int(m.ring_until) - int(Game.time.minute) + 2)
	t.check(str(m.state) == "missed" and int(Game.week.snitched) == 0, "an unknown number left to ring out is nobody's business")
	t.check(not Game.events.fire("weird_fax", {"urgent": true}), "and it does not call back")
	# The manager's calls are still the manager's calls.
	t.run("survivor", 281)
	Game.time.day = 2
	t.at_work(700)
	Game.events.fire("surprise_call", {"urgent": true})
	Game.time.advance(1)
	m = c.ringing()
	t.check(not bool(m.casual) and c.ring_sound(m) == "ring_loop", "a call from the manager is not casual")
	susp = Game.stats.get_value("susp")
	Game.time.advance(int(m.ring_until) - int(Game.time.minute) + 2)
	t.check(Game.stats.get_value("susp") > susp + 3.0 and int(Game.week.meetings_missed) == 1, "and missing it still costs you")
	# Every scripted and strange call can be played to the end without real work.
	for id in Db.events:
		var e: Dictionary = Db.events[id]
		if str(e.kind) != "call" or not (s.is_colleague(str(e.from)) or str(e.pool) == "weird"):
			continue
		for pick: int in [0, 1, 2]:
			t.run("survivor", 290 + pick)
			Game.time.day = 3
			t.at_work(700)
			Game.presence.set_at_desk(true)
			if e.conditions.has("owns"):
				_own(str(e.conditions.owns))
			for who in e.conditions.get("tier_min", {}):
				n.state[who].rel = 90.0
			Game.economy.favors = 3
			Game.economy.money = 500
			Game.work.add_task("pipeline")
			var fired := Game.events.fire(id, {"asked": true, "urgent": true})
			Game.time.advance(1)
			m = c.ringing()
			if m.is_empty():
				t.check(false, "call '%s' rings (fired: %s)" % [id, str(fired)])
				continue
			c.join(str(m.id), false)
			guard = 0
			worked = int(Game.week.worked_min)
			while c.in_call() and guard < 12:
				guard += 1
				var list := c.call_choices()
				var chosen := -1
				for k in list.size():
					var i: int = (pick + k) % list.size()
					if not Game.work.is_work(str(list[i].a)) and not bool(list[i].get("excuse", false)) and bool(c.choice_view(list[i], c.call_context(), str(c.call_beat().who)).ok):
						chosen = i
						break
				if chosen < 0:
					c.call_timeout()
				else:
					c.call_choose(chosen)
			t.check(not c.in_call() and Game.time.running() and int(Game.week.worked_min) == worked, "call '%s' plays through without real work (path %d)" % [id, pick])
	# Saving keeps who your friends are.
	Game.saves.enabled = true
	t.run("survivor", 295)
	t.at_work(600)
	Game.presence.set_at_desk(true)
	n.state.dave.rel = 70.0
	s.tiers["dave"] = s.tier("dave")
	s.ask("dave", "cover")
	s.small_talk("priya")
	s.told = {"kevin": 1}
	t.check(Game.saves.save("slot3"), "save")
	t.run("intern", 6)
	t.check(Game.saves.load_game("slot3"), "load")
	t.check(s.tier("dave") == Social.Tier.FRIENDLY and s.talked_today("priya") and int(s.told.get("kevin", 0)) == 1, "friendships, small talk and who told on you are restored")
	t.check(not bool(s.favour_view("dave", s.favour("dave", "cover")).ok), "a favour asked today is still asked today after loading")
	Game.saves.delete("slot3")
	Game.saves.enabled = false


# ---------------------------------------------------------------------------
# Junk food and other loose items
# ---------------------------------------------------------------------------

func _junk_food() -> void:
	t.section("junk food")
	var h := Game.home
	t.check(Db.foods.size() >= 30, "there are many kinds of junk food (%d)" % Db.foods.size())
	var groups := {}
	var models := {}
	for id in Db.foods:
		var f: Dictionary = Db.foods[id]
		groups[str(f.group)] = int(groups.get(str(f.group), 0)) + 1
		t.check(FoodKit.has(str(f.model)) and str(f.model) in FoodKit.MODELS, "food:%s has a 3D model ('%s')" % [id, str(f.model)])
		t.check(not models.has(str(f.model)), "food:%s has a model of its own" % id)
		models[str(f.model)] = id
		t.check(str(f.trash) == "" or str(f.trash) in FoodKit.TRASH, "food:%s leftover '%s' has a model" % [id, str(f.trash)])
		t.check(str(f.trash) == "" or str(f.trash_name) != "", "food:%s leftover has a name" % id)
		t.check(int(f.bites) >= 1 and int(f.bites) <= 8 and float(f.energy) > 0.0 and float(f.fullness) > 0.0, "food:%s has sane numbers" % id)
		t.check(str(f.display_name) != "" and str(f.blurb) != "", "food:%s has a name and a line" % id)
	for g in ["sweet", "frozen", "crunchy", "hot", "drink"]:
		t.check(int(groups.get(g, 0)) >= 3, "at least three kinds of '%s' (%d)" % [g, int(groups.get(g, 0))])
	for toy in Home.TOYS:
		t.check(str(toy) in FoodKit.TOYS, "toy '%s' has a model" % str(toy))
	for m in FoodKit.MODELS:
		t.check(models.has(str(m)), "model '%s' is something you can actually find" % str(m))
	t.check(WorkSystem.DEFS.has("eat") and not Game.work.is_work("eat"), "eating is not work")
	for sfx in ["step", "bite", "gulp", "pickup", "putdown", "squeak"]:
		t.check(ResourceLoader.exists("res://assets/audio/%s.wav" % sfx), "audio cue '%s' exists" % sfx)
	# A fresh flat.
	t.run("survivor", 401)
	t.at_work(600)
	var food_n := 0
	var toys := 0
	var spots := {}
	for it in h.items:
		if h.is_toy(it):
			toys += 1
		else:
			food_n += 1
			t.check(str(it.spot) in Home.MORNING_SPOTS and not spots.has(str(it.spot)), "'%s' has a spot to itself (%s)" % [h.item_name(it), str(it.spot)])
			spots[str(it.spot)] = true
	t.check(food_n == Home.MORNING_ITEMS and toys == Home.TOYS.size(), "Monday starts with %d things to eat and %d to fidget with (%d, %d)" % [Home.MORNING_ITEMS, Home.TOYS.size(), food_n, toys])
	# Eating.
	var it := h.add_item("burger", "desk")
	t.check(h.item_name(it) == "Cheeseburger" and h.item_model(it) == "burger" and int(it.bites) == 4, "a burger is four bites")
	Game.stats.values.energy = 30.0
	Game.stats.values.health = 60.0
	var view := h.bite_view(it)
	t.check(bool(view.ok) and is_equal_approx(float(view.energy), 4.0) and str(view.verb) == "Eat", "each bite is worth a quarter of it")
	var res := h.eat(str(it.id))
	t.check(bool(res.ok) and not bool(res.done) and int(it.bites) == 3, "a bite is a bite")
	t.near(Game.stats.get_value("energy"), 34.0, "it gives energy")
	t.check(Game.stats.get_value("health") > 60.0, "comfort food comforts")
	t.near(h.fullness(), 9.0, "and fills you up")
	t.check(int(Game.week.bites) == 1 and int(Game.week.worked_min) == 0, "bites are counted, and are not work")
	h.eat(str(it.id))
	h.eat(str(it.id))
	res = h.eat(str(it.id))
	t.check(bool(res.done) and bool(it.trash) and h.item_name(it) == "Wrapper" and h.item_model(it) == "trash_wrapper", "the last bite leaves a wrapper")
	t.check(int(Game.week.junk_eaten) == 1 and not bool(h.bite_view(it).ok) and not bool(h.eat(str(it.id)).ok), "you cannot eat the wrapper")
	var n := h.items.size()
	var donut := h.add_item("donut", "")
	for i in 3:
		Game.home.things.fullness = 0.0
		h.eat(str(donut.id))
	t.check(h.item(str(donut.id)).is_empty() and h.items.size() == n, "a donut leaves nothing behind")
	# Being full.
	t.run("survivor", 402)
	t.at_work(600)
	var pizza := h.add_item("pizza_box", "")
	var eaten := 0
	for i in 12:
		if bool(h.eat(str(pizza.id)).ok):
			eaten += 1
	t.check(eaten > 0 and eaten < 8 and int(pizza.bites) == 8 - eaten, "you cannot eat a whole pizza in one go (%d slices)" % eaten)
	t.check(h.fullness() <= Home.FULL and str(h.bite_view(pizza).why) != "", "you are told why")
	Game.time.advance(1)
	t.check(Game.stats.has_buff("stuffed"), "and you are stuffed")
	Game.time.advance(60)
	t.check(h.fullness() < Home.STUFFED_AT and not Game.stats.has_buff("stuffed"), "it settles in time")
	t.check(bool(h.eat(str(pizza.id)).ok), "and then there is room for more")
	# Caffeine.
	t.run("survivor", 403)
	t.at_work(600)
	for i in 2:
		var can := h.add_item("energy_can", "")
		for b in 3:
			h.eat(str(can.id))
	t.check(int(h.things.coffees) == 2 and Game.stats.has_buff("jitter"), "an energy drink counts as a coffee, jitters included")
	# Hands, the fridge, the microwave.
	t.run("survivor", 404)
	t.at_work(600)
	t.check(h.held == "" and not h.hold("nope"), "you start empty-handed")
	var stock := int(h.things.snacks)
	t.check(h.use("fridge", "take") and h.held != "" and int(h.things.snacks) == stock - 1, "the fridge hands you something to carry")
	var got := h.item(h.held)
	t.check(str(h.food(got).group) in Home.FRIDGE_GROUPS, "something cold (%s)" % h.item_name(got))
	t.check(not h.use("fridge", "take"), "not with your hands full")
	h.release()
	t.check(h.held == "" and not h.item(str(got.id)).is_empty(), "putting it down does not make it vanish")
	var has_heat := func() -> bool:
		for o in h.options("microwave"):
			if str(o.id) == "heat":
				return true
		return false
	t.check(not has_heat.call(), "the microwave offers nothing for empty hands")
	var slice := h.add_item("pizza_slice", "")
	h.hold(str(slice.id))
	t.check(has_heat.call(), "holding something hot-able, it offers to heat it")
	var cold := float(h.bite_view(slice).energy)
	t.check(h.use("microwave", "heat") and Game.activities.id() == "heat", "heating takes a moment")
	Game.time.advance(3)
	t.check(bool(slice.hot) and float(h.bite_view(slice).energy) > cold * 1.2, "a hot slice is worth more per bite")
	h.release()
	var cola := h.add_item("soda_can", "")
	h.hold(str(cola.id))
	t.check(not has_heat.call(), "you cannot microwave a can of cola")
	# The bin.
	t.run("survivor", 405)
	t.at_work(600)
	var wrapper := h.add_item("burger", "", true)
	Game.stats.values.health = 50.0
	t.check(h.rubbish() == 1, "rubbish is counted")
	h.hold(str(wrapper.id))
	t.check(h.use("bin", "bin") and h.item(str(wrapper.id)).is_empty() and h.held == "", "the kitchen bin takes what is in your hand")
	t.check(Game.stats.get_value("health") > 50.0 and int(Game.week.binned) == 1, "tidying up is good for you")
	for i in 8:
		var more := h.add_item("burger", "", true)
		h.bin(str(more.id))
	t.near(Game.stats.get_value("health"), 50.0 + float(Home.TIDY_MAX) * float(Game.diff().recover), "up to a point")
	var duck: Dictionary = {}
	for x in h.items:
		if str(x.food) == "rubber_duck":
			duck = x
	t.check(not duck.is_empty() and h.item_name(duck) == "Rubber Duck" and not h.bin(str(duck.id)) and not h.item(str(duck.id)).is_empty(), "you cannot bin the rubber duck")
	t.check(h.fidget(str(duck.id)), "you can squeeze it")
	# Every object in the flat copes with whatever is in your hand.
	for carry in [str(duck.id), str(h.add_item("soda_can", "").id), str(h.add_item("burger", "", true).id), str(h.add_item("pizza_slice", "").id), ""]:
		h.held = carry
		var listed := 0
		for thing in Home.THINGS:
			listed += h.options(str(thing)).size()
		t.check(listed >= Home.THINGS.size(), "every object offers something while you hold '%s'" % (h.item_name(h.item(carry)) if carry != "" else "nothing"))
		t.check(not bool(h.bite_view(h.item(carry)).ok) or not h.is_toy(h.item(carry)), "and a toy is never food")
	h.held = ""
	# A dirty flat.
	t.run("survivor", 406)
	t.at_work(1010)
	for i in 3:
		h.add_item("fries", "", true)
	var moved := 0
	for x in h.items:
		if str(x.spot) in Home.MORNING_SPOTS and moved < 2:
			x.spot = ""                    # you carried two of them off somewhere
			moved += 1
	Game.time.advance(15)
	Game.stats.values.health = 50.0
	var before_n := h.items.size()
	Game.sleep()
	t.check(Game.time.day == 1 and h.rubbish() == 3, "yesterday's rubbish is still there in the morning")
	t.check(h.items.size() == before_n + 2, "what you took is replaced; what you left is still there (%d new)" % (h.items.size() - before_n))
	var slept := Game.stats.get_value("health")
	t.run("survivor", 406)
	t.at_work(1010)
	Game.time.advance(15)
	Game.stats.values.health = 50.0
	Game.sleep()
	t.check(Game.stats.get_value("health") > slept, "waking up in a tidy flat is better for you (%.1f vs %.1f)" % [Game.stats.get_value("health"), slept])
	# Pizza.
	t.run("survivor", 407)
	t.at_work(600)
	Game.economy.money = 100
	var count := h.items.size()
	t.check(h.use("gaming_pc", "pizza") and Game.economy.money == 100 - Game.economy.price(Home.PIZZA_PRICE), "a pizza costs money")
	t.check(h.items.size() == count, "and takes a while")
	t.check(not h.use("gaming_pc", "pizza"), "one at a time")
	Game.time.advance(Home.PIZZA_MINUTES + 1)
	var arrived: Dictionary = h.items.back()
	t.check(h.items.size() == count + 1 and str(arrived.food) == "pizza_box" and str(arrived.spot) == "doormat", "it arrives on the doormat")
	t.check(not h.use("gaming_pc", "pizza"), "one pizza a day")
	# Clutter is capped.
	for i in 60:
		h.add_item("cookie", "", i % 2 == 0)
	t.check(h.items.size() <= Home.MAX_ITEMS, "the flat never holds more than %d loose things (%d)" % [Home.MAX_ITEMS, h.items.size()])
	# Extreme difficulty: eating never ends the run.
	t.run("unemployed", 408)
	t.at_work(600)
	var safe := h.add_item("burger", "")
	h.eat(str(safe.id))
	t.check(Game.time.running() and int(Game.week.worked_min) == 0, "eating is safe on Professional Unemployed")
	# Save and load.
	Game.saves.enabled = true
	t.run("survivor", 409)
	t.at_work(600)
	var keep := h.add_item("burger", "")
	h.eat(str(keep.id))
	keep.at = [1.0, 0.8, -2.0, 0.0, 0.0, 0.0, 1.0]
	h.hold(str(keep.id))
	var snap := {"n": h.items.size(), "full": h.fullness(), "id": str(keep.id)}
	t.check(Game.saves.save("slot3"), "save")
	t.run("intern", 7)
	t.check(Game.saves.load_game("slot3"), "load")
	var back := h.item(str(snap.id))
	t.check(h.items.size() == int(snap.n) and not back.is_empty() and int(back.bites) == 3 and h.held == str(snap.id), "items, bites and what you were holding are restored")
	t.near(h.fullness(), float(snap.full), "and so is your stomach")
	t.check(typeof(back.bites) == TYPE_INT and (back.at as Array).size() == 7, "item data keeps its types")
	Game.saves.delete("slot3")
	Game.saves.enabled = false


func _economy() -> void:
	t.section("economy")
	var e := Game.economy
	t.run("survivor", 95)
	t.check(e.money == Cfg.START_MONEY, "you start with pocket money")
	var pay := e.day_salary(0, 80.0, 10.0)
	t.check(int(pay.total) == Cfg.SALARY_BASE + Cfg.BONUS_ZERO_WORK + Cfg.BONUS_ILLUSION, "a zero-work day that looked busy pays the most")
	t.check(int(e.day_salary(120, 80.0, 10.0).total) < int(pay.total), "doing real work forfeits the efficiency bonus")
	t.check(int(e.day_salary(0, 40.0, 90.0).total) < Cfg.SALARY_BASE + Cfg.BONUS_ZERO_WORK, "high suspicion docks your pay")
	e.pay_salary(300)
	t.check(e.money == Cfg.START_MONEY + 300 and e.earned == 300, "salary is paid and tracked")
	t.run("senior", 95)
	var hard := Game.automation.price("mousemover", 1)
	t.run("intern", 95)
	t.check(Game.automation.price("mousemover", 1) < hard, "prices scale with difficulty")
	t.check(Game.automation.price("mousemover", 2) > 0, "upgrades have their own price")


# ---------------------------------------------------------------------------
# Save / load, day flow
# ---------------------------------------------------------------------------

func _save_load() -> void:
	t.section("save / load")
	Game.saves.enabled = true
	t.run("senior", 99, false)
	Game.player = {"name": "Saver", "skin": 2, "accessory": 3}
	Game.presence.set_at_desk(true)
	Game.time.advance(70)
	while Game.comms.in_call():
		Game.comms.call_timeout()
	Game.economy.money = 777
	Game.time.day = 1
	Game.automation.buy("mousemover")
	Game.automation.toggle("mousemover")
	_tell("data_validation")
	Game.home.use("wardrobe", "wear_shirt")
	var snap := {
		"minute": Game.time.minute, "day": Game.time.day, "susp": Game.stats.get_value("susp"), "tasks": Game.work.tasks.size(),
		"prompts": Game.comms.prompts.size(), "meetings": Game.comms.meetings.size(), "timers": Game.time.timers.size(),
		"money": Game.economy.money, "rel": Game.npcs.relationship(t.boss()),
	}
	t.check(Game.saves.save("slot3"), "save succeeds")
	t.check(not Game.saves.meta("slot3").is_empty(), "the save has readable metadata")
	t.run("intern", 5)
	t.check(Game.saves.load_game("slot3"), "load succeeds")
	t.check(is_equal_approx(Game.time.minute, float(snap.minute)) and Game.time.day == int(snap.day), "the clock is restored")
	t.near(Game.stats.get_value("susp"), float(snap.susp), "suspicion is restored")
	t.check(Game.work.tasks.size() == int(snap.tasks) and Game.comms.prompts.size() == int(snap.prompts) and Game.comms.meetings.size() == int(snap.meetings), "tickets, messages and meetings are restored")
	t.check(Game.time.timers.size() == int(snap.timers), "scheduled events are restored")
	t.check(Game.economy.money == int(snap.money), "money is restored")
	t.check(Game.automation.working("mousemover"), "gadgets and their state are restored")
	t.check(Game.deception.live("data_validation") != null, "active claims are restored")
	t.check(Game.home.outfit == "shirt", "the apartment state is restored")
	t.near(Game.npcs.relationship(t.boss()), float(snap.rel), "NPC relationships are restored")
	t.check(Game.difficulty_id == "senior" and Game.player_name() == "Saver" and int(Game.player.accessory) == 3, "difficulty and character customisation are restored")
	t.check(typeof(Game.time.minute) == TYPE_FLOAT and typeof(Game.economy.money) == TYPE_INT, "numeric types survive the round trip")
	Game.time.advance(30)
	t.check(Game.time.running() and is_equal_approx(Game.time.minute, float(snap.minute) + 30.0), "the simulation continues after loading")
	# Versioning: an incompatible save is refused, not half-loaded.
	var bad := Game.save_state()
	bad.version = GameManager.SAVE_VERSION - 1
	t.check(not Game.load_state(bad), "a save from another version is rejected")
	Game.saves.delete("slot3")
	t.check(Game.saves.meta("slot3").is_empty(), "a save can be deleted")
	Game.saves.enabled = false


func _day_flow() -> void:
	t.section("day flow")
	t.run("intern", 1, false)
	Game.presence.set_at_desk(true)
	var guard := 0
	while Game.time.phase == "work" and guard < 800:
		guard += 1
		if Game.comms.in_call():
			Game.comms.call_timeout()
		var ring := Game.comms.ringing()
		if not ring.is_empty():
			Game.comms.join(str(ring.id))
		Game.time.advance(1)
	t.check(Game.time.phase == "evening" and Game.reports.size() == 1, "17:00 ends the workday with a report")
	t.check(int(Game.reports[0].salary) >= Cfg.SALARY_BASE and Game.economy.earned > 0, "salary is paid")
	for key in ["hours_employed", "worked_min", "pretend_min", "excuses", "meetings_avoided", "salary", "susp_gained", "health", "auto_eff"]:
		t.check(Game.reports[0].has(key), "the daily report includes '%s'" % key)
	Game.home.use("bed", "sleep")
	t.check(Game.time.day == 1 and Game.time.phase == "work" and int(Game.time.minute) == Cfg.DAY_START, "sleeping starts Tuesday at 08:59")
	t.check(not Game.comms.meetings_today().is_empty(), "the new day is planned")
