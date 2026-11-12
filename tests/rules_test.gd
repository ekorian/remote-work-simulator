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
	bad.version = 1
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
