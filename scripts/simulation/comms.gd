class_name Comms
extends GameSystem
## Comms — SynerCorp's communication channels: chat threads, messages that
## need an answer (prompts), mail, the calendar, meetings and live calls.
## Pure data and rules; the desktop apps and the phone are views over it.
##
## Choices offered by prompts, mails and calls share one format and one
## resolver (`resolve`). See docs/ARCHITECTURE.md, "Choice format".

const CHANNELS := {"team": "# team-synergy", "general": "# general"}

var threads: Dictionary = {}     ## thread id -> {msgs: [], unread: int}
var prompts: Array = []          ## messages waiting for an answer
var meetings: Array = []
var mails: Array = []
var live_call: Dictionary = {}   ## {mid, beats, i, phone, per} while in a call


func _ready() -> void:
	Game.time.minute_passed.connect(_on_minute)


func setup_run() -> void:
	Db.load_all()
	threads = {}
	for tid in thread_order():
		threads[tid] = {"msgs": [], "unread": 0}
	prompts = []
	meetings = []
	mails = []
	live_call = {}


func save_state() -> Dictionary:
	return {"threads": threads, "prompts": prompts, "meetings": meetings, "mails": mails}


func load_state(d: Dictionary) -> void:
	setup_run()
	var saved: Dictionary = d.get("threads", {})
	for tid in saved:
		threads[tid] = saved[tid]
	prompts = d.get("prompts", [])
	meetings = d.get("meetings", [])
	mails = d.get("mails", [])
	live_call = {}
	# A call cannot be resumed: a meeting that was live counts as attended.
	for m in meetings:
		if str(m.state) == "live" and str(m.kind) != "block":
			m.state = "done"


# ---------------------------------------------------------------------------
# Threads and notifications
# ---------------------------------------------------------------------------

func thread_order() -> Array:
	## Boss first, then channels, then everyone else you can message.
	var out: Array = []
	var boss := ""
	for id in Db.npcs:
		if bool(Db.npcs[id].is_boss):
			boss = id
	if boss != "":
		out.append(boss)
	out.append_array(CHANNELS.keys())
	for id in Db.npcs:
		if id != boss and bool(Db.npcs[id].has_dm):
			out.append(id)
	return out


func is_channel(tid: String) -> bool:
	return CHANNELS.has(tid)


func thread_name(tid: String) -> String:
	return str(CHANNELS[tid]) if CHANNELS.has(tid) else Game.npcs.display_name(tid)


func dm_thread(who: String) -> String:
	var t := str(Game.npcs.def(who).get("thread", ""))
	if t != "":
		return t
	return who if threads.has(who) else "team"


func fmt(text: String) -> String:
	return text.replace("{name}", Game.player_name()).replace("{boss}", Game.npcs.boss_name())


func post(thread: String, who: String, text: String, kind: String = "") -> Dictionary:
	var th: Dictionary = threads[thread]
	var m := {"who": who, "text": fmt(text), "day": Game.time.day, "t": int(Game.time.minute), "kind": kind}
	th.msgs.append(m)
	if th.msgs.size() > 80:
		th.msgs.pop_front()
	if who != "me":
		th.unread = int(th.unread) + 1
	Bus.thread_message.emit(thread, m)
	Bus.comms_changed.emit()
	return m


func say(who: String, text: String, loud: bool = true) -> void:
	## An NPC speaks in their own thread.
	post(dm_thread(who), who, text)
	Game.npcs.contacted(who)
	if loud:
		notify(Game.npcs.display_name(who), fmt(text), "info", false, who)


func can_react(thread: String) -> bool:
	if not is_channel(thread):
		return false
	var msgs: Array = threads[thread].msgs
	for i in range(msgs.size() - 1, -1, -1):
		var m: Dictionary = msgs[i]
		if str(m.who) != "me" and str(m.who) != "bot":
			return not bool(m.get("reacted", false))
	return false


func react(thread: String) -> bool:
	## Drop an emoji on the latest message in a group channel.
	if not can_react(thread):
		return false
	if not Game.work.perform("react", {"label": "React in %s" % thread_name(thread)}):
		return false
	var msgs: Array = threads[thread].msgs
	for i in range(msgs.size() - 1, -1, -1):
		var m: Dictionary = msgs[i]
		if str(m.who) != "me" and str(m.who) != "bot":
			m["reacted"] = true
			break
	if Game.time.in_work_hours():
		Game.stats.add("ill", 1.5, "Visible engagement")
	Game.presence.touch()
	Game.deception.observe("desk_message")
	Game.deception.observe("social_post")
	Bus.sfx.emit("pop")
	Bus.comms_changed.emit()
	return true


func mark_read(thread: String) -> void:
	threads[thread].unread = 0
	Bus.comms_changed.emit()


func unread_total() -> int:
	var n := 0
	for tid in threads:
		n += int(threads[tid].unread)
	return n


