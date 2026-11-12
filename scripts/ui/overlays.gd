class_name Overlays
extends RefCounted
## Namespace for the in-game overlays: the call screen, the phone, the shop
## and the incoming-call dialog.


class Dim:
	extends Control
	## Full-screen dimmer that swallows clicks behind a modal.
	var bg: ColorRect

	func _init(alpha: float = 0.6) -> void:
		UI.full(self)
		mouse_filter = Control.MOUSE_FILTER_STOP
		bg = ColorRect.new()
		bg.color = Color(0.06, 0.05, 0.11, alpha)
		UI.full(bg)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

	func center(child: Control) -> CenterContainer:
		var cc := CenterContainer.new()
		UI.full(cc)
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(child)
		add_child(cc)
		return cc


# ---------------------------------------------------------------------------
# Incoming call / meeting starting
# ---------------------------------------------------------------------------

class RingDialog:
	extends Dim
	signal join(meeting_id: String, via_phone: bool)
	signal dismissed()

	var mid := ""
	var _body: VBoxContainer
	var _bar: Hud.StatBar
	var _left: Label
	var _picking := false

	func _init() -> void:
		super(0.45)
		visible = false
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.shadowed(UI.sb(UI.PANEL, 20, 2, UI.RED, 22, 20), 30, 0.5))
		p.custom_minimum_size = Vector2(560, 0)
		center(p)
		_body = UI.vbox(10)
		p.add_child(_body)

	func open(meeting_id: String) -> void:
		mid = meeting_id
		_picking = false
		visible = true
		_build()

	func close() -> void:
		if visible:
			visible = false
			dismissed.emit()

	func _process(_delta: float) -> void:
		if not visible:
			return
		var m := Corp.meeting(mid)
		if m.is_empty() or str(m.state) != "ringing":
			close()
			return
		var left := float(int(m.ring_until) + 1) - Game.clock()
		_bar.value = clampf(left, 0.0, _bar.max_value)
		_left.text = "%d min before you're marked absent" % int(maxf(0.0, ceil(left)))

	func _build() -> void:
		UI.clear(_body)
		var m := Corp.meeting(mid)
		if m.is_empty():
			return
		var at_desk: bool = bool(Game.s.pres.at_desk) and Interact.internet_up()
		var phone := Interact.phone_usable()
		var reach := at_desk or phone
		var head := UI.hbox(12)
		head.add_child(UI.icon("call", 40, UI.RED))
		var hv := UI.vbox(0)
		hv.add_child(UI.title(str(m.title), 26))
		var who := Content.person_name(str(m.who))
		hv.add_child(UI.label("%s  -  %d min  -  %s" % [who, int(m.dur), "MANDATORY" if bool(m.mandatory) else "optional-ish"], 13, UI.DIM))
		head.add_child(hv)
		_body.add_child(head)
		_bar = Hud.StatBar.new()
		_bar.color = UI.RED
		_bar.max_value = maxf(1.0, float(int(m.ring_until) - int(m.start) + 1))
		_bar.custom_minimum_size = Vector2(0, 8)
		_body.add_child(_bar)
		_left = UI.label("", 12, UI.DIM, true)
		_body.add_child(_left)
		if _picking:
			var cl := ChoiceList.new()
			_body.add_child(cl)
			cl.show_choices([{"t": "Make an excuse...", "a": "excuse", "excuse": true}], "chat")
			cl._picking = 0
			cl.refresh()
			cl.chosen.connect(func(_i: int, ex: String):
				_picking = false
				if ex != "":
					Corp.decline_excuse(mid, ex)
				if visible:
					_build()
			)
			return
		if not reach:
			_body.add_child(UI.wrap("You're nowhere near a screen. Get to the Work Computer, or carry your phone next time.", 15, UI.ACCENT))
			_body.add_child(UI.button("Run for it", close, "primary", 17))
			return
		_body.add_child(UI.wrap("Meetings drain Health with every question, and every answer is a chance to slip up. Missing one raises Suspicion.", 13, UI.DIM))
		var view := {"text": "Join the call%s" % ("" if at_desk else " from your phone (camera off)"), "badge": {"text": "", "color": UI.DIM, "warn": false}, "odds": -1.0, "ok": true, "why": "", "cost": 0.0}
		var jb := UI.choice(view, func(): join.emit(mid, not at_desk))
		_body.add_child(jb)
		if Corp.can_dodge(m):
			var conflict := Corp.conflicts(m)
			_body.add_child(_opt("Decline: calendar conflict", "decline_conflict", "The system approves it automatically." if conflict else "", conflict, "You have no calendar block over this meeting (SynerCalendar).", func(): Corp.decline_conflict(mid)))
			if Auto.owns("loopcam"):
				var ready := Auto.working("loopcam") and Interact.loop_ready()
				_body.add_child(_opt("Send your LoopCam instead", "send_loop", "It nods. Convincingly. Usually.", ready, "LoopCam is off or broken, or today's loop isn't recorded.", func(): Corp.send_loop(mid)))
			if not bool(m.excuse_tried):
				_body.add_child(_opt("Make an excuse...", "excuse", "", true, "", func():
					_picking = true
					_build()
				))
		else:
			_body.add_child(UI.pill("THIS ONE CANNOT BE AVOIDED", UI.RED, 11, true))
		if bool(m.surprise):
			_body.add_child(_opt("Reject the call", "ignore", "Costs some Suspicion, less than letting it ring out.", true, "", func(): Corp.reject_call(mid)))
		_body.add_child(UI.button("Not now (keep ringing)", close, "ghost", 13))

	func _opt(text: String, act: String, hint: String, ok: bool, why: String, cb: Callable) -> Control:
		var check := Actions.can(act)
		if ok and not check.ok:
			ok = false
			why = str(check.why)
		var view := {"text": text, "badge": Actions.badge(act), "odds": -1.0, "ok": ok, "why": why, "cost": Actions.energy_cost(act)}
		var c := UI.choice(view, cb)
		if hint != "" and ok:
			var col: VBoxContainer = c.get_child(0).get_child(0)
			col.add_child(UI.wrap(hint, 11, UI.DIM))
		return c


