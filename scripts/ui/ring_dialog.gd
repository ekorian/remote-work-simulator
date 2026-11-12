class_name RingDialog
extends Dim

signal join(meeting_id: String, via_phone: bool)
signal dismissed()

var mid := ""
var _body: VBoxContainer
var _bar: StatBar
var _left: Label
var _picking := false

func _ready() -> void:
	setup(0.45)
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
	var m := Game.comms.meeting(mid)
	if m.is_empty() or str(m.state) != "ringing":
		close()
		return
	var left := float(int(m.ring_until) + 1) - Game.time.clock()
	_bar.value = clampf(left, 0.0, _bar.max_value)
	_left.text = "%d min before you're marked absent" % int(maxf(0.0, ceil(left)))

func _build() -> void:
	UI.clear(_body)
	var m := Game.comms.meeting(mid)
	if m.is_empty():
		return
	var at_desk: bool = bool(Game.presence.at_desk) and Game.home.internet_up()
	var phone := Game.home.phone_usable()
	var reach := at_desk or phone
	var head := UI.hbox(12)
	head.add_child(UI.icon("call", 40, UI.RED))
	var hv := UI.vbox(0)
	hv.add_child(UI.title(str(m.title), 26))
	var who: String = Game.npcs.display_name(str(m.who))
	hv.add_child(UI.label("%s  -  %d min  -  %s" % [who, int(m.dur), "MANDATORY" if bool(m.mandatory) else "optional-ish"], 13, UI.DIM))
	head.add_child(hv)
	_body.add_child(head)
	_bar = StatBar.new()
	_bar.color = UI.RED
	_bar.max_value = maxf(1.0, float(int(m.ring_until) - int(m.start) + 1))
	_bar.custom_minimum_size = Vector2(0, 8)
	_body.add_child(_bar)
	_left = UI.label("", 12, UI.DIM, true)
	_body.add_child(_left)
	if _picking:
		var cl := ChoiceList.new()
		_body.add_child(cl)
		cl.show_excuses("meeting", str(m.who) if Game.npcs.has(str(m.who)) else Game.npcs.boss_id())
		cl.chosen.connect(func(_i: int, ex: String):
			_picking = false
			if ex != "":
				Game.comms.decline_excuse(mid, ex)
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
	var forbidden := Game.deception.forbidden_now()
	if ("video_meeting" if at_desk else "phone_meeting") in forbidden:
		_body.add_child(UI.wrap("Joining %s contradicts a story you told. They WILL ask about it." % ("on camera" if at_desk else "from your phone"), 12, UI.RED))
	if at_desk and phone and "video_meeting" in forbidden and not "phone_meeting" in forbidden:
		var pv := {"text": "Join from your phone instead (camera off)", "badge": {"text": "", "color": UI.DIM, "warn": false}, "odds": -1.0, "ok": true, "why": "", "cost": 0.0}
		_body.add_child(UI.choice(pv, func(): join.emit(mid, true)))
	if Game.comms.can_dodge(m):
		var conflict := Game.comms.conflicts(m)
		_body.add_child(_opt("Decline: calendar conflict", "decline_conflict", "The system approves it automatically." if conflict else "", conflict, "You have no calendar block over this meeting (SynerCalendar).", func(): Game.comms.decline_conflict(mid)))
		if Game.automation.has("attend_meetings"):
			var why := Game.comms.can_send_clone(m)
			_body.add_child(_opt("Send your AI Doppelganger instead", "send_clone", "It attends as you. It has opinions.", why == "", why, func(): Game.comms.send_clone(mid)))
		if not bool(m.excuse_tried):
			_body.add_child(_opt("Make an excuse...", "excuse", "", true, "", func():
				_picking = true
				_build()
			))
	else:
		_body.add_child(UI.pill("THIS ONE CANNOT BE AVOIDED", UI.RED, 11, true))
	if bool(m.surprise):
		_body.add_child(_opt("Reject the call", "ignore", "Costs some Suspicion, less than letting it ring out.", true, "", func(): Game.comms.reject_call(mid)))
	_body.add_child(UI.button("Not now (keep ringing)", close, "ghost", 13))

func _opt(text: String, act: String, hint: String, ok: bool, why: String, cb: Callable) -> Control:
	var check := Game.work.can(act)
	if ok and not check.ok:
		ok = false
		why = str(check.why)
	var view := {"text": text, "badge": Game.work.badge(act), "odds": -1.0, "ok": ok, "why": why, "cost": Game.work.energy_cost(act)}
	var c := UI.choice(view, cb)
	if hint != "" and ok:
		var col: VBoxContainer = c.get_child(0).get_child(0)
		col.add_child(UI.wrap(hint, 11, UI.DIM))
	return c


# ---------------------------------------------------------------------------
# The call itself
# ---------------------------------------------------------------------------