func notify(title: String, text: String, kind: String = "info", urgent: bool = false, from: String = "") -> void:
	## Tell the player, if they are in a position to notice.
	if Game.presence.can_notice():
		Bus.toast.emit("%s: %s" % [title, text], kind)
		if urgent:
			Bus.sfx.emit("ring")
			Game.time.alert()
		else:
			Bus.sfx.emit("boss" if from == Game.npcs.boss_id() else "ping")
	else:
		Bus.sfx.emit("ping_far")


# ---------------------------------------------------------------------------
# Choices (shared by chat prompts, mail and calls)
# ---------------------------------------------------------------------------

func choice_view(c: Dictionary, context: String = "chat", listener: String = "") -> Dictionary:
	## Everything the UI needs to draw one choice button.
	var act := str(c.get("a", "ack"))
	var v := {
		"text": fmt(str(c.t)), "badge": Game.work.badge(act), "odds": -1.0,
		"ok": true, "why": "", "excuse": bool(c.get("excuse", false)), "cost": Game.work.energy_cost(act),
	}
	var check := Game.work.can(act)
	if not check.ok:
		v.ok = false
		v.why = check.why
	var req: Dictionary = c.get("req", {})
	if req.has("ability") and not Game.automation.can(str(req.ability)):
		v.ok = false
		v.why = "Needs a working %s" % Game.automation.owner_of(str(req.ability))
	if req.has("favor") and Game.economy.favors < int(req.favor):
		v.ok = false
		v.why = "Needs %d favour(s)" % int(req.favor)
	if req.has("money") and not Game.economy.can_afford(int(req.money)):
		v.ok = false
		v.why = "Needs $%d" % int(req.money)
	if req.has("evidence") and not Game.deception.has_evidence(str(req.evidence)):
		v.ok = false
		v.why = "Needs: %s" % str(DeceptionManager.EVIDENCE_TEXT.get(str(req.evidence), req.evidence))
	if c.has("ability"):
		var gid := Game.automation.provider(str(c.ability))
		v.odds = 100.0 - Game.automation.fail_chance(gid) if gid != "" else 0.0
	elif c.has("evidence"):
		v.odds = 95.0 if Game.deception.has_evidence(str(c.evidence)) else 5.0
	elif c.has("p"):
		v.odds = Game.deception.chance(float(c.p), _tags(c, context), listener)
	return v


func _tags(c: Dictionary, context: String) -> Array:
	var tags: Array = c.get("tags", []).duplicate()
	if context == "video" and not "video" in tags:
		tags.append("video")
	return tags


func resolve(c: Dictionary, context: String, ctx: Dictionary, excuse_id: String = "") -> Dictionary:
	## Execute one choice. Returns {done, ok, say, end}. `done` is false when
	## the choice could not be taken, or the run ended while taking it.
	## ctx: {from, about, claim, task, via}
	var res := {"done": false, "ok": true, "say": "", "end": false}
	var listener := str(ctx.get("from", Game.npcs.boss_id()))
	var view := choice_view(c, context, listener)
	if not view.ok:
		Bus.toast.emit(str(view.why), "warn")
		return res
	var act := str(c.get("a", "ack"))
	var out: Dictionary = {}
	if bool(c.get("excuse", false)):
		if not Db.claims.has(excuse_id):
			return res
		if not Game.work.perform("excuse", {"label": str(Db.claims[excuse_id].title)}):
			return res
		var att := Game.deception.attempt(excuse_id, context, listener, str(ctx.get("about", "")), str(ctx.get("task", "")))
		res.ok = bool(att.ok)
		res.say = str(att.say)
		res["claim"] = att.claim
		out = c.get("ok", {}) if res.ok else c.get("ko", {"susp": 6})
		if res.ok and not out.has("susp"):
			out = out.duplicate()
			out["susp"] = -1
	else:
		if not Game.work.perform(act, {"label": fmt(str(c.t))}):
			return res
		if Game.work.is_work(act) and not in_call():
			# Real work takes real (game) time, wherever it was agreed to.
			Game.activities.start({
				"id": "grind", "label": "Doing actual work", "mins": int(WorkSystem.DEFS[act].get("mins", 30)),
				"speed": 6.0, "anim": "type", "thing": "", "per": {},
			})
		var req: Dictionary = c.get("req", {})
		if req.has("favor"):
			Game.economy.add_favor(-int(req.favor))
		if req.has("money"):
			Game.economy.add_money(-int(req.money), "Favour")
		if c.has("ability"):
			res.ok = Game.automation.use_ability(str(c.ability))
		elif c.has("evidence"):
			res.ok = Game.deception.has_evidence(str(c.evidence))      # it holds up only if it is true
		elif c.has("match"):
			var told := Game.deception.claim(str(ctx.get("claim", "")))
			res.ok = told != null and told.subject == str(c.match)     # do you remember your own story?
		elif c.has("p"):
			res.ok = Game.deception.roll(float(c.p), _tags(c, context), listener)
			if Game.work.cls_of(act) == WorkSystem.Cls.DECEIVE and res.ok:
				Game.bump("lies_landed")
		out = c.get("ok", {}) if res.ok else c.get("ko", c.get("ok", {}))
		res.say = str(out.get("say", ""))
	if not Game.time.running():
		return res
	res.done = true
	res.end = bool(out.get("end", false))
	Game.npcs.react(listener, res.ok, Game.work.cls_of(act))
	apply(out, str(ctx.get("about", "")), ctx)
	return res


