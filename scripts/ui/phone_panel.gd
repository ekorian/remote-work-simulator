class_name PhonePanel
extends Control

signal closed()
signal join(meeting_id: String)

const COST := 6.0

var _body: VBoxContainer
var _head: Label
var _open_pid := ""
var _dirty := true

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full(self)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.shadowed(UI.sb(UI.BG.darkened(0.25), 34, 3, UI.LINE, 14, 16), 30, 0.5))
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
	_head.text = "%s   battery %d%%" % [Cfg.fmt_time(fposmod(Game.time.clock(), 1440.0)), int(Game.home.things.phone_bat)]
	if _dirty:
		_dirty = false
		_build()

func _build() -> void:
	UI.clear(_body)
	if not Game.home.phone_usable():
		_body.add_child(UI.wrap("The phone is dead or on the charger. Dock it in the bedroom to charge.", 14, UI.ACCENT))
		return
	if Game.time.phase != "work":
		_body.add_child(UI.wrap("After hours. Do Not Disturb is on. Bliss.", 14, UI.DIM))
		return
	var ring := Game.comms.ringing()
	if not ring.is_empty() and not Game.comms.in_call():
		var rc := UI.Clicky.new()
		rc.setup(Color("7a2b3d"), UI.RED, 2, false, 12)
		var rv := UI.vbox(2)
		var casual := bool(ring.get("casual", false))
		rv.add_child(UI.title(str(ring.title) if str(ring.kind) == "call" else "%s is starting" % str(ring.title), 15))
		rv.add_child(UI.label("Tap to pick up" if casual else "Tap to join from the phone (camera off)", 12, Color("ffd3da")))
		rc.add_child(rv)
		rc.pressed.connect(func(): join.emit(str(ring.id)))
		_body.add_child(rc)
	var p := Game.comms.prompt(_open_pid)
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
		hh.add_child(UI.label(Game.npcs.display_name(str(p.from)), 14, UI.TEXT, true))
		cv.add_child(hh)
		cv.add_child(UI.wrap(str(p.text), 14))
		cv.add_child(UI.label("%d min left  -  each reply costs %d%% battery" % [maxi(0, int(p.due) - Game.time.now()), int(COST)], 11, UI.DIM))
		_body.add_child(card)
		var cl := ChoiceList.new()
		cl.columns = 1
		cl.picker_height = 300.0
		_body.add_child(cl)
		cl.show_choices(Game.comms.choices_of(p), "chat", str(p.from))
		cl.chosen.connect(func(i: int, ex: String):
			Game.home.phone_spend(COST)
			Game.comms.answer(str(p.id), i, ex, "phone")
			_open_pid = ""
			_dirty = true
		)
		return
	var list := Game.comms.pending()
	if list.is_empty():
		_body.add_child(UI.wrap("No one needs you. This is the dream.", 14, UI.DIM))
	for pd in list:
		var c := UI.Clicky.new()
		c.setup(UI.PANEL2, Color(Game.npcs.color(str(pd.from)), 0.8), 1, false, 12)
		var h := UI.hbox(8)
		h.add_child(UI.avatar(str(pd.from), 28))
		var col := UI.vbox(1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UI.label("%s  -  %d min" % [Game.npcs.display_name(str(pd.from)), maxi(0, int(pd.due) - Game.time.now())], 12, UI.TEXT, true))
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