# ---------------------------------------------------------------------------
# The call itself
# ---------------------------------------------------------------------------

class CallView:
	extends Dim
	signal ended()

	const THINK := 22.0

	var _title: Label
	var _dots: HBoxContainer
	var _tiles: HBoxContainer
	var _speaker: Label
	var _line: Label
	var _choices: ChoiceList
	var _timer: Hud.StatBar
	var _timer_label: Label
	var _reply: PanelContainer
	var _reply_label: Label
	var _left := 0.0
	var _limit := 20.0
	var _waiting := false
	var _showing_reply := false
	var _health: Label
	var _hang: Button

	func _init() -> void:
		super(0.86)
		visible = false
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.shadowed(UI.sb(Color("1f1b33"), 22, 2, UI.LINE, 24, 20), 30, 0.5))
		p.custom_minimum_size = Vector2(980, 0)
		center(p)
		var v := UI.vbox(12)
		p.add_child(v)
		var head := UI.hbox(10)
		v.add_child(head)
		head.add_child(UI.pill("LIVE", UI.RED, 12, true))
		_title = UI.title("Meeting", 24)
		_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(_title)
		_health = UI.label("", 13, UI.RED, true)
		head.add_child(_health)
		_dots = UI.hbox(5)
		head.add_child(_dots)
		_tiles = UI.hbox(10)
		_tiles.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(_tiles)
		var bubble := UI.panel(UI.PANEL2, 16, 16)
		v.add_child(bubble)
		var bv := UI.vbox(4)
		bubble.add_child(bv)
		_speaker = UI.label("", 13, UI.ACCENT, true)
		bv.add_child(_speaker)
		_line = UI.wrap("", 21)
		_line.add_theme_font_override("font", UI.font_title)
		_line.custom_minimum_size = Vector2(880, 0)
		bv.add_child(_line)
		_reply = UI.panel(Color(0, 0, 0, 0.3), 12, 12)
		_reply_label = UI.wrap("", 16)
		_reply.add_child(_reply_label)
		_reply.visible = false
		v.add_child(_reply)
		var th := UI.hbox(8)
		v.add_child(th)
		_timer = Hud.StatBar.new()
		_timer.color = UI.ACCENT
		_timer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_timer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_timer.custom_minimum_size = Vector2(0, 8)
		th.add_child(_timer)
		_timer_label = UI.label("", 12, UI.DIM, true)
		th.add_child(_timer_label)
		_choices = ChoiceList.new()
		_choices.hotkeys = true
		_choices.chosen.connect(_on_chosen)
		v.add_child(_choices)
		var foot := UI.hbox(8)
		v.add_child(foot)
		foot.add_child(UI.spacer())
		_hang = UI.button("Hang up (suspicious)", func():
			Corp.call_hang_up()
			_finish()
		, "danger", 13)
		foot.add_child(_hang)

	func start() -> void:
		if not Corp.in_call():
			return
		visible = true
		_reply.visible = false
		_showing_reply = false
		var m := Corp.meeting(str(Game.s.call.mid))
		_title.text = str(m.get("title", "Call"))
		_limit = THINK * float(Game.diff().window)
		Bus.sfx.emit("join")
		_show_beat()

	func _show_beat() -> void:
		var b := Corp.call_beat()
		if b.is_empty():
			_finish()
			return
		_showing_reply = false
		_reply.visible = false
		var c: Dictionary = Game.s.call
		UI.clear(_dots)
		for i in c.beats.size():
			var d := Panel.new()
			d.custom_minimum_size = Vector2(12, 12)
			d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			d.add_theme_stylebox_override("panel", UI.sb(UI.ACCENT if i == int(c.i) else (UI.GREEN if i < int(c.i) else UI.LINE), 6))
			_dots.add_child(d)
		var who: String = str(b.who)
		UI.clear(_tiles)
		var cast: Array = ["todd", "priya", "kevin", "dave", "linda"]
		if not who in cast:
			cast.append(who)
		for id in cast:
			var on: bool = id == who
			var tile := UI.panel(Color("2b2542") if not on else Color("3a3260"), 14, 10, 3 if on else 1, UI.ACCENT if on else UI.LINE)
			tile.custom_minimum_size = Vector2(150, 0)
			var tv := UI.vbox(5)
			tv.alignment = BoxContainer.ALIGNMENT_CENTER
			var av := UI.avatar(str(id), 54 if on else 44)
			av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			tv.add_child(av)
			var nl := UI.label(Content.person_name(str(id)).get_slice(" ", 0), 12, UI.TEXT if on else UI.DIM, true)
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tv.add_child(nl)
			tile.add_child(tv)
			_tiles.add_child(tile)
		var you := UI.panel(Color("1f3a2b"), 14, 10, 1, UI.GREEN)
		you.custom_minimum_size = Vector2(150, 0)
		var yv := UI.vbox(5)
		yv.alignment = BoxContainer.ALIGNMENT_CENTER
		var ya := UI.avatar("me", 44)
		ya.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		yv.add_child(ya)
		var yl := UI.label("You%s" % (" (phone)" if bool(c.phone) else ""), 12, UI.GREEN, true)
		yl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		yv.add_child(yl)
		you.add_child(yv)
		_tiles.add_child(you)
		_speaker.text = Content.person_name(who).to_upper()
		_line.text = Corp.fmt(str(b.text))
		_choices.visible = true
		_choices.show_choices(Corp.call_choices(), Corp.call_context())
		_left = _limit
		_waiting = true
		_timer.max_value = _limit
		_hang.visible = true
		Bus.sfx.emit("talk")

	func _process(delta: float) -> void:
		if not visible:
			return
		_health.text = "Health %d" % int(round(Game.get_stat("health"))) if Game.active else ""
		if not _waiting:
			return
		_left -= delta
		_timer.value = maxf(0.0, _left)
		_timer.color = UI.RED if _left < 6.0 else UI.ACCENT
		_timer_label.text = "%ds to answer" % int(ceil(maxf(0.0, _left)))
		if _left <= 0.0:
			_waiting = false
			var res := Corp.call_timeout()
			_after(res, "...")

	func _on_chosen(i: int, excuse_id: String) -> void:
		if not _waiting:
			return
		var list := Corp.call_choices()
		if i < 0 or i >= list.size():
			return
		var said: String = Corp.fmt(str(list[i].t))
		if excuse_id != "":
			said = str(Deception.EXCUSES[excuse_id].label)
		var res := Corp.call_choose(i, excuse_id)
		if not bool(res.get("done", false)):
			if not Game.active or Game.s.phase == "over":
				_finish()
			else:
				_choices.refresh()
			return
		_waiting = false
		_after(res, said)

	func _after(res: Dictionary, said: String) -> void:
		_choices.visible = false
		_hang.visible = false
		_timer_label.text = ""
		_showing_reply = true
		var ok := bool(res.get("ok", false))
		var say: String = Corp.fmt(str(res.get("say", "")))
		_reply.visible = true
		_reply.add_theme_stylebox_override("panel", UI.sb(Color(UI.GREEN, 0.16) if ok else Color(UI.RED, 0.18), 12, 1, UI.GREEN if ok else UI.RED, 12, 12))
		_reply_label.text = "You: %s%s" % [said, ("\n\n" + say) if say != "" else ""]
		Bus.sfx.emit("good" if ok else "bad")
		var wait := clampf(1.3 + float(say.length()) * 0.035, 1.6, 4.2)
		await get_tree().create_timer(wait, true, false, true).timeout
		if not visible:
			return
		if not Game.active or Game.s.phase == "over" or bool(res.get("end", false)) or not Corp.in_call():
			_finish()
		else:
			_show_beat()

	func _finish() -> void:
		_waiting = false
		if visible:
			visible = false
			Bus.sfx.emit("leave")
			ended.emit()