func apply(out: Dictionary, reason: String, ctx: Dictionary = {}) -> void:
	## Apply the consequences of a choice (or of ignoring one).
	var from := str(ctx.get("from", Game.npcs.boss_id()))
	if out.has("susp"):
		Game.stats.add("susp", float(out.susp), reason)
	if out.has("ill"):
		Game.stats.add("ill", float(out.ill), reason)
	if out.has("hp"):
		Game.stats.add("health", float(out.hp), reason)
	if out.has("en"):
		Game.stats.add("energy", float(out.en), reason)
	if not Game.time.running():
		return
	if out.has("money"):
		Game.economy.add_money(int(out.money), reason)
	if out.has("favor"):
		Game.economy.add_favor(int(out.favor))
	if out.has("rel"):
		Game.npcs.adjust(from, float(out.rel))
	if out.has("cover"):
		Game.presence.grant_cover(int(out.cover), str(out.get("cover_cat", "story")))
	if out.has("buff"):
		Game.stats.add_buff(str(out.buff[0]), int(out.buff[1]))
	if out.has("flag"):
		Game.set_flag(str(out.flag))
	if out.has("stat"):
		Game.bump(str(out.stat))
	if out.has("task"):
		Game.work.add_task(str(out.task))
	if out.has("progress"):
		var t := Game.work.task(str(ctx.get("task", "")))
		if t.is_empty() or str(t.status) != "open":
			t = Game.work.most_urgent_task()
		if not t.is_empty():
			Game.work.task_progress(str(t.id), int(out.progress), 0.0, "me")
	if out.has("give"):
		_hand_off(str(out.give))
	if out.has("claim"):
		# A story handed to you by the situation: accepted without a roll.
		Game.deception.attempt(str(out.claim), "chat", from, reason, str(ctx.get("task", "")), true)
	if out.has("claim_status") and str(ctx.get("claim", "")) != "":
		Game.deception.resolve(str(ctx.claim), str(out.claim_status))
	if out.has("due_in"):
		var due_task := Game.work.task(str(ctx.get("task", "")))
		if due_task.is_empty():
			due_task = Game.work.most_urgent_task()
		if not due_task.is_empty():
			Game.work.set_deadline(str(due_task.id), Game.time.now() + int(out.due_in))
	if out.has("fix_gadget"):
		var gid := str(ctx.get("gadget", ""))
		if Game.automation.owns(gid):
			Game.automation.g(gid).broken = false
			Game.automation.g(gid).wear = 0.0
			Bus.gadget_changed.emit(gid)
	if out.has("event"):
		Game.events.fire(str(out.event), {"task": str(ctx.get("task", "")), "claim": str(ctx.get("claim", "")), "urgent": true})
	if out.has("later"):
		var l: Dictionary = out.later
		Game.events.fire_later(int(l.get("in", 30)), str(l.ev), {"task": str(ctx.get("task", ""))})


func _hand_off(who: String) -> void:
	## Hand your most urgent open ticket to a colleague.
	var t := Game.work.most_urgent_task()
	if t.is_empty():
		return
	t.by = who
	t.helper_left = int(t.effort) * 35
	Game.bump("tasks_delegated")
	Bus.toast.emit("%s is now quietly doing %s." % [Game.npcs.display_name(who), str(t.key)], "good")
	Bus.task_changed.emit(t)


# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------

func add_prompt(def: Dictionary) -> Dictionary:
	var window := int(round(float(def.get("window", 25)) * float(Game.diff().window) * Cfg.WINDOW_SCALE))
	var due := Game.time.now() + window
	var kind := str(def.get("kind", "chat"))
	var from := str(def.get("from", Game.npcs.boss_id()))
	# People leave you alone (for a bit) while they think you are legitimately out.
	if kind == "chat" and Game.presence.covered() and bool(def.get("routine", false)):
		due = Game.presence.cover_until + window
	var p := {
		"id": Game.next_id("p"), "key": str(def.get("id", "")), "kind": kind,
		"thread": str(def.get("thread", dm_thread(from))),
		"from": from, "text": fmt(str(def.text)),
		"choices": def.choices.duplicate(true), "due": due, "born": Game.time.now(), "window": window,
		"routine": bool(def.get("routine", false)), "expire": def.get("expire", {"susp": 7}),
		"stalled": false, "mail": str(def.get("mail", "")), "auto_tried": false,
		"no_excuse": bool(def.get("no_excuse", kind != "chat")),
		"claim": str(def.get("claim", "")), "task": str(def.get("task", "")), "gadget": str(def.get("gadget", "")),
	}
	prompts.append(p)
	if kind == "chat":
		post(str(p.thread), from, str(p.text), "prompt")
	Game.npcs.contacted(from)
	if Game.presence.can_notice():
		Bus.sfx.emit("boss" if from == Game.npcs.boss_id() else "ping")
		Game.time.alert()
	else:
		Bus.sfx.emit("ping_far")
	Bus.prompt_added.emit(p)
	Bus.comms_changed.emit()
	return p


