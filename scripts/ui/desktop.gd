class_name Desktop
extends Control
## SynerOS — the fictional corporate desktop shown full-screen at the work
## computer. Hosts SynerTeams, SynerTasks, SynerCalendar, SynerMail and
## ShadowIT (your own, less official, gadget control panel).

signal closed()
signal join_requested(meeting_id: String)

const APPS := [
	{"id": "teams", "name": "SynerTeams", "icon": "chat"},
	{"id": "tasks", "name": "SynerTasks", "icon": "task"},
	{"id": "cal", "name": "SynerCalendar", "icon": "cal"},
	{"id": "mail", "name": "SynerMail", "icon": "mail"},
	{"id": "shadow", "name": "ShadowIT", "icon": "gear"},
]

var app := "teams"
var thread := ""
var task_id := ""
var mail_id := ""
var excuse_for := ""               ## meeting id whose excuse picker is open
var block_for := ""                ## ticket id whose "it's blocked" picker is open
var _content: Control
var _side_buttons: Dictionary = {}
var _badges: Dictionary = {}
var _status: Label
var _status_dot: Panel
var _clock: Label
var _title: Label
var _banner: PanelContainer
var _offline: Control
var _dirty := true
var _timers: Array = []            ## [{bar, label, due, window}]
var _scroll_bottom: ScrollContainer
var _t := 0.0