# ---------------------------------------------------------------------------
# Phone
# ---------------------------------------------------------------------------

class Phone:
	extends Control
	signal closed()
	signal join(meeting_id: String)

	const COST := 6.0

	var _body: VBoxContainer
	var _head: Label
	var _open_pid := ""
	var _dirty := true

	func _init() -> void:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.full(self)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.shadowed(UI.sb(Color("15131f"), 34, 3, Color("4d4478"), 14, 16), 30, 0.5))
		p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		p.anchor_top = 1.0
		p.anchor_bottom = 1.0
		p.offset_left = 20
		p.offset_right = 20 + 400
		p.offset_top = -640
		p.offset_bottom = -20
		add_child(p)
		var v := UI.vbox(8)
		p.add_child(v)
		var top := UI.hbox(8)
		v.add_child(top)
		_head = UI.label("", 13, UI.DIM, true)
		_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(_head)
		top.add_child(UI.button("x", close, "ghost", 13))
		v.add_child(UI.title("SynerTeams Mobile", 19))
		_body = UI.vbox(7)
		v.add_child(UI.scroll(_body))
		Bus.comms_changed.connect(func(): _dirty = true)
		Bus.meeting_changed.connect(func(_m): _dirty = true)

	func open(pid: String = "") -> void:
		_open_pid = pid
		visible = true
		_dirty = true
		Bus.sfx.emit("pop")

	func close() -> void:
		if visible:
			visible = false
			closed.emit()

	func _process(_delta: float) -> void:
		if not visible or not Game.active:
			return
		_head.text = "%s   battery %d%%" % [Cfg.fmt_time(fposmod(Game.clock(), 1440.0)), int(Game.s.things.phone_bat)]
		if _dirty:
			_dirty = false
			_build()

	func _build() -> void:
		UI.clear(_body)
		if not Interact.phone_usable():
			_body.add_child(UI.wrap("The phone is dead or on the charger. Dock it in the bedroom to charge.", 14, UI.ACCENT))
			return
		if Game.s.phase != "work":
			_body.add_child(UI.wrap("After hours. Do Not Disturb is on. Bliss.", 14, UI.DIM))
			return
		var ring := Corp.ringing()
		if not ring.is_empty() and not Corp.in_call():
			var rc := UI.Clicky.new()
			rc.setup(Color("7a2b3d"), UI.RED, 2, false, 12)
			var rv := UI.vbox(2)
			rv.add_child(UI.title("%s is starting" % str(ring.title), 15))
			rv.add_child(UI.label("Tap to join from the phone (camera off)", 12, Color("ffd3da")))
			rc.add_child(rv)
			rc.pressed.connect(func(): join.emit(str(ring.id)))
			_body.add_child(rc)
		var p := Corp.prompt(_open_pid)
		if not p.is_empty():
			_body.add_child(UI.button("< All messages", func():
				_open_pid = ""
				_dirty = true
			, "ghost", 12))
			var card := UI.panel(UI.PANEL2, 12, 12)
			var cv := UI.vbox(5)
			card.add_child(cv)
			var hh := UI.hbox(8)
			hh.add_child(UI.avatar(str(p.from), 28))
			hh.add_child(UI.label(Content.person_name(str(p.from)), 14, UI.TEXT, true))
			cv.add_child(hh)
			cv.add_child(UI.wrap(str(p.text), 14))
			cv.add_child(UI.label("%d min left  -  each reply costs %d%% battery" % [maxi(0, int(p.due) - Game.now()), int(COST)], 11, UI.DIM))
			_body.add_child(card)
			var cl := ChoiceList.new()
			_body.add_child(cl)
			cl.show_choices(Corp.choices_of(p), "chat")
			cl.chosen.connect(func(i: int, ex: String):
				Interact.phone_spend(COST)
				Corp.answer(str(p.id), i, ex)
				_open_pid = ""
				_dirty = true
			)
			return
		var list := Corp.prompts()
		if list.is_empty():
			_body.add_child(UI.wrap("No one needs you. This is the dream.", 14, UI.DIM))
		for pd in list:
			var c := UI.Clicky.new()
			c.setup(UI.PANEL2, Color(Content.person_color(str(pd.from)), 0.8), 1, false, 12)
			var h := UI.hbox(8)
			h.add_child(UI.avatar(str(pd.from), 28))
			var col := UI.vbox(1)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(UI.label("%s  -  %d min" % [Content.person_name(str(pd.from)), maxi(0, int(pd.due) - Game.now())], 12, UI.TEXT, true))
			var tl := UI.label(str(pd.text), 12, UI.DIM)
			tl.clip_text = true
			tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			col.add_child(tl)
			h.add_child(col)
			c.add_child(h)
			c.pressed.connect(func():
				_open_pid = str(pd.id)
				_dirty = true
			)
			_body.add_child(c)
		_body.add_child(UI.wrap("Tickets, calendar and gadgets need the work computer.", 11, UI.DIM))