func prompt(pid: String) -> Dictionary:
	for p in prompts:
		if p.id == pid:
			return p
	return {}


func pending(kind: String = "") -> Array:
	var out: Array = []
	for p in prompts:
		if kind == "" or p.kind == kind:
			out.append(p)
	out.sort_custom(func(a, b): return int(a.due) < int(b.due))
	return out


func prompt_for_thread(thread: String) -> Dictionary:
	for p in prompts:
		if p.kind == "chat" and p.thread == thread:
			return p
	return {}


func prompt_for_mail(mail_id: String) -> Dictionary:
	for p in prompts:
		if p.mail == mail_id:
			return p
	return {}


func choices_of(p: Dictionary) -> Array:
	var out: Array = p.choices.duplicate()
	if not bool(p.no_excuse):
		out.append({"t": "Make an excuse...", "a": "excuse", "excuse": true})
	return out


func prompt_ctx(p: Dictionary, via: String = "desk") -> Dictionary:
	return {"from": str(p.from), "about": str(p.text), "claim": str(p.claim), "task": str(p.task), "gadget": str(p.get("gadget", "")), "via": via}


func answer(pid: String, idx: int, excuse_id: String = "", via: String = "desk") -> Dictionary:
	## Answer a prompt. `via` is "desk" (work computer) or "phone".
	var p := prompt(pid)
	if p.is_empty():
		return {"done": false}
	var list := choices_of(p)
	if idx < 0 or idx >= list.size():
		return {"done": false}
	var c: Dictionary = list[idx]
	# The message itself is a visible fact, and it is checked against every
	# story already on record *before* any new story is told.
	var was_work := Game.work.is_work(str(c.get("a", "ack")))
	Game.deception.observe("phone_message" if via == "phone" else "desk_message")
	var res := resolve(c, "chat", prompt_ctx(p, via), excuse_id)
	if not res.done:
		return res
	var line := fmt(str(c.t))
	if bool(c.get("excuse", false)):
		line = str(Db.claims[excuse_id].line)
		var cl: Claim = res.get("claim")
		if cl != null and cl.subject != "":
			line = line.replace("{subject}", cl.subject)
	if p.kind == "chat":
		post(str(p.thread), "me", line)
		if res.say != "":
			post(str(p.thread), str(p.from), str(res.say), "good" if res.ok else "bad")
	elif res.say != "":
		Bus.toast.emit("%s: %s" % [Game.npcs.display_name(str(p.from)), fmt(str(res.say))], "good" if res.ok else "bad")
	prompts.erase(p)
	Game.bump("prompts_answered")
	if via != "phone":
		Game.presence.touch()
	if was_work:
		Game.deception.observe("ticket_activity")
	Bus.sfx.emit("good" if res.ok else "bad")
	Bus.prompt_resolved.emit(p, res)
	Bus.comms_changed.emit()
	return res


func stall(pid: String) -> bool:
	## "On it!" — buys time once per prompt.
	var p := prompt(pid)
	if p.is_empty() or bool(p.stalled):
		return false
	if not Game.work.perform("stall", {"label": "Stall"}):
		return false
	p.stalled = true
	p.due = int(p.due) + int(round(15.0 * float(Game.diff().window)))
	if p.kind == "chat":
		post(str(p.thread), "me", str(Game.pick(["On it!", "Looking into it now.", "Give me two minutes.", "Yep, circling back shortly."])))
	Game.deception.observe("desk_message")
	Bus.comms_changed.emit()
	return true


func _expire(p: Dictionary) -> void:
	prompts.erase(p)
	Game.bump("prompts_ignored")
	var ex: Dictionary = p.expire
	Game.npcs.ignored(str(p.from))
	apply(ex, "Ignored: %s" % Game.npcs.display_name(str(p.from)), prompt_ctx(p))
	if not Game.time.running():
		return
	if p.kind == "chat":
		post(str(p.thread), str(p.from), str(ex.get("say", Game.pick(["Hello??", "...", "Guess you're busy. Noted.", "Read 14 minutes ago. Interesting."]))), "bad")
	Bus.sfx.emit("bad")
	Bus.prompt_resolved.emit(p, {"done": true, "ok": false, "say": "", "expired": true})
	Bus.comms_changed.emit()


