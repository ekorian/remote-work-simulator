class_name CallView
extends Dim

signal ended()

const THINK := 22.0

var _title: Label
var _dots: HBoxContainer
var _tiles: HBoxContainer
var _speaker: Label
var _line: Label
var _choices: ChoiceList
var _timer: StatBar
var _timer_label: Label
var _reply: PanelContainer
var _reply_label: Label
var _left := 0.0
var _limit := 20.0
var _waiting := false
var _showing_reply := false
var _health: Label
var _hang: Button

func _ready() -> void:
	setup(0.86)
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
	_timer = StatBar.new()
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
		Game.comms.call_hang_up()
		_finish()
	, "danger", 13)
	foot.add_child(_hang)

func start() -> void:
	if not Game.comms.in_call():
		return
	visible = true
	_reply.visible = false
	_showing_reply = false
	var m := Game.comms.meeting(str(Game.comms.live_call.mid))
	_title.text = str(m.get("title", "Call"))
	_limit = THINK * float(Game.diff().window)
	Bus.sfx.emit("join")
	_show_beat()

func _show_beat() -> void:
	var b := Game.comms.call_beat()
	if b.is_empty():
		_finish()
		return
	_showing_reply = false
	_reply.visible = false
	var c: Dictionary = Game.comms.live_call
	UI.clear(_dots)
	for i in c.beats.size():
		var d := Panel.new()
		d.custom_minimum_size = Vector2(12, 12)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		d.add_theme_stylebox_override("panel", UI.sb(UI.ACCENT if i == int(c.i) else (UI.GREEN if i < int(c.i) else UI.LINE), 6))
		_dots.add_child(d)
	var who: String = str(b.who)
	UI.clear(_tiles)
	var cast: Array = [Game.npcs.boss_id(), "priya", "kevin", "dave", "linda"]
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
		var nl := UI.label(Game.npcs.display_name(str(id)).get_slice(" ", 0), 12, UI.TEXT if on else UI.DIM, true)
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
	_speaker.text = Game.npcs.display_name(who).to_upper()
	_line.text = Game.comms.fmt(str(b.text))
	_choices.visible = true
	_choices.show_choices(Game.comms.call_choices(), Game.comms.call_context(), who)
	_left = _limit
	_waiting = true
	_timer.max_value = _limit
	_hang.visible = true
	Bus.sfx.emit("talk")

func _process(delta: float) -> void:
	if not visible:
		return
	_health.text = "Health %d" % int(round(Game.stats.get_value("health"))) if Game.active else ""
	if not _waiting:
		return
	_left -= delta
	_timer.value = maxf(0.0, _left)
	_timer.color = UI.RED if _left < 6.0 else UI.ACCENT
	_timer_label.text = "%ds to answer" % int(ceil(maxf(0.0, _left)))
	if _left <= 0.0:
		_waiting = false
		var res := Game.comms.call_timeout()
		_after(res, "...")

func _on_chosen(i: int, excuse_id: String) -> void:
	if not _waiting:
		return
	var list := Game.comms.call_choices()
	if i < 0 or i >= list.size():
		return
	var said: String = Game.comms.fmt(str(list[i].t))
	if excuse_id != "":
		said = str(Db.claims[excuse_id].line)
	var res := Game.comms.call_choose(i, excuse_id)
	if not bool(res.get("done", false)):
		if not Game.active or Game.time.phase == "over":
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
	var say: String = Game.comms.fmt(str(res.get("say", "")))
	_reply.visible = true
	_reply.add_theme_stylebox_override("panel", UI.sb(Color(UI.GREEN, 0.16) if ok else Color(UI.RED, 0.18), 12, 1, UI.GREEN if ok else UI.RED, 12, 12))
	_reply_label.text = "You: %s%s" % [said, ("\n\n" + say) if say != "" else ""]
	Bus.sfx.emit("good" if ok else "bad")
	var wait := clampf(1.3 + float(say.length()) * 0.035, 1.6, 4.2)
	await get_tree().create_timer(wait, true, false, true).timeout
	if not visible:
		return
	if not Game.active or Game.time.phase == "over" or bool(res.get("end", false)) or not Game.comms.in_call():
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