func _ready() -> void:
	UI.full(self)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The room dims behind the monitor; the HUD column keeps a strip on the right.
	var dim := ColorRect.new()
	dim.color = UI.BG
	UI.full(dim)
	add_child(dim)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.sb(Color("0d0c14"), 16, 0, Color.TRANSPARENT, 8, 8))
	UI.full(frame)
	frame.offset_left = 12
	frame.offset_top = 12
	frame.offset_bottom = -12
	frame.offset_right = -(Hud.COL_W + 28.0)
	add_child(frame)
	var screen := Control.new()
	screen.clip_contents = true
	frame.add_child(screen)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UI.sb(UI.OS_BG, 9))
	UI.full(bg)
	screen.add_child(bg)
	var root := UI.hbox(0)
	UI.full(root)
	screen.add_child(root)
	# Sidebar
	var side := PanelContainer.new()
	var side_sb := UI.sb(UI.OS_SIDE, 0, 0, Color.TRANSPARENT, 8, 12)
	side_sb.corner_radius_top_left = 9
	side_sb.corner_radius_bottom_left = 9
	side.add_theme_stylebox_override("panel", side_sb)
	side.custom_minimum_size = Vector2(92, 0)
	root.add_child(side)
	var sv := UI.vbox(6)
	side.add_child(sv)
	var logo := UI.title("S", 34, Color.WHITE)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(logo)
	sv.add_child(UI.gap(1, 8))
	for a in APPS:
		var b := UI.Clicky.new()
		b.setup(Color(1, 1, 1, 0.0), Color.TRANSPARENT, 0, false, 10)
		b.tooltip_text = str(a.name)
		var col := UI.vbox(2)
		var ic := UI.icon(str(a.icon), 26, Color.WHITE)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(ic)
		var nm := UI.label(str(a.name).replace("Syner", ""), 10, Color("c8d2f0"), true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(nm)
		b.add_child(col)
		b.pressed.connect(open_app.bind(str(a.id)))
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(76, 62)
		b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(b)
		var badge := UI.pill("0", UI.RED, 11, true)
		badge.position = Vector2(50, 0)
		badge.visible = false
		holder.add_child(badge)
		sv.add_child(holder)
		_side_buttons[a.id] = b
		_badges[a.id] = badge
	sv.add_child(UI.spacer())
	var off := UI.button("Log off", close, "os_danger", 12)
	off.tooltip_text = "Leave the desk (Esc)"
	sv.add_child(off)
	# Main column
	var main := UI.vbox(0)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(main)
	var top := PanelContainer.new()
	var top_sb := UI.sb(UI.OS_PANEL, 0, 0, Color.TRANSPARENT, 18, 9)
	top_sb.corner_radius_top_right = 9
	top.add_theme_stylebox_override("panel", top_sb)
	main.add_child(top)
	var th := UI.hbox(12)
	top.add_child(th)
	_title = UI.title("SynerTeams", 22, UI.OS_TEXT)
	th.add_child(_title)
	th.add_child(UI.spacer())
	var focus := UI.button("Set status: Focusing", func():
		Game.comms.set_focus()
		_dirty = true
	, "os_ghost", 12)
	focus.tooltip_text = "FAKE WORK. 40 minutes during which nobody expects you to be visibly active. Suspicious the third time in a day."
	th.add_child(focus)
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", UI.sb(UI.OS_SOFT, 20, 1, UI.OS_LINE, 10, 4))
	var sh := UI.hbox(6)
	_status_dot = Panel.new()
	_status_dot.custom_minimum_size = Vector2(10, 10)
	_status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh.add_child(_status_dot)
	_status = UI.label("Available", 13, UI.OS_TEXT, true)
	sh.add_child(_status)
	sp.add_child(sh)
	th.add_child(sp)
	_clock = UI.title("09:00", 20, UI.OS_TEXT)
	th.add_child(_clock)
	var line := ColorRect.new()
	line.color = UI.OS_LINE
	line.custom_minimum_size = Vector2(0, 1)
	main.add_child(line)
	_banner = PanelContainer.new()
	_banner.add_theme_stylebox_override("panel", UI.sb(Color("ffe1e5"), 0, 0, Color.TRANSPARENT, 18, 10))
	_banner.visible = false
	main.add_child(_banner)
	_content = MarginContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_content.add_theme_constant_override(m, 16)
	main.add_child(_content)
	Bus.comms_changed.connect(_mark)
	Bus.task_changed.connect(func(_t2): _mark())
	Bus.meeting_changed.connect(func(_m): _mark())
	Bus.gadget_changed.connect(func(_g): _mark())
	Bus.thing_changed.connect(func(_g): _mark())
	Game.presence.changed.connect(func(_s): _mark())
	Game.economy.money_changed.connect(func(_a, _b, _c): _mark())
	Game.economy.favors_changed.connect(func(_v): _mark())


func _mark() -> void:
	_dirty = true


func open(which: String = "") -> void:
	if not Game.comms.threads.has(thread):
		thread = Game.npcs.boss_id()
	if which != "":
		app = which
	elif not Game.comms.ringing().is_empty():
		app = "cal"
	elif not Game.comms.pending("chat").is_empty():
		app = "teams"
		thread = str(Game.comms.pending("chat")[0].thread)
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	excuse_for = ""
	block_for = ""
	_dirty = true


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func open_app(id: String) -> void:
	app = id
	excuse_for = ""
	Game.presence.touch()
	_dirty = true


func open_prompt(pid: String) -> void:
	var p := Game.comms.prompt(pid)
	if p.is_empty():
		return
	if str(p.kind) == "mail":
		app = "mail"
		mail_id = str(p.mail)
	else:
		app = "teams"
		thread = str(p.thread)
	_dirty = true


func _process(delta: float) -> void:
	if not visible or not Game.active:
		return
	_t += delta
	var st: String = str(Game.presence.status)
	var info: Dictionary = Cfg.PRESENCE[st]
	_status.text = str(info.label) if Game.time.phase == "work" else "After hours"
	_status_dot.add_theme_stylebox_override("panel", UI.sb(info.color, 5))
	_clock.text = "%s  %s" % [Cfg.DAYS_SHORT[clampi(int(Game.time.day), 0, 4)], Cfg.fmt_time(fposmod(Game.time.clock(), 1440.0))]
	var now := float(Game.time.now()) + fposmod(Game.time.clock(), 1.0)
	for tm in _timers:
		if not is_instance_valid(tm.bar):
			continue
		var left := float(tm.due) - now
		(tm.bar as StatBar).value = clampf(left, 0.0, float(tm.window))
		(tm.bar as StatBar).color = Color("d6455b") if left < 6.0 else (Color("e0a100") if left < 12.0 else Color("2f9e5b"))
		if tm.label != null and is_instance_valid(tm.label):
			(tm.label as Label).text = "%d min to answer" % int(maxf(0.0, ceil(left)))
	if _dirty:
		_dirty = false
		_rebuild()


# ---------------------------------------------------------------------------
# Shared pieces
# ---------------------------------------------------------------------------

func _card(pad: int = 14) -> PanelContainer:
	return UI.panel(UI.OS_PANEL, 10, pad, 1, UI.OS_LINE)


func _h(text: String, size: int = 16) -> Label:
	var l := UI.label(text, size, UI.OS_TEXT, true)
	return l


func _dimtext(text: String, size: int = 13) -> Label:
	return UI.wrap(text, size, UI.OS_DIM)


func _timer_row(due: int, window: int) -> Control:
	var v := UI.vbox(3)
	var l := UI.label("", 12, UI.OS_DIM, true)
	v.add_child(l)
	var bar := StatBar.new()
	bar.max_value = maxf(1.0, float(window))
	bar.custom_minimum_size = Vector2(0, 7)
	v.add_child(bar)
	_timers.append({"bar": bar, "label": l, "due": due, "window": window})
	return v


func _rebuild() -> void:
	_timers.clear()
	_scroll_bottom = null
	UI.clear(_content)
	for a in APPS:
		var b: UI.Clicky = _side_buttons[a.id]
		var on: bool = a.id == app
		b.add_theme_stylebox_override("panel", UI.sb(Color(1, 1, 1, 0.16 if on else 0.0), 10, 0, Color.TRANSPARENT, 6, 6))
		if a.id == app:
			_title.text = str(a.name)
	_set_badge("teams", Game.comms.pending("chat").size(), Game.comms.unread_total())
	_set_badge("mail", Game.comms.pending("mail").size(), Game.comms.unread_mail())
	_set_badge("tasks", 0, Game.work.open_tasks().size())
	_set_badge("cal", 1 if not Game.comms.ringing().is_empty() else 0, 0)
	_set_badge("shadow", 1 if Game.automation.any_broken() else 0, 0)
	_build_banner()
	if not Game.home.internet_up():
		_build_offline()
		return
	if Game.time.phase != "work" and app != "shadow":
		var c := _card(30)
		var v := UI.vbox(8)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		c.add_child(v)
		var t := UI.title("It's after hours.", 30, UI.OS_TEXT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var d := _dimtext("Nobody is watching. Nobody is pinging. Why are you still here? Go and enjoy your evening.", 15)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(d)
		_content.add_child(c)
		return
	match app:
		"teams":
			_build_teams()
		"tasks":
			_build_tasks()
		"cal":
			_build_cal()
		"mail":
			_build_mail()
		"shadow":
			_build_shadow()
	if _scroll_bottom != null:
		_to_bottom.call_deferred(_scroll_bottom)


func _to_bottom(sc: ScrollContainer) -> void:
	await get_tree().process_frame
	if is_instance_valid(sc):
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)


func _set_badge(id: String, urgent: int, soft: int) -> void:
	var b: PanelContainer = _badges[id]
	var n := urgent if urgent > 0 else soft
	b.visible = n > 0
	(b.get_child(0) as Label).text = str(n)
	b.add_theme_stylebox_override("panel", UI.sb(Color("d6455b") if urgent > 0 else Color("6b7594"), 20, 0, Color.TRANSPARENT, 7, 1))
	(b.get_child(0) as Label).add_theme_color_override("font_color", Color.WHITE)


func _build_banner() -> void:
	UI.clear(_banner)
	var ring := Game.comms.ringing()
	var risky := "desk_message" in Game.deception.forbidden_now()
	_banner.visible = (not ring.is_empty() and not Game.comms.in_call()) or risky
	if not _banner.visible:
		return
	if ring.is_empty() or Game.comms.in_call():
		var titles: Array = []
		for c in Game.deception.live_claims():
			if "desk_message" in c.contradicted_by:
				titles.append(str(Game.deception.def(c.type).title).to_lower())
		var wh := UI.hbox(10)
		_banner.add_child(wh)
		wh.add_child(UI.icon("warn", 22, Color("b3243a")))
		wh.add_child(UI.wrap("You told them: %s. Anything you send from this computer will contradict it. Use your phone, or wait it out." % ", ".join(titles), 14, Color("7a1626")))
		return
	var h := UI.hbox(12)
	_banner.add_child(h)
	h.add_child(UI.icon("call", 26, Color("b3243a")))
	var t := UI.label(str(ring.title) if str(ring.kind) == "call" else "%s is starting now" % str(ring.title), 16, Color("7a1626"), true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	_meeting_buttons(h, ring)


func _build_offline() -> void:
	var c := _card(30)
	var v := UI.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(v)
	var ic := UI.icon("wifi", 64, Color("b3243a"))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var t := UI.title("No internet connection", 30, UI.OS_TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := _dimtext("The router is unplugged. Nobody can reach you, and you can't see what they're sending. Messages are piling up and their timers are still running.", 15)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	_content.add_child(c)


# ---------------------------------------------------------------------------
# SynerTeams
# ---------------------------------------------------------------------------

func _build_teams() -> void:
	var split := UI.hbox(14)
	_content.add_child(split)
	# Thread list
	var lc := _card(8)
	lc.custom_minimum_size = Vector2(250, 0)
	split.add_child(lc)
	var lv := UI.vbox(3)
	lc.add_child(lv)
	for tid in Game.comms.thread_order():
		var th: Dictionary = Game.comms.threads[tid]
		var channel := Game.comms.is_channel(tid)
		var pending := Game.comms.prompt_for_thread(tid)
		var on: bool = tid == thread
		var b := UI.Clicky.new()
		b.setup(Color("e7ecfb") if on else UI.OS_PANEL, Color.TRANSPARENT, 0, true, 8)
		var h := UI.hbox(8)
		if not channel:
			h.add_child(UI.avatar(tid, 30))
		else:
			var hash_l := UI.title("#", 22, UI.OS_DIM)
			hash_l.custom_minimum_size = Vector2(30, 0)
			hash_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			h.add_child(hash_l)
		var col := UI.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UI.label(Game.comms.thread_name(tid).trim_prefix("# "), 14, UI.OS_TEXT, true))
		var last := ""
		if not th.msgs.is_empty():
			last = str(th.msgs[th.msgs.size() - 1].text)
		var ll := UI.label(last, 11, UI.OS_DIM)
		ll.clip_text = true
		ll.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(ll)
		h.add_child(col)
		if not pending.is_empty():
			h.add_child(UI.pill("REPLY", Color("d6455b"), 10, true))
		elif int(th.unread) > 0 and not on:
			h.add_child(UI.pill(str(int(th.unread)), Color("6b7594"), 10))
		elif Game.social.is_colleague(tid):
			# A dot in the colour of how they feel about you.
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(10, 10)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.add_theme_stylebox_override("panel", UI.sb(Game.social.tier_color(tid).darkened(0.15), 5))
			h.add_child(dot)
		b.add_child(h)
		b.pressed.connect(func():
			thread = tid
			Game.presence.touch()
			_dirty = true
		)
		lv.add_child(b)
	# Conversation
	var rc := _card(0)
	rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(rc)
	var rv := UI.vbox(0)
	rc.add_child(rv)
	var head := UI.margin(null, 16, 12, 16, 10)
	var hh := UI.hbox(10)
	head.add_child(hh)
	hh.add_child(_h(Game.comms.thread_name(thread), 18))
	if not Game.comms.is_channel(thread) and Game.npcs.has(thread):
		hh.add_child(UI.label(Game.npcs.role(thread), 12, UI.OS_DIM))
		var mood := Game.npcs.mood(thread)
		# For colleagues the friendship panel below says where you stand; their
		# mood is only worth a pill when it is not the ordinary one.
		if mood != "neutral" or not Game.social.is_colleague(thread):
			var mcol: Color = NPCManager.MOOD_INFO[mood].color
			var mp := UI.pill(Game.npcs.mood_label(thread).to_upper(), mcol.darkened(0.35), 9)
			mp.mouse_filter = Control.MOUSE_FILTER_STOP
			mp.tooltip_text = "How %s feels about you right now. It changes how readily your lies are believed (%+d%%)." % [Game.npcs.first_name(thread), int(round(Game.npcs.trust(thread)))]
			hh.add_child(mp)
		if thread == Game.npcs.boss_id() and Game.npcs.escalation > 0:
			hh.add_child(UI.pill(Game.npcs.escalation_name().to_upper(), Color("b3243a"), 9, true))
	hh.add_child(UI.spacer())
	if Game.comms.can_react(thread):
		var rb := UI.button("React with an emoji", func():
			Game.comms.react(thread)
		, "os_ghost", 12)
		rb.tooltip_text = "FAKE WORK. Visible engagement: a little Productivity Illusion for 1 energy."
		hh.add_child(rb)
	rv.add_child(head)
	if Game.social.is_colleague(thread):
		rv.add_child(_colleague_panel(thread))
	var sep := ColorRect.new()
	sep.color = UI.OS_LINE
	sep.custom_minimum_size = Vector2(0, 1)
	rv.add_child(sep)
	var msgs := UI.vbox(10)
	var sc := UI.scroll(UI.margin(msgs, 16, 12, 16, 12))
	rv.add_child(sc)
	_scroll_bottom = sc
	var list: Array = Game.comms.threads[thread].msgs
	if list.is_empty():
		msgs.add_child(_dimtext("Nothing here yet. Enjoy it while it lasts."))
	for m in list.slice(maxi(0, list.size() - 40)):
		msgs.add_child(_bubble(m))
	Game.comms.mark_read(thread) if int(Game.comms.threads[thread].unread) > 0 else null
	# Composer / choices
	var pending := Game.comms.prompt_for_thread(thread)
	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", UI.sb(UI.OS_SOFT, 0, 0, Color.TRANSPARENT, 16, 12))
	rv.add_child(foot)
	var fv := UI.vbox(8)
	foot.add_child(fv)
	if pending.is_empty():
		fv.add_child(_dimtext("Nobody is waiting on you here." if Game.social.is_colleague(thread) else "Nobody is waiting on you here. Do not start conversations. That is how work happens.", 12))
		return
	var trow := UI.hbox(10)
	var timer := _timer_row(int(pending.due), int(pending.window))
	timer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(timer)
	if not bool(pending.stalled):
		var sb := UI.button("\"On it!\"  (stall)", func():
			Game.comms.stall(str(pending.id))
		, "os_ghost", 12)
		sb.tooltip_text = "DECEPTION. Buys extra time once. Costs 2 energy."
		trow.add_child(sb)
	fv.add_child(trow)
	var cl := ChoiceList.new()
	cl.light = true
	cl.hotkeys = true
	cl.picker_height = 470.0
	fv.add_child(cl)
	# The excuse picker needs the room: it takes over the conversation area.
	cl.picking_changed.connect(func(on: bool):
		sc.visible = not on
		foot.size_flags_vertical = Control.SIZE_EXPAND_FILL if on else Control.SIZE_FILL
		cl.size_flags_vertical = Control.SIZE_EXPAND_FILL if on else Control.SIZE_FILL
	)
	cl.show_choices(Game.comms.choices_of(pending), "chat", str(pending.from))
	cl.chosen.connect(func(i: int, ex: String):
		Game.comms.answer(str(pending.id), i, ex, "desk")
	)


func _colleague_panel(id: String) -> Control:
	## Where you stand with a colleague, and what they would do for you.
	var s := Game.social
	var name: String = Game.npcs.first_name(id)
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", UI.sb(UI.OS_SOFT, 0, 0, Color.TRANSPARENT, 16, 10))
	var v := UI.vbox(7)
	wrap.add_child(v)
	var top := UI.hbox(10)
	v.add_child(top)
	var tcol: Color = s.tier_color(id).darkened(0.3)
	top.add_child(UI.pill(s.tier_name(id).to_upper(), tcol, 10, true))
	var bar := UI.bar(tcol, 8)
	bar.value = Game.npcs.relationship(id)
	bar.custom_minimum_size = Vector2(150, 8)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(bar)
	var gap := s.to_next_tier(id)
	top.add_child(UI.label("%d/100%s" % [int(round(Game.npcs.relationship(id))), ("  (+%d to %s)" % [gap, str(Social.TIERS[s.tier(id) + 1].name)]) if gap > 0 else ""], 11, UI.OS_DIM, true))
	top.add_child(UI.spacer())
	var risk := s.snitch_chance(id)
	var rp := UI.pill("TELLS %s IF IGNORED: %d%%" % [Game.npcs.boss_name().to_upper(), int(round(risk))], Color("b3243a"), 10) if risk > 0.0 else UI.pill("WON'T TELL ON YOU", Color("1f8f4a"), 10)
	rp.mouse_filter = Control.MOUSE_FILTER_STOP
	rp.tooltip_text = "Leave %s's messages or calls unanswered and this is how likely they are to tell your manager. It falls as they like you more, and is zero for friends." % name
	top.add_child(rp)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	v.add_child(row)
	var talk := UI.button("Small talk", func(): s.small_talk(id), "os_ghost", 12)
	talk.disabled = s.talked_today(id)
	talk.tooltip_text = "SOCIAL. They like you a little more. Once a day each. Careful: it may remind them of something they wanted."
	row.add_child(talk)
	var price := s.gift_price()
	var gift := UI.button("Gift card  $%d" % price, func(): s.gift(id), "os_ghost", 12)
	gift.disabled = not s.can_gift() or not Game.economy.can_afford(price)
	gift.tooltip_text = "SOCIAL. They like you a lot more and owe you one favour. One gift card per day." if s.can_gift() else "One gift card per day."
	row.add_child(gift)
	for f in s.favours(id):
		var view := s.favour_view(id, f)
		if bool(view.passive):
			var pp := UI.pill(("ON: " if bool(view.ok) else "") + str(view.title) + ("" if bool(view.ok) else "  -  " + str(view.why)), Color("1f8f4a") if bool(view.ok) else UI.OS_DIM, 10)
			pp.mouse_filter = Control.MOUSE_FILTER_STOP
			pp.tooltip_text = str(view.hint)
			row.add_child(pp)
			continue
		var fid: String = str(view.id)
		var fb := UI.button(str(view.title), func(): s.ask(id, fid), "os" if bool(view.ok) else "os_ghost", 12)
		fb.disabled = not bool(view.ok)
		fb.tooltip_text = "%s  %s" % [str(Game.work.badge(str(view.act)).text), str(view.hint)] if bool(view.ok) else "%s. %s" % [str(view.why), str(view.hint)]
		if not bool(view.ok):
			fb.text = "%s  -  %s" % [str(view.title), str(view.why)]
		row.add_child(fb)
	return wrap


func _bubble(m: Dictionary) -> Control:
	var who: String = str(m.who)
	var me := who == "me"
	var kind: String = str(m.get("kind", ""))
	var row := UI.hbox(9)
	if kind == "sys":
		var l := UI.wrap(str(m.text), 12, UI.OS_DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(l)
		return row
	if me:
		row.add_child(UI.spacer(80))
	else:
		row.add_child(UI.avatar(who, 32))
	var col := UI.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL if not me else Control.SIZE_SHRINK_END
	var meta := UI.hbox(6)
	if me:
		meta.alignment = BoxContainer.ALIGNMENT_END
	meta.add_child(UI.label("You" if me else Game.npcs.display_name(who), 12, UI.OS_TEXT, true))
	meta.add_child(UI.label(Cfg.fmt_time(float(m.t)), 11, UI.OS_DIM))
	if kind == "auto":
		meta.add_child(UI.pill("generated", Color("1f8f4a"), 9))
	col.add_child(meta)
	var bg := Color("e3e9ff") if me else Color("f1f3f8")
	if kind == "bad":
		bg = Color("ffe1e5")
	elif kind == "good":
		bg = Color("e1f7e8")
	elif kind == "prompt":
		bg = Color("fff3d1")
	var p := UI.panel(bg, 12, 10)
	p.size_flags_horizontal = Control.SIZE_SHRINK_END if me else Control.SIZE_SHRINK_BEGIN
	var txt := UI.wrap(str(m.text), 14, UI.OS_TEXT)
	txt.custom_minimum_size = Vector2(minf(560.0, 60.0 + float(str(m.text).length()) * 8.0), 0)
	p.add_child(txt)
	col.add_child(p)
	if bool(m.get("reacted", false)):
		col.add_child(UI.pill(":thumbsup: 1", Color("3b5bdb"), 10))
	row.add_child(col)
	if not me:
		row.add_child(UI.spacer(80))
	return row


# ---------------------------------------------------------------------------
# SynerTasks
# ---------------------------------------------------------------------------

func _build_tasks() -> void:
	var split := UI.hbox(14)
	_content.add_child(split)
	var left := UI.vbox(10)
	left.custom_minimum_size = Vector2(360, 0)
	split.add_child(left)
	# Daily report
	var rep := _card()
	left.add_child(rep)
	var rv := UI.vbox(7)
	rep.add_child(rv)
	rv.add_child(_h("Daily status report"))
	var sent := Game.flag("report_day_%d" % int(Game.time.day))
	if sent:
		rv.add_child(_dimtext("Sent. %s may even have opened it." % Game.npcs.boss_name()))
	else:
		rv.add_child(_dimtext("Management loves a report. Nobody reads them, usually."))
		rv.add_child(_action_button("Generate a fake corporate report", "fake_report", "Big Productivity Illusion boost. Small chance %s actually reads it." % Game.npcs.boss_name(), func(): Game.work.fake_report(false)))
		rv.add_child(_action_button("Write a real, accurate report", "write_report", "", func(): Game.work.real_report()))
	# Ticket list
	var lc := _card(8)
	lc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(lc)
	var lv := UI.vbox(5)
	lc.add_child(UI.scroll(lv))
	var tasks: Array = Game.work.tasks.duplicate()
	tasks.sort_custom(func(a, b):
		if (a.status == "open") != (b.status == "open"):
			return a.status == "open"
		return int(a.due) < int(b.due))
	if tasks.is_empty():
		lv.add_child(UI.margin(_dimtext("No tickets. A beautiful, empty board."), 8, 8, 8, 8))
	var sel := Game.work.task(task_id)
	if sel.is_empty() and not tasks.is_empty():
		sel = tasks[0]
		task_id = str(sel.id)
	for t in tasks:
		var on: bool = str(t.id) == task_id
		var b := UI.Clicky.new()
		b.setup(Color("e7ecfb") if on else UI.OS_PANEL, UI.OS_LINE, 1, true, 8)
		var col := UI.vbox(4)
		var top := UI.hbox(6)
		top.add_child(UI.label(str(t.key), 12, UI.OS_DIM, true))
		top.add_child(_prio_pill(int(t.prio)))
		top.add_child(UI.spacer())
		top.add_child(_status_pill(t))
		col.add_child(top)
		var tl := UI.wrap(str(t.title), 13, UI.OS_TEXT)
		col.add_child(tl)
		if str(t.status) == "open":
			var pb := UI.bar(Color("2f9e5b"), 6)
			pb.value = float(t.fake)
			col.add_child(pb)
			col.add_child(UI.label("Due %s" % Game.work.due_text(int(t.due)), 11, Color("b3243a") if int(t.due) - Game.time.now() < 90 else UI.OS_DIM, true))
		b.add_child(col)
		b.pressed.connect(func():
			task_id = str(t.id)
			Game.presence.touch()
			_dirty = true
		)
		lv.add_child(b)
	# Detail
	var dc := _card(18)
	dc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(dc)
	if sel.is_empty():
		dc.add_child(_dimtext("Select a ticket."))
		return
	var dv := UI.vbox(10)
	dc.add_child(UI.scroll(dv))
	var th := UI.hbox(8)
	th.add_child(UI.label(str(sel.key), 14, UI.OS_DIM, true))
	th.add_child(_prio_pill(int(sel.prio)))
	th.add_child(_status_pill(sel))
	dv.add_child(th)
	dv.add_child(UI.wrap(str(sel.title), 22, UI.OS_TEXT))
	dv.add_child(_dimtext(str(sel.desc), 14))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	dv.add_child(grid)
	grid.add_child(UI.label("What %s sees" % Game.npcs.boss_name(), 13, UI.OS_DIM, true))
	var fb := UI.bar(Color("2f9e5b"), 12)
	fb.value = float(sel.fake)
	fb.custom_minimum_size = Vector2(260, 12)
	var fh := UI.hbox(8)
	fh.add_child(fb)
	fh.add_child(UI.label("%d%% \"done\"" % int(sel.fake), 13, UI.OS_TEXT, true))
	grid.add_child(fh)
	grid.add_child(UI.label("What exists", 13, UI.OS_DIM, true))
	var rb := UI.bar(Color("3b5bdb"), 12, float(sel.effort))
	rb.value = float(sel.real)
	rb.custom_minimum_size = Vector2(260, 12)
	var rh := UI.hbox(8)
	rh.add_child(rb)
	rh.add_child(UI.label("%d of %d work sessions" % [int(sel.real), int(sel.effort)], 13, UI.OS_TEXT, true))
	grid.add_child(rh)
	grid.add_child(UI.label("Deadline", 13, UI.OS_DIM, true))
	grid.add_child(UI.label(Game.work.due_text(int(sel.due)), 13, UI.OS_TEXT, true))
	if str(sel.by) != "":
		grid.add_child(UI.label("Being done by", 13, UI.OS_DIM, true))
		var who: String = str(Game.automation.def(str(sel.by)).get("display_name", Game.npcs.display_name(str(sel.by))))
		grid.add_child(UI.label(who + " (not you)", 13, Color("1f8f4a"), true))
	if str(sel.status) != "open":
		dv.add_child(_dimtext(_closed_text(sel), 14))
		return
	if str(sel.blocked) != "":
		grid.add_child(UI.label("Officially", 13, UI.OS_DIM, true))
		grid.add_child(UI.label("Blocked: %s" % str(Db.claims[str(sel.blocked)].title), 13, Color("9a5b00"), true))
	dv.add_child(UI.gap(1, 4))
	dv.add_child(_h("Ways to not do this"))
	var boss := Game.npcs.boss_name()
	if float(sel.fake) < 100.0:
		dv.add_child(_dimtext("At 100%% it 'looks done' and usually auto-closes at the deadline. Three or more fake updates make %s ask for a demo." % boss, 12))
	var id: String = str(sel.id)
	dv.add_child(_action_button("Post a fake progress update", "fake_update", "+22 to 34% reported progress, +Illusion.", func(): Game.work.task_fake(id), not Game.work.task_looks_done(sel), "Already looks 100% done."))
	if block_for == id:
		var bp := UI.panel(UI.OS_SOFT, 8, 10, 1, UI.OS_LINE)
		var bv := UI.vbox(6)
		bp.add_child(bv)
		var cl := ChoiceList.new()
		cl.light = true
		bv.add_child(cl)
		cl.show_excuses("ticket", Game.npcs.boss_id(), Game.work.blockers())
		cl.chosen.connect(func(_i: int, ex: String):
			block_for = ""
			if ex != "":
				Game.work.task_block(id, ex)
			_dirty = true
		)
		bv.add_child(UI.button("Never mind", func():
			block_for = ""
			_dirty = true
		, "os_ghost", 12))
		dv.add_child(bp)
	else:
		dv.add_child(_action_button("Tell %s it's blocked..." % boss, "excuse", "Pick a reason. It buys the ticket time, and goes on record: touching the ticket afterwards contradicts it.", func():
			block_for = id
		, str(sel.blocked) == "", "Already reported as blocked."))
	dv.add_child(_action_button("Open a clarification request with another team", "clarify", "A paper trail: 'waiting for another team' will check out. Once per ticket.", func(): Game.work.task_clarify(id), not bool(sel.clarified), "Already open on this ticket."))
	dv.add_child(_action_button("File a Form 27-B (Scope Change Request)", "change_request", "May bury the ticket in a steering committee forever. Either way the form backs up a 'process blocker'. One per day.", func(): Game.work.task_change_request(id), not Game.flag("cr_day_%d" % Game.time.day), "Today's form is already filed."))
	var offered := 0
	for who in Game.social.colleagues():
		for f in Game.social.favours(who):
			if not str(f.type) in ["ticket", "bury"]:
				continue
			var view := Game.social.favour_view(who, f, {"task": id})
			if bool(view.locked) and offered > 0:
				continue            # one "you need friends" row is enough
			offered += 1
			var fid: String = str(f.id)
			var label := "Favour: have %s do it" % Game.npcs.first_name(who) if str(f.type) == "ticket" else "Favour: have %s lose it" % Game.npcs.first_name(who)
			var free: bool = str(sel.by) == ""
			dv.add_child(_action_button(label, str(view.act), "%s You have %d." % [str(view.hint), Game.economy.favors], func(): Game.social.ask(who, fid, {"task": id}), bool(view.ok) and free, str(view.why) if free else "Already delegated."))
	if Game.automation.can("do_tickets") or str(Game.automation.autos.ai_task) != "":
		dv.add_child(_action_button("Hand it to your AI Doppelganger", "delegate_ai", "It works the ticket in the background while switched on. It may hallucinate.", func(): Game.work.task_ai(id), str(sel.by) == "" and Game.automation.can("do_tickets") and str(Game.automation.autos.ai_task) == "", "Your clone is off, broken or busy."))
	dv.add_child(UI.gap(1, 6))
	dv.add_child(_h("The other way"))
	dv.add_child(_action_button("Do the actual work (45 min session)", "work_task", "Real progress. %s would be thrilled. You would not." % boss, func(): Game.work.task_work(id), not Game.activities.busy(), "You're busy."))


func _closed_text(t: Dictionary) -> String:
	match str(t.status):
		"done":
			match str(t.how):
				"faked":
					return "Closed. It 'looked done', so the system closed it. Nothing was ever built."
				"me":
					return "Closed. You did this one. With your own hands. We don't talk about it."
				_:
					if Db.gadgets.has(str(t.how)):
						return "Closed by your AI clone. You contributed the electricity."
					return "Closed by %s on your behalf. Teamwork." % Game.npcs.display_name(str(t.how))
		"cancelled":
			if str(t.how) == "lost":
				return "Lost in Records, sub-basement 3. Officially, it never existed."
			return "Descoped: pending steering committee review (est. Q4). It will never come back."
		"failed":
			return "Failed. The deadline came and there was nothing to show. %s remembers." % Game.npcs.boss_name()
	return ""


func _prio_pill(p: int) -> Control:
	var names := ["", "P1 CRITICAL", "P2 HIGH", "P3 MEDIUM", "P4 LOW"]
	var cols := [UI.OS_DIM, Color("d6455b"), Color("e07b00"), Color("3b5bdb"), Color("6b7594")]
	return UI.pill(names[clampi(p, 1, 4)], cols[clampi(p, 1, 4)], 9)


func _status_pill(t: Dictionary) -> Control:
	match str(t.status):
		"open":
			if str(t.by) != "":
				return UI.pill("DELEGATED", Color("1f8f4a"), 9)
			if float(t.fake) >= 100.0:
				return UI.pill("LOOKS DONE", Color("1f8f4a"), 9)
			return UI.pill("IN PROGRESS" if float(t.fake) > 0.0 or int(t.real) > 0 else "TO DO", Color("3b5bdb"), 9)
		"done":
			return UI.pill("DONE", Color("1f8f4a"), 9, true)
		"cancelled":
			return UI.pill("DESCOPED", Color("6b7594"), 9, true)
	return UI.pill("FAILED", Color("d6455b"), 9, true)


func _action_button(text: String, act: String, hint: String, cb: Callable, ok: bool = true, why: String = "") -> Control:
	## A SynerOS action row. The badge and cost come straight from Actions,
	## so real work is always labelled the same way.
	var badge := Game.work.badge(act)
	var check := Game.work.can(act)
	if ok and not check.ok:
		ok = false
		why = str(check.why)
	var view := {"text": text, "badge": badge, "odds": -1.0, "ok": ok, "why": why, "cost": Game.work.energy_cost(act)}
	var c := UI.choice(view, Callable(), true)
	if hint != "" and ok:
		var col: VBoxContainer = c.get_child(0).get_child(0)
		col.add_child(UI.wrap(hint, 11, UI.OS_DIM))
	var armed := [false]
	c.pressed.connect(func():
		if Game.work.lethal(act) and not armed[0]:
			armed[0] = true
			Bus.sfx.emit("bad")
			Bus.toast.emit("That is REAL WORK. On this difficulty it ends your run. Click again if you mean it.", "bad")
			return
		Game.presence.touch()
		cb.call()
		_dirty = true
	)
	return c


# ---------------------------------------------------------------------------
# SynerCalendar
# ---------------------------------------------------------------------------

func _meeting_buttons(parent: Control, m: Dictionary) -> void:
	var mid: String = str(m.id)
	var st: String = str(m.state)
	if bool(m.get("casual", false)):
		# A colleague or a stranger: pick up, make an excuse, or say no.
		if st != "ringing":
			return
		parent.add_child(UI.button("Pick up", func(): join_requested.emit(mid), "os", 13))
		if Game.npcs.kind(str(m.who)) != "stranger" and not bool(m.excuse_tried):
			parent.add_child(UI.button("Excuse...", func():
				excuse_for = mid if excuse_for != mid else ""
				if excuse_for != "":
					app = "cal"          # the picker lives next to the entry in the calendar
				_dirty = true
			, "os_ghost", 12))
		parent.add_child(UI.button("Reject", func(): Game.comms.reject_call(mid), "os_danger", 12))
		return
	if st == "ringing":
		parent.add_child(UI.button("Join", func(): join_requested.emit(mid), "os", 13))
	if not Game.comms.can_dodge(m):
		if bool(m.no_dodge) and st in ["upcoming", "ringing"]:
			parent.add_child(UI.pill("CANNOT BE AVOIDED", Color("b3243a"), 10))
		return
	if Game.automation.has("attend_meetings"):
		var lb := UI.button("Send your clone", func(): Game.comms.send_clone(mid), "os_ghost", 12)
		var why := Game.comms.can_send_clone(m)
		lb.tooltip_text = "AUTOMATION. Your AI Doppelganger attends instead of you." if why == "" else why
		lb.disabled = why != ""
		parent.add_child(lb)
	var cb := UI.button("Decline: conflict", func(): Game.comms.decline_conflict(mid), "os_ghost", 12)
	cb.tooltip_text = "BUREAUCRACY. Only works if one of your own calendar blocks overlaps this meeting. The system approves it automatically."
	cb.disabled = not Game.comms.conflicts(m)
	parent.add_child(cb)
	if not bool(m.excuse_tried):
		parent.add_child(UI.button("Excuse...", func():
			excuse_for = mid if excuse_for != mid else ""
			if excuse_for != "":
				app = "cal"              # the picker lives next to the entry in the calendar
			_dirty = true
		, "os_ghost", 12))
	if st == "ringing" and bool(m.surprise):
		parent.add_child(UI.button("Reject", func(): Game.comms.reject_call(mid), "os_danger", 12))


func _build_cal() -> void:
	var split := UI.hbox(14)
	_content.add_child(split)
	var lc := _card(16)
	lc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(lc)
	var lv := UI.vbox(8)
	lc.add_child(UI.scroll(lv))
	lv.add_child(_h("%s - today" % Game.time.day_name(), 18))
	var meetings := Game.comms.meetings_today()
	if meetings.is_empty():
		lv.add_child(_dimtext("No meetings. Suspicious."))
	var now_t := int(Game.time.minute)
	for m in meetings:
		var is_block: bool = str(m.kind) == "block"
		var st: String = str(m.state)
		var past := st in ["done", "excused", "declined", "missed"]
		var bg := Color("eef1f8")
		var edge := Color("3b5bdb")
		if is_block:
			bg = Color("e1f7e8")
			edge = Color("2f9e5b")
		elif st == "ringing":
			bg = Color("ffe1e5")
			edge = Color("d6455b")
		elif past:
			bg = Color("f5f6f9")
			edge = Color("b6bdd0")
		var p := PanelContainer.new()
		var sbx := UI.sb(bg, 8, 0, edge, 12, 10)
		sbx.border_width_left = 5
		p.add_theme_stylebox_override("panel", sbx)
		var v := UI.vbox(6)
		p.add_child(v)
		var h := UI.hbox(8)
		v.add_child(h)
		h.add_child(UI.label("%s - %s" % [Cfg.fmt_time(float(m.start)), Cfg.fmt_time(float(int(m.start) + int(m.dur)))], 13, UI.OS_DIM, true))
		var tl := UI.label(str(m.title), 15, UI.OS_DIM if past else UI.OS_TEXT, true)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.clip_text = true
		h.add_child(tl)
		if is_block:
			h.add_child(UI.pill("YOUR FAKE BLOCK", Color("1f8f4a"), 9))
		elif bool(m.get("casual", false)):
			h.add_child(UI.pill("CALL", Color("b0417a"), 9))
		elif bool(m.mandatory):
			h.add_child(UI.pill("MANDATORY", Color("b3243a"), 9))
		else:
			h.add_child(UI.pill("OPTIONAL-ISH", Color("6b7594"), 9))
		h.add_child(_meeting_state_pill(st))
		if not is_block and not past:
			var row := UI.hbox(6)
			_meeting_buttons(row, m)
			if row.get_child_count() > 0:
				v.add_child(row)
			else:
				row.free()
			if excuse_for == str(m.id):
				var cl := ChoiceList.new()
				cl.light = true
				v.add_child(cl)
				cl.show_excuses("meeting", str(m.who) if Game.npcs.has(str(m.who)) else Game.npcs.boss_id())
				cl.chosen.connect(func(_i: int, ex: String):
					excuse_for = ""
					if ex != "":
						Game.comms.decline_excuse(str(m.id), ex)
					_dirty = true
				)
		lv.add_child(p)
	# Block planner
	var rc := _card(16)
	rc.custom_minimum_size = Vector2(380, 0)
	split.add_child(rc)
	var rv := UI.vbox(8)
	rc.add_child(rv)
	rv.add_child(_h("Block your calendar", 18))
	rv.add_child(_dimtext("A fake meeting shows you as 'In a meeting' (no suspicion for being away), is evidence for a 'conflicting meeting' excuse, and lets you auto-decline anything it overlaps. Max 2 per day. %s sometimes asks what it was." % Game.npcs.boss_name()))
	var badge := Game.work.badge("fake_block")
	rv.add_child(UI.pill(str(badge.text), badge.color.darkened(0.3), 10))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	rv.add_child(grid)
	var slot := 540
	while slot < Cfg.WORK_END:
		var s0 := slot
		var b := UI.button(Cfg.fmt_time(float(s0)), func():
			Game.comms.add_block(s0, 30)
			_dirty = true
		, "os_ghost", 12)
		var taken := false
		for m in meetings:
			if str(m.kind) == "block" and int(m.start) <= s0 and s0 < int(m.start) + int(m.dur):
				taken = true
		b.disabled = s0 + 30 <= now_t or taken or Game.comms.blocks_today() >= 2 or s0 < now_t
		if taken:
			b.text = "blocked"
		grid.add_child(b)
		slot += 30
	rv.add_child(_dimtext("Blocks used today: %d / 2" % Game.comms.blocks_today(), 12))
	rv.add_child(UI.spacer())
	rv.add_child(_h("This week"))
	var wk := UI.hbox(5)
	rv.add_child(wk)
	for d in 5:
		var cur: bool = d == int(Game.time.day)
		var wp := UI.panel(Color("3b5bdb") if cur else (Color("eef1f8") if d > int(Game.time.day) else Color("dfe3ec")), 8, 8)
		wp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var wl := UI.label(Cfg.DAYS_SHORT[d], 12, Color.WHITE if cur else UI.OS_DIM, true)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wp.add_child(wl)
		wk.add_child(wp)
	rv.add_child(_dimtext("Friday 15:30: Weekly Performance Review. It cannot be avoided.", 12))


func _meeting_state_pill(st: String) -> Control:
	match st:
		"ringing":
			return UI.pill("STARTING NOW", Color("d6455b"), 9, true)
		"live":
			return UI.pill("LIVE", Color("2f9e5b"), 9, true)
		"looped":
			return UI.pill("LOOP ATTENDING", Color("1f8f4a"), 9)
		"done":
			return UI.pill("OVER", Color("6b7594"), 9)
		"excused":
			return UI.pill("EXCUSED", Color("1f8f4a"), 9)
		"declined":
			return UI.pill("DECLINED", Color("1f8f4a"), 9)
		"missed":
			return UI.pill("MISSED", Color("d6455b"), 9)
	return UI.pill("UPCOMING", Color("3b5bdb"), 9)


# ---------------------------------------------------------------------------
# SynerMail
# ---------------------------------------------------------------------------

func _build_mail() -> void:
	var split := UI.hbox(14)
	_content.add_child(split)
	var lc := _card(8)
	lc.custom_minimum_size = Vector2(350, 0)
	split.add_child(lc)
	var lv := UI.vbox(4)
	lc.add_child(UI.scroll(lv))
	var mails: Array = Game.comms.mails.duplicate()
	mails.reverse()
	if mails.is_empty():
		lv.add_child(UI.margin(_dimtext("Inbox zero. Savour it."), 8, 8, 8, 8))
	var sel: Dictionary = {}
	for m in mails:
		if str(m.id) == mail_id:
			sel = m
	if sel.is_empty() and not mails.is_empty():
		sel = mails[0]
		mail_id = str(sel.id)
	for m in mails:
		var on: bool = str(m.id) == mail_id
		var pending := Game.comms.prompt_for_mail(str(m.id))
		var b := UI.Clicky.new()
		b.setup(Color("e7ecfb") if on else UI.OS_PANEL, UI.OS_LINE, 1, true, 8)
		var col := UI.vbox(2)
		var top := UI.hbox(6)
		var from: String = "You" if bool(m.sent) else Game.npcs.display_name(str(m.from))
		top.add_child(UI.label(from, 13, UI.OS_TEXT, not bool(m.read)))
		top.add_child(UI.spacer())
		if not pending.is_empty():
			top.add_child(UI.pill("ACTION", Color("d6455b"), 9, true))
		elif bool(m.sent):
			top.add_child(UI.pill("SENT", Color("6b7594"), 9))
		top.add_child(UI.label("%s %s" % [Cfg.DAYS_SHORT[clampi(int(m.day), 0, 4)], Cfg.fmt_time(float(m.t))], 11, UI.OS_DIM))
		col.add_child(top)
		var sl := UI.label(str(m.subject), 12, UI.OS_TEXT if not bool(m.read) else UI.OS_DIM, not bool(m.read))
		sl.clip_text = true
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(sl)
		b.add_child(col)
		b.pressed.connect(func():
			mail_id = str(m.id)
			Game.presence.touch()
			_dirty = true
		)
		lv.add_child(b)
	var rc := _card(20)
	rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(rc)
	if sel.is_empty():
		rc.add_child(_dimtext("Nothing selected."))
		return
	if not bool(sel.read):
		sel.read = true
		_dirty = true
	var rv := UI.vbox(10)
	rc.add_child(UI.scroll(rv))
	rv.add_child(UI.wrap(str(sel.subject), 21, UI.OS_TEXT))
	var fh := UI.hbox(8)
	if not bool(sel.sent):
		fh.add_child(UI.avatar(str(sel.from), 30))
	fh.add_child(UI.label("From: %s" % ("You" if bool(sel.sent) else Game.npcs.display_name(str(sel.from))), 13, UI.OS_DIM, true))
	rv.add_child(fh)
	var sep := ColorRect.new()
	sep.color = UI.OS_LINE
	sep.custom_minimum_size = Vector2(0, 1)
	rv.add_child(sep)
	rv.add_child(UI.wrap(str(sel.body), 15, UI.OS_TEXT))
	var pending := Game.comms.prompt_for_mail(str(sel.id))
	if not pending.is_empty():
		rv.add_child(UI.gap(1, 6))
		rv.add_child(_timer_row(int(pending.due), int(pending.window)))
		var cl := ChoiceList.new()
		cl.light = true
		cl.hotkeys = true
		rv.add_child(cl)
		cl.show_choices(Game.comms.choices_of(pending), "chat", str(pending.from))
		cl.chosen.connect(func(i: int, ex: String):
			Game.comms.answer(str(pending.id), i, ex, "desk")
		)


# ---------------------------------------------------------------------------
# ShadowIT
# ---------------------------------------------------------------------------

func _build_shadow() -> void:
	Game.tutor.opened_ledger()
	var auto := Game.automation
	var split := UI.hbox(14)
	_content.add_child(split)
	# --- Gadgets ---
	var lc := _card(16)
	lc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(lc)
	var lv := UI.vbox(9)
	lc.add_child(UI.scroll(lv))
	var head := UI.hbox(10)
	head.add_child(_h("Your gadgets", 18))
	head.add_child(UI.spacer())
	var heat := auto.heat()
	var hp := UI.pill("HEAT %d%%" % int(heat), Color("d6455b") if heat >= 40.0 else (Color("e07b00") if heat >= 20.0 else Color("2f9e5b")), 11, heat >= 40.0)
	hp.mouse_filter = Control.MOUSE_FILTER_STOP
	hp.tooltip_text = "The chance a SynerWatch scan spots non-human input right now (halved while you sit here). Switch gadgets off before a scan and back on after."
	head.add_child(hp)
	var svc := UI.button("Service all", func():
		auto.maintain()
		_dirty = true
	, "os_ghost", 12)
	svc.tooltip_text = "UPKEEP. Costs 8 energy. Repairs breakage and resets wear. Worn gadgets fail far more often."
	head.add_child(svc)
	lv.add_child(head)
	var owned := 0
	for id in Db.gadget_order():
		if not auto.owns(id):
			continue
		owned += 1
		var def := auto.def(id)
		var st := auto.g(id)
		var p := UI.panel(UI.OS_SOFT, 8, 12, 1, UI.OS_LINE)
		var v := UI.vbox(5)
		p.add_child(v)
		var h := UI.hbox(8)
		v.add_child(h)
		h.add_child(UI.label(str(def.display_name), 15, UI.OS_TEXT, true))
		h.add_child(UI.pill("LEVEL %d/%d" % [auto.level(id), auto.max_level(id)], Color("3b5bdb"), 9))
		if bool(st.broken):
			h.add_child(UI.pill("BROKEN", Color("d6455b"), 9, true))
		elif auto.working(id):
			h.add_child(UI.pill("RUNNING", Color("2f9e5b"), 9, true))
		elif bool(st.on):
			h.add_child(UI.pill("NO INTERNET", Color("e07b00"), 9, true))
		else:
			h.add_child(UI.pill("OFF", Color("6b7594"), 9))
		h.add_child(UI.spacer())
		var tb := UI.button("Switch off" if bool(st.on) else "Switch on", func():
			auto.toggle(id)
			_dirty = true
		, "os_ghost" if bool(st.on) else "os", 12)
		tb.disabled = bool(st.broken)
		h.add_child(tb)
		v.add_child(_dimtext(str(auto.data(id).text), 12))
		var wh := UI.hbox(8)
		wh.add_child(UI.label("Wear", 11, UI.OS_DIM, true))
		var wb := UI.bar(Color("e07b00") if float(st.wear) > 28.0 else Color("2f9e5b"), 7)
		wb.value = float(st.wear)
		wb.custom_minimum_size = Vector2(110, 7)
		wh.add_child(wb)
		wh.add_child(UI.label("reliability %d%%  -  fails %d%%  -  heat +%d" % [int(round(auto.reliability(id))), int(round(auto.fail_chance(id))), int(auto.data(id).get("heat", 0))], 11, UI.OS_DIM))
		v.add_child(wh)
		if "auto_report" in auto.abilities(id):
			var rh := UI.hbox(6)
			rh.add_child(UI.label("Send the report at", 12, UI.OS_DIM, true))
			for tm in AutomationManager.REPORT_TIMES:
				var cur: bool = int(auto.autos.report_at) == int(tm)
				rh.add_child(UI.button("off" if int(tm) < 0 else Cfg.fmt_time(float(tm)), func():
					auto.set_report_time(int(tm))
					_dirty = true
				, "os" if cur else "os_ghost", 11))
			v.add_child(rh)
		if "do_tickets" in auto.abilities(id):
			var at: Dictionary = Game.work.task(str(auto.autos.ai_task))
			v.add_child(_dimtext("Working on: %s" % (str(at.key) if not at.is_empty() else "nothing. Assign it a ticket in SynerTasks."), 12))
		lv.add_child(p)
	if owned == 0:
		lv.add_child(_dimtext("Nothing installed. Leave your desk, sit at your Gaming PC and visit ShadyDeals.biz. MouseMover.exe goes on sale Tuesday.", 14))
	# Combinations
	lv.add_child(UI.gap(1, 4))
	lv.add_child(_h("Combinations", 16))
	var active: Array = []
	for c in auto.combos_active():
		active.append(str(c.id))
	for cid in Db.combos:
		var c: Dictionary = Db.combos[cid]
		var on: bool = cid in active
		var names: Array = []
		var have := true
		for need in c.needs:
			names.append(str(auto.def(str(need)).display_name))
			if not auto.owns(str(need)):
				have = false
		var cp := UI.panel(Color("e1f7e8") if on else UI.OS_SOFT, 8, 10, 1, Color("2f9e5b") if on else UI.OS_LINE)
		var cv := UI.vbox(2)
		cp.add_child(cv)
		var ch := UI.hbox(6)
		ch.add_child(UI.label(str(c.display_name), 13, UI.OS_TEXT, true))
		ch.add_child(UI.pill("ACTIVE" if on else ("BOTH OFF OR BROKEN" if have else "NOT OWNED"), Color("1f8f4a") if on else Color("6b7594"), 9, on))
		ch.add_child(UI.label(" + ".join(names), 11, UI.OS_DIM))
		cv.add_child(ch)
		cv.add_child(_dimtext(str(c.text), 11))
		lv.add_child(cp)
	# --- Alibi ledger ---
	var rc := _card(16)
	rc.custom_minimum_size = Vector2(460, 0)
	split.add_child(rc)
	var nv := UI.vbox(6)
	rc.add_child(nv)
	var lh := UI.hbox(8)
	lh.add_child(_h("Alibi Ledger", 18))
	lh.add_child(UI.spacer())
	lh.add_child(UI.label("%d held up  -  %d caught" % [Game.deception.successful(), Game.deception.caught()], 12, UI.OS_DIM, true))
	nv.add_child(lh)
	nv.add_child(_dimtext("Every story you have told. While one is ACTIVE, anything listed under it will expose you. Each reuse makes a story weaker; the fourth backfires by itself.", 12))
	var body := UI.vbox(7)
	nv.add_child(UI.scroll(body))
	var list: Array = Game.deception.claims.duplicate()
	list.reverse()
	if list.is_empty():
		body.add_child(_dimtext("No lies on record. Yet."))
	for c in list:
		var d := Game.deception.describe(c)
		var live := bool(d.live)
		var bad: bool = str(d.status) in [Claim.CONTRADICTED, Claim.EXPOSED]
		var edge := Color("2f9e5b") if live else (Color("d6455b") if bad else UI.OS_LINE)
		var cp := PanelContainer.new()
		var sbx := UI.sb(Color("eefaf1") if live else (Color("fff0f2") if bad else UI.OS_SOFT), 8, 0, edge, 10, 8)
		sbx.border_width_left = 5
		cp.add_theme_stylebox_override("panel", sbx)
		var cv := UI.vbox(3)
		cp.add_child(cv)
		var ch := UI.hbox(6)
		ch.add_child(UI.label(str(d.title), 13, UI.OS_TEXT, true))
		ch.add_child(UI.pill(str(d.status_text), Color("1f8f4a") if live else (Color("d6455b") if bad else Color("6b7594")), 9, live or bad))
		ch.add_child(UI.spacer())
		ch.add_child(UI.label(("%s left" % Cfg.fmt_dur(float(d.left))) if live else str(d.when), 11, UI.OS_DIM, true))
		cv.add_child(ch)
		var meta := "Told to %s at %s" % [str(d.told_to), str(d.when)]
		if str(d.subject) != "":
			meta += "  -  you said: %s" % str(d.subject)
		cv.add_child(_dimtext(meta, 11))
		if live and not d.avoid.is_empty():
			cv.add_child(UI.wrap("Do NOT: %s." % "; ".join(d.avoid), 12, Color("b3243a")))
		if not d.evidence.is_empty():
			cv.add_child(UI.wrap("Backed by: %s." % ", ".join(d.evidence), 11, Color("1f8f4a")))
		if live:
			cv.add_child(_dimtext("Chance someone checks: %d%%" % int(d.risk), 11))
		if bad and str(d.contradiction) != "":
			cv.add_child(UI.wrap("Contradicted by: %s." % str(d.contradiction), 11, Color("b3243a")))
		body.add_child(cp)