func _auto_reply(p: Dictionary) -> void:
	## A chatbot answers a routine message for you.
	p.auto_tried = true
	if not Game.automation.use_ability("auto_reply"):
		return                      # it failed: its failure event takes it from here
	post(str(p.thread), "me", str(Game.pick(Db.lines("auto_replies"))), "auto")
	prompts.erase(p)
	Game.stats.add("ill", 2.0, "Chatbot reply")
	Game.bump("prompts_answered")
	Game.deception.observe("auto_message")
	Bus.toast.emit("Your chatbot handled a ping from %s." % Game.npcs.display_name(str(p.from)), "good")
	Bus.prompt_resolved.emit(p, {"done": true, "ok": true, "say": "", "auto": true})
	Bus.comms_changed.emit()
	Game.automation.maybe_chaos("message")


# ---------------------------------------------------------------------------
# Calendar and meetings
# ---------------------------------------------------------------------------

func add_meeting(def: Dictionary) -> Dictionary:
	var m := {
		"id": Game.next_id("m"), "key": str(def.get("id", "")), "title": str(def.title),
		"day": int(def.get("day", Game.time.day)), "start": int(def.start), "dur": int(def.get("dur", 30)),
		"kind": str(def.get("kind", "meeting")), "who": str(def.get("who", Game.npcs.boss_id())),
		"mandatory": bool(def.get("mandatory", false)), "video": bool(def.get("video", true)),
		"script": str(def.get("script", "")), "state": "upcoming", "ring_until": -1,
		"excuse_tried": false, "no_dodge": bool(def.get("no_dodge", false)),
		"surprise": bool(def.get("surprise", false)), "warned": false,
	}
	meetings.append(m)
	Bus.meeting_changed.emit(m)
	return m


func meeting(id: String) -> Dictionary:
	for m in meetings:
		if m.id == id:
			return m
	return {}


func meetings_today() -> Array:
	var out: Array = []
	for m in meetings:
		if int(m.day) == Game.time.day:
			out.append(m)
	out.sort_custom(func(a, b): return int(a.start) < int(b.start))
	return out


func ringing() -> Dictionary:
	for m in meetings:
		if m.state == "ringing":
			return m
	return {}


func next_meeting() -> Dictionary:
	for m in meetings_today():
		if m.state == "upcoming" and m.kind != "block":
			return m
	return {}


func block_covers(day: int, minute: int) -> bool:
	for m in meetings:
		if m.kind == "block" and int(m.day) == day and minute >= int(m.start) and minute < int(m.start) + int(m.dur):
			return true
	return false


func calendar_block_now() -> bool:
	return block_covers(Game.time.day, int(Game.time.minute))


func blocks_today() -> int:
	var n := 0
	for m in meetings_today():
		if m.kind == "block":
			n += 1
	return n


func conflicts(m: Dictionary) -> bool:
	for o in meetings_today():
		if o.kind == "block" and int(o.start) < int(m.start) + int(m.dur) and int(m.start) < int(o.start) + int(o.dur):
			return true
	return false


func add_block(start: int, dur: int = 30) -> bool:
	## A fake meeting on your own calendar. Shows you as "In a meeting".
	if blocks_today() >= 2:
		Bus.toast.emit("Policy 7.3: maximum two self-scheduled blocks per day.", "warn")
		return false
	if start + dur > Cfg.WORK_END or start < int(Game.time.minute):
		Bus.toast.emit("That slot is in the past or after hours.", "warn")
		return false
	for o in meetings_today():
		if o.kind == "block" and int(o.start) < start + dur and start < int(o.start) + int(o.dur):
			Bus.toast.emit("You already blocked that slot.", "warn")
			return false
	if not Game.work.perform("fake_block", {"label": "Fake calendar block"}):
		return false
	var title := str(Game.pick(Db.lines("block_titles")))
	add_meeting({"title": title, "start": start, "dur": dur, "kind": "block", "who": "me", "video": false})
	if Game.chance(22.0 * float(Game.diff().boss_check)):
		Game.time.schedule(Game.time.abs_at(Game.time.day, start + dur + 3), "event", {"id": "block_audit", "ctx": {"title": title}})
	Bus.toast.emit("Blocked %s-%s: \"%s\"." % [Cfg.fmt_time(start), Cfg.fmt_time(start + dur), title], "good")
	Game.presence.touch()
	return true


func can_dodge(m: Dictionary) -> bool:
	return (m.state == "upcoming" or m.state == "ringing") and not bool(m.no_dodge)