# ---------------------------------------------------------------------------
# Shop
# ---------------------------------------------------------------------------

class Shop:
	extends Dim
	signal closed()

	var _grid: GridContainer
	var _money: Label
	var _dirty := true

	func _init() -> void:
		super(1.0)
		bg.color = UI.BG
		visible = false
		# Same footprint as the work desktop: the HUD column keeps the right strip.
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.sb(Color("14121f"), 16, 2, Color("b48cff"), 22, 16))
		UI.full(p)
		p.offset_left = 12
		p.offset_top = 12
		p.offset_bottom = -12
		p.offset_right = -(Hud.COL_W + 28.0)
		add_child(p)
		var v := UI.vbox(10)
		p.add_child(v)
		var head := UI.hbox(12)
		v.add_child(head)
		var tv := UI.vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.title("ShadyDeals.biz", 32, Color("b48cff")))
		tv.add_child(UI.label("\"Solutions\" for the modern remote professional. No refunds. No questions.", 13, UI.DIM))
		head.add_child(tv)
		_money = UI.title("$0", 28, UI.ACCENT)
		head.add_child(_money)
		head.add_child(UI.button("Close  (Esc)", close, "ghost", 14))
		_grid = GridContainer.new()
		_grid.columns = 3
		_grid.add_theme_constant_override("h_separation", 10)
		_grid.add_theme_constant_override("v_separation", 10)
		v.add_child(UI.scroll(_grid))
		Bus.gadget_changed.connect(func(_g): _dirty = true)
		Game.money_changed.connect(func(_a, _b, _c): _dirty = true)
		Game.favor_changed.connect(func(_f): _dirty = true)

	func open() -> void:
		visible = true
		_dirty = true

	func close() -> void:
		if visible:
			visible = false
			closed.emit()

	func _process(_delta: float) -> void:
		if visible and _dirty and Game.active:
			_dirty = false
			_build()

	func _tile(title_text: String, blurb: String, tags: Array, price: int, state: String, cb: Callable) -> Control:
		var owned := state == "owned"
		var locked := state.begins_with("ships")
		var p := UI.panel(Color("211d36") if not owned else Color("1f3a2b"), 14, 14, 1, UI.GREEN if owned else UI.LINE)
		p.custom_minimum_size = Vector2(300, 168)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UI.vbox(6)
		p.add_child(v)
		v.add_child(UI.title(title_text, 18, UI.TEXT if not locked else UI.DIM))
		var b := UI.wrap(blurb, 13, UI.DIM)
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(b)
		var th := UI.hbox(5)
		for tg in tags:
			th.add_child(UI.pill(str(tg[0]), tg[1], 10))
		v.add_child(th)
		var foot := UI.hbox(8)
		v.add_child(foot)
		foot.add_child(UI.title("$%d" % price, 20, UI.ACCENT if not owned else UI.DIM))
		foot.add_child(UI.spacer())
		if owned:
			foot.add_child(UI.pill("OWNED", UI.GREEN, 12, true))
		elif locked:
			foot.add_child(UI.pill(state.to_upper(), UI.DIM, 11))
		else:
			var bb := UI.button("Buy", cb, "primary", 15)
			bb.disabled = int(Game.s.money) < price
			foot.add_child(bb)
		return p

	func _build() -> void:
		_money.text = "$%d" % int(Game.s.money)
		UI.clear(_grid)
		for id in Auto.ORDER:
			var def: Dictionary = Auto.GADGETS[id]
			var tags: Array = []
			match str(def.kind):
				"passive":
					tags.append(["ALWAYS ON", UI.GREEN])
				"always":
					tags.append(["RUNS CONTINUOUSLY", UI.BLUE])
				"use":
					tags.append(["FIRES WHEN NEEDED", UI.PURPLE])
			if int(def.heat) > 0:
				tags.append(["HEAT +%d" % int(def.heat), UI.ORANGE])
			if bool(def.net):
				tags.append(["NEEDS INTERNET", UI.TEAL])
			var state := "buy"
			if Auto.owns(id):
				state = "owned"
			elif not Auto.unlocked(id):
				state = "ships %s" % Cfg.DAYS[int(def.day)]
			_grid.add_child(_tile(str(def.name), str(def.blurb), tags, Auto.price(id), state, func():
				Auto.buy(id)
			))
		var price := int(round(float(Auto.BRIBE_PRICE) * float(Game.diff().cost) / 5.0)) * 5
		_grid.add_child(_tile("Gift Card \"For The Team\"", "Send Dave a gift card. Dave will owe you one favour, which you can spend to hand him a ticket. One per day. You have %d favour(s)." % int(Game.s.favor),
			[["SOCIAL", Color("ff9ecb")]], price, "buy" if Auto.can_bribe() else "ships tomorrow", func():
				Auto.bribe()
		))
