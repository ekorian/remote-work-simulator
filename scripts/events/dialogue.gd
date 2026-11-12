class_name Dialogue
extends RefCounted
## Dialogue — assembles what people say from authored content and the
## current state of the run: meeting scripts, the Friday review, and the
## small generated texts (fake updates, fake reports).

static func build(m: Dictionary) -> Array:
	## Beats for a meeting. The review is generated from how the week went.
	var script := str(m.script)
	if script == "review":
		return _review_beats()
	var def: Dictionary = Db.dialogues.get(script, Db.dialogues.get("sync", {}))
	var beats: Array = def.get("beats", []).duplicate(true)
	var pool: Array = def.get("pool", []).duplicate()
	for i in int(def.get("pick", 0)):
		if pool.is_empty():
			break
		var key: String = pool[Game.rng.randi() % pool.size()]
		pool.erase(key)
		beats.append_array(Db.dialogues.get(key, {}).get("beats", []).duplicate(true))
	# A suspicious boss puts you on the spot once more.
	if Game.npcs.escalation >= 3 and Db.dialogues.has("grilling") and script != "fun" and not bool(m.get("casual", false)):
		beats.append_array(Db.dialogues["grilling"].beats.duplicate(true))
	return beats


static func fake_update_line(t: Dictionary) -> String:
	return str(Game.pick(Db.lines("fake_updates"))).replace("{key}", str(t.key)).replace("{pct}", str(int(t.fake)))


static func fake_report_text() -> String:
	var lines: Array = []
	for i in 4:
		lines.append("- %s %s %s" % [Game.pick(Db.lines("report_verbs")), Game.pick(Db.lines("report_nouns")), Game.pick(Db.lines("report_tails"))])
	return "Hi %s,\n\nToday's highlights:\n%s\n\nNext steps: continue to continue.\n\nBest,\n{name}" % [Game.npcs.boss_name(), "\n".join(lines)]


static func _review_beats() -> Array:
	var wk := Game.week
	var boss := Game.npcs.boss_id()
	var name := Game.npcs.boss_name()
	var done := int(wk.tasks_done) + int(wk.tasks_faked)
	var failed := int(wk.tasks_failed)
	var caught := Game.deception.caught()
	var told := Game.deception.claims.size()
	var p_achieve := clampf(46.0 + 9.0 * float(done) - 10.0 * float(failed), 15.0, 90.0)
	var beats: Array = [
		{
			"who": boss, "no_excuse": true,
			"text": "Performance review. HR is on the line. {name}: what was your biggest achievement this week?",
			"choices": [
				{"t": "List your closed tickets with total confidence.", "a": "bluff", "p": p_achieve, "tags": ["video", "jargon"], "ok": {"susp": -5, "ill": 5, "say": "Linda: That matches the board. Noted."}, "ko": {"susp": 9, "say": "Linda: The board shows something rather different."}},
				{"t": "\"Achievement is a journey, not a deliverable.\"", "a": "jargon", "p": 52, "tags": ["jargon", "video"], "ok": {"ill": 3, "say": "%s: ...I'm writing that down." % name}, "ko": {"susp": 7, "say": "Linda: Please answer the question."}},
				{"t": "Present real, documented accomplishments", "a": "real_answer", "ok": {"susp": -9, "ill": 8, "say": "Linda: Thorough. Very thorough."}},
			],
			"silence": {"susp": 9, "say": "Linda: Let the record show the employee said nothing."},
		},
	]
	if caught > 0 or told >= 6:
		beats.append({
			"who": "linda", "no_excuse": true,
			"text": "Our records show %d separate explanations for your absences this week, %d of which fell apart. Care to comment?" % [told, caught],
			"choices": [
				{"t": "\"Each one was documented. Check your system.\"", "a": "bluff", "p": 62.0 - 13.0 * float(caught), "tags": ["video"], "ok": {"susp": -4, "say": "Linda: ...The system does lose things. Fine."}, "ko": {"susp": 11, "say": "Linda: I am the system."}},
				{"t": "\"It's been a hard week. Family, routers, the Change Advisory Board.\"", "a": "bluff", "p": 44.0 - 6.0 * float(caught), "tags": ["video"], "ok": {"susp": -2, "say": "%s: Let's show some empathy here, Linda." % name}, "ko": {"susp": 9, "say": "Linda: All in the same week. Remarkable."}},
				{"t": "Come clean about the excuses.", "a": "honest", "ok": {"susp": 14, "say": "Linda: Thank you for your honesty. It will be held against you."}},
			],
			"silence": {"susp": 10, "say": "Linda: Silence. Noted."},
		})
	else:
		beats.append({
			"who": "linda", "no_excuse": true,
			"text": "Your attendance record is... surprisingly clean. How do you stay so available?",
			"choices": [
				{"t": "\"Discipline. And a very good chair.\"", "a": "bluff", "p": 80, "tags": ["video"], "ok": {"susp": -4, "ill": 3, "say": "Linda: We should all be so lucky."}, "ko": {"susp": 4, "say": "Linda: Hm."}},
				{"t": "\"I never really log off.\" (Technically true.)", "a": "honest", "ok": {"susp": -2, "say": "%s: That's the spirit!" % name}},
			],
			"silence": {"susp": 6, "say": "Linda: Noted."},
		})
	if int(wk.auto_runs) > 0 and int(wk.auto_runs) - int(wk.auto_ok) >= 2:
		beats.append({
			"who": "it", "no_excuse": true,
			"text": "IT here. Your machine tripped %d automation alerts this week. Explain the 'non-human input patterns'." % (int(wk.auto_runs) - int(wk.auto_ok)),
			"choices": [
				{"t": "\"Accessibility software. For my wrists.\"", "a": "bluff", "p": 56, "tags": ["video"], "ok": {"susp": -3, "say": "IT: ...We can't legally ask a follow-up to that."}, "ko": {"susp": 9, "say": "IT: It was typing 'jjjjjj' at 3am."}},
				{"t": "\"I think my laptop is haunted. Have you tried rebooting it?\"", "a": "deflect", "p": 48, "tags": ["video"], "ok": {"say": "IT: ...We'll open a ticket."}, "ko": {"susp": 7, "say": "IT: That's our line."}},
				{"t": "Admit to the gadgets.", "a": "honest", "ok": {"susp": 13, "say": "IT: Confiscation form is in your inbox."}},
			],
			"silence": {"susp": 9, "say": "IT: No comment. Logged."},
		})
	beats.append({
		"who": boss, "no_excuse": true,
		"text": "Last one. Where do you see yourself in five years?",
		"choices": [
			{"t": "\"Driving synergy at scale, wherever the roadmap takes me.\"", "a": "jargon", "p": 76, "tags": ["jargon", "video"], "ok": {"ill": 4, "susp": -3, "say": "%s: Beautiful." % name}, "ko": {"susp": 5, "say": "Linda: That's the mission statement from our lobby wall."}},
			{"t": "\"In your chair, %s.\"" % name, "a": "bluff", "p": 34, "tags": ["video"], "ok": {"susp": -9, "ill": 8, "say": "%s: HA! I love ambition." % name}, "ko": {"susp": 10, "say": "%s: ...Excuse me?" % name}},
			{"t": "\"Honestly? On a beach. Still on payroll.\"", "a": "honest", "ok": {"susp": 9, "say": "Linda: I'm writing down 'retention risk'."}},
		],
		"silence": {"susp": 8, "say": "%s: Deep thinker. OK." % name},
	})
	return beats