func decline_excuse(mid: String, excuse_id: String) -> Dictionary:
	var m := meeting(mid)
	if m.is_empty() or not can_dodge(m) or bool(m.excuse_tried) or not Db.claims.has(excuse_id):
		return {"done": false}
	if not Game.work.perform("excuse", {"label": str(Db.claims[excuse_id].title)}):
		return {"done": false}
	m.excuse_tried = true
	var boss := Game.npcs.boss_id()
	var who := str(m.who) if Game.npcs.has(str(m.who)) else boss
	Game.deception.observe("desk_message" if Game.presence.at_desk else "phone_message")
	var att := Game.deception.attempt(excuse_id, "meeting", who, str(m.title))
	var line := str(Db.claims[excuse_id].line)
	var cl: Claim = att.claim
	if cl != null:
		line = line.replace("{subject}", cl.subject)
	post(boss, "me", "Re: %s - %s" % [str(m.title), line])
	var ok := bool(att.ok)
	var reply := str(att.say)
	if ok and bool(m.mandatory) and not Game.chance(70.0):
		ok = false
		reply = "Sorry to hear that, but this one is mandatory. See you there."
	if ok:
		m.state = "excused"
		Game.bump("meetings_avoided")
		post(boss, who if threads.has(who) else boss, reply, "good")
		Bus.toast.emit("You're excused from \"%s\"." % str(m.title), "good")
		Bus.sfx.emit("good")
	else:
		Game.stats.add("susp", 5.0, "Excuse rejected")
		post(boss, boss, reply, "bad")
		Bus.toast.emit("Excuse rejected. You still have to deal with \"%s\"." % str(m.title), "bad")
		Bus.sfx.emit("bad")
	Bus.meeting_changed.emit(m)
	Bus.comms_changed.emit()
	return {"done": true, "ok": ok, "say": reply}


func decline_conflict(mid: String) -> bool:
	## Bureaucracy: "sorry, I have a conflict" — only works if you really do.
	var m := meeting(mid)
	if m.is_empty() or not can_dodge(m):
		return false
	if not conflicts(m):
		Bus.toast.emit("You have no conflicting calendar block. Create one first.", "warn")
		return false
	if not Game.work.perform("decline_conflict", {"label": "Decline %s" % str(m.title)}):
		return false
	if not bool(m.mandatory) or Game.chance(55.0):
		m.state = "declined"
		Game.bump("meetings_avoided")
		Bus.toast.emit("Declined \"%s\": calendar conflict. The system accepted it without a human involved." % str(m.title), "good")
	else:
		Game.stats.add("susp", 4.0, "Tried to decline a mandatory meeting")
		say(Game.npcs.boss_id(), "Move your other thing. %s is mandatory." % str(m.title))
		m.no_dodge = true
	Bus.meeting_changed.emit(m)
	return true


func can_send_clone(m: Dictionary) -> String:
	## "" if a clone could attend this meeting, otherwise why not.
	if not can_dodge(m):
		return "This one cannot be avoided."
	if not Game.automation.can("attend_meetings"):
		return "Needs a working %s." % Game.automation.owner_of("attend_meetings")
	if bool(m.mandatory) and Game.automation.effect("attend_mandatory", 0.0) <= 0.0:
		return "Mandatory meetings need the Meeting Assistant running as well."
	return ""


func send_clone(mid: String) -> bool:
	## Let your AI double attend instead of you.
	var m := meeting(mid)
	if m.is_empty():
		return false
	var why := can_send_clone(m)
	if why != "":
		Bus.toast.emit(why, "warn")
		return false
	if not Game.work.perform("send_clone", {"label": "Send clone to %s" % str(m.title)}):
		return false
	if Game.automation.try_attend(m):
		m.state = "looped"
		Game.bump("meetings_avoided")
		Game.stats.add("ill", 3.0, "Attended (in spirit)")
		Bus.toast.emit("Your clone is attending \"%s\" for you. It nods beautifully." % str(m.title), "good")
	Bus.meeting_changed.emit(m)
	return true


# ---------------------------------------------------------------------------
# Live calls
# ---------------------------------------------------------------------------

func join(mid: String, via_phone: bool = false) -> bool:
	var m := meeting(mid)
	if m.is_empty() or m.state != "ringing":
		return false
	m.state = "live"
	var beats := Dialogue.build(m)
	live_call = {
		"mid": mid, "beats": beats, "i": 0, "phone": via_phone,
		"per": maxi(2, int(float(m.dur) / float(maxi(1, beats.size())))),
	}
	Game.presence.in_call = true
	Game.activities.stop()
	Game.time.set_speed(1.0)
	Game.presence.update()
	Game.deception.observe("phone_meeting" if via_phone else "video_meeting")
	Game.events.on_call_join()
	Bus.meeting_changed.emit(m)
	return true


func in_call() -> bool:
	return Game.active and not live_call.is_empty()


func call_context() -> String:
	return "phone" if bool(live_call.get("phone", false)) else "video"


func call_meeting() -> Dictionary:
	return meeting(str(live_call.get("mid", "")))


func call_beat() -> Dictionary:
	if not in_call():
		return {}
	if int(live_call.i) >= live_call.beats.size():
		return {}
	return live_call.beats[int(live_call.i)]


func call_choices() -> Array:
	var b := call_beat()
	if b.is_empty():
		return []
	var out: Array = b.choices.duplicate()
	if Game.automation.can("meeting_answers"):
		out.append({
			"t": "Let the Meeting Assistant answer.", "a": "assistant_answer", "ability": "meeting_answers",
			"ok": {"susp": -1, "ill": 3, "say": str(Game.pick(Db.lines("assistant_ok")))},
			"ko": {"susp": 7, "say": str(Game.pick(Db.lines("assistant_absurd")))},
		})
	if not bool(call_meeting().get("no_dodge", false)) and not bool(b.get("no_excuse", false)):
		out.append({"t": "Bail out with an excuse...", "a": "excuse", "excuse": true, "ok": {"end": true}, "ko": {"susp": 8}})
	return out


func _call_ctx() -> Dictionary:
	var b := call_beat()
	return {"from": str(b.get("who", Game.npcs.boss_id())), "about": str(call_meeting().get("title", "Call")), "via": call_context()}


func call_choose(idx: int, excuse_id: String = "") -> Dictionary:
	if not in_call():
		return {"done": false}
	var list := call_choices()
	if idx < 0 or idx >= list.size():
		return {"done": false}
	var c: Dictionary = list[idx]
	var res := resolve(c, call_context(), _call_ctx(), excuse_id)
	if not res.done:
		return res
	if bool(c.get("excuse", false)) and res.ok:
		res["bailed"] = true
	_call_step(res)
	return res


func call_timeout() -> Dictionary:
	## The player froze. Either the assistant steps in, or there is silence.
	if not in_call():
		return {"done": false}
	if Game.automation.can("auto_answer"):
		var list := call_choices()
		for i in list.size():
			if str(list[i].get("ability", "")) == "meeting_answers":
				return call_choose(i)
	var b := call_beat()
	var sil: Dictionary = b.get("silence", {"susp": 5, "say": "...{name}? You're on mute. Or frozen. Moving on."})
	apply(sil, "Awkward silence", _call_ctx())
	var res := {"done": true, "ok": false, "say": fmt(str(sil.get("say", ""))), "end": false}
	_call_step(res)
	return res


func _call_step(res: Dictionary) -> void:
	if not in_call():
		return
	var per := int(live_call.per)
	live_call.i = int(live_call.i) + 1
	Game.bump("pretend_min", per)
	Game.stats.add("health", -Cfg.BEAT_HP * float(Game.diff().stress), "Meeting fatigue")
	if not in_call():
		res.end = true
		return
	# Nobody expects answers from someone who is in a meeting.
	for p in prompts:
		p.due = int(p.due) + per
	Game.time.advance(per)
	if not in_call():
		res.end = true
		return
	if bool(res.get("end", false)) or int(live_call.i) >= live_call.beats.size():
		res.end = true
		call_end(bool(res.get("bailed", false)))


func call_end(bailed: bool = false) -> void:
	if not in_call():
		return
	var m := call_meeting()
	live_call = {}
	Game.presence.in_call = false
	if not m.is_empty():
		if bailed:
			m.state = "excused"
			Game.bump("meetings_avoided")
		else:
			m.state = "done"
			Game.bump("meetings_attended")
			var after: Dictionary = Db.dialogues.get(str(m.script), {}).get("after", {})
			if not after.is_empty():
				apply(after, str(m.title))
			if str(m.script) == "review":
				Game.events.review_verdict()
		Bus.meeting_changed.emit(m)
	Game.presence.touch()
	Game.presence.update()


func call_hang_up() -> void:
	## Leaving mid-meeting without an excuse.
	if not in_call():
		return
	var m := call_meeting()
	Game.stats.add("susp", 9.0 if bool(m.get("mandatory", false)) else 6.0, "Dropped off a call")
	say(Game.npcs.boss_id(), "Did you just... leave?", false)
	call_end(false)


func reject_call(mid: String) -> void:
	## Decline an incoming surprise call outright.
	var m := meeting(mid)
	if m.is_empty() or m.state != "ringing":
		return
	_miss(m, true)


func _miss(m: Dictionary, rejected: bool = false) -> void:
	if Game.presence.covered() and not bool(m.no_dodge):
		m.state = "excused"
		Game.bump("meetings_avoided")
		Bus.meeting_changed.emit(m)
		return
	m.state = "missed"
	Game.bump("meetings_missed")
	var pen := 13.0 if bool(m.mandatory) else 8.0
	if bool(m.no_dodge):
		pen = 30.0
	if rejected:
		pen = 6.0
	Game.stats.add("susp", pen, "Missed: %s" % str(m.title))
	Game.stats.add("ill", -4.0, "Missed: %s" % str(m.title))
	Game.npcs.ignored(Game.npcs.boss_id())
	say(Game.npcs.boss_id(), str(Game.pick(Db.lines("missed"))).replace("{m}", str(m.title)))
	Bus.meeting_changed.emit(m)


# ---------------------------------------------------------------------------
# Mail
# ---------------------------------------------------------------------------

func add_mail(def: Dictionary) -> Dictionary:
	var m := add_mail_raw({"from": str(def.from), "subject": str(def.subject), "body": str(def.body), "key": str(def.id)})
	if not def.choices.is_empty():
		add_prompt({
			"id": str(def.id), "kind": "mail", "from": str(def.from), "text": str(def.subject), "choices": def.choices,
			"window": int(def.window), "expire": def.expire if not def.expire.is_empty() else {"susp": 4}, "mail": str(m.id),
		})
	else:
		notify("SynerMail", str(def.subject), "info", false)
	return m


func add_mail_raw(def: Dictionary) -> Dictionary:
	var m := {
		"id": Game.next_id("e"), "key": str(def.get("key", "")), "from": str(def.from),
		"subject": fmt(str(def.subject)), "body": fmt(str(def.body)), "day": Game.time.day,
		"t": int(Game.time.minute), "read": bool(def.get("sent", false)), "sent": bool(def.get("sent", false)),
	}
	mails.append(m)
	if mails.size() > 60:
		mails.pop_front()
	Bus.mail_added.emit(m)
	Bus.comms_changed.emit()
	return m


func unread_mail() -> int:
	var n := 0
	for m in mails:
		if not bool(m.read):
			n += 1
	return n


# ---------------------------------------------------------------------------
# Status and the minute tick
# ---------------------------------------------------------------------------

func set_focus() -> bool:
	## Flip your status to "Focusing". Costs credibility if abused.
	var p := Game.presence
	if Game.time.now() < p.focus_until:
		return false
	if not Game.work.perform("set_focus", {"label": "Set status to Focusing"}):
		return false
	p.focus_used += 1
	p.focus_until = Game.time.now() + 40
	if p.focus_used >= 3:
		Game.stats.add("susp", 5.0, "Always 'Focusing'")
		say(Game.npcs.boss_id(), "You've been 'Focusing' three times today. On what?")
	else:
		Bus.toast.emit("Status: Focusing (40 min). Nobody expects a reply.", "good")
	p.update()
	return true


func close_day() -> void:
	## 17:00 — wrap up anything still hanging.
	if in_call():
		call_end(false)
	for p in prompts.duplicate():
		prompts.erase(p)
		Game.bump("prompts_ignored")
		Game.stats.add("susp", 3.0, "Left on read overnight")
	for m in meetings:
		if m.state == "ringing":
			_miss(m)
		elif m.state == "upcoming" and int(m.day) == Game.time.day:
			m.state = "done"
	Game.deception.close_day()
	Bus.comms_changed.emit()


func _on_minute() -> void:
	if not Game.time.running() or Game.time.phase != "work":
		return
	var now := Game.time.now()
	var t := int(Game.time.minute)
	# Prompts: expire, or let a chatbot take the routine ones.
	if not in_call():
		var early := Game.automation.effect("reply_early", 0.0) > 0.0
		for p in prompts.duplicate():
			if not Game.time.running():
				return
			if now >= int(p.due):
				_expire(p)
			elif bool(p.routine) and not bool(p.auto_tried) and Game.automation.can("auto_reply"):
				var wait := int(float(p.window) * (0.2 if early else 0.5))
				if now - int(p.born) >= wait:
					_auto_reply(p)
	if not Game.time.running():
		return
	# Meetings
	for m in meetings:
		if int(m.day) != Game.time.day:
			continue
		var start := int(m.start)
		match str(m.state):
			"upcoming":
				if m.kind == "block":
					if t >= start:
						m.state = "live"
						Game.presence.update()
						Bus.meeting_changed.emit(m)
				elif t >= start:
					if not ringing().is_empty() or in_call():
						m.start = t + 1          # never two calls at once: this one waits
						continue
					if Game.automation.is_on(Game.automation.provider("attend_meetings")) and can_send_clone(m) == "" and Game.automation.try_attend(m):
						m.state = "looped"
						Game.bump("meetings_avoided")
						Game.stats.add("ill", 3.0, "Attended (in spirit)")
						Bus.toast.emit("Your clone joined \"%s\" so you don't have to." % str(m.title), "good")
						Bus.meeting_changed.emit(m)
						continue
					m.state = "ringing"
					m.ring_until = t + maxi(4, int(round((5.0 if bool(m.surprise) else 8.0) * float(Game.diff().window))))
					if Game.presence.can_notice():
						Bus.sfx.emit("ring")
						Game.time.alert()
					else:
						Bus.sfx.emit("ping_far")
					Bus.meeting_changed.emit(m)
				elif not bool(m.warned) and t >= start - 10:
					m.warned = true
					notify("SynerCalendar", "\"%s\" starts in %d min." % [str(m.title), start - t], "info", false)
			"ringing":
				if t > int(m.ring_until):
					_miss(m)
			"live":
				if m.kind == "block" and t >= start + int(m.dur):
					m.state = "done"
					Game.presence.update()
					Bus.meeting_changed.emit(m)
			"looped":
				if t >= start + int(m.dur):
					m.state = "done"
					Bus.meeting_changed.emit(m)
