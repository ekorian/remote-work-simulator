class_name Hud
extends Control
## HUD — clock, the four resources, buffs, the "needs you" inbox, the tutorial
## checklist, interaction prompts, activity progress and toasts.

signal inbox_clicked(prompt_id: String)
signal ring_clicked()
signal option_chosen(thing: Interactable, option_id: String)
signal menu_closed()

const COL_W := 348.0

var world: World
var desk_mode := false:            ## the desktop is open: hide world-only widgets
	set(v):
		desk_mode = v
		_layout_dirty = true

var _clock_card: Control
var _time: Label
var _day: Label
var _day_bar: StatBar
var _presence: PanelContainer
var _presence_label: Label
var _presence_dot: Panel
var _next_label: Label
var _slack_label: Label
var _speed: PanelContainer
var _bars: Dictionary = {}
var _vals: Dictionary = {}
var _deltas: Dictionary = {}
var _delta_state: Dictionary = {}
var _why: Label
var _why_until := 0.0
var _money: Label
var _favor: Label
var _battery: Label
var _heat_chip: Control
var _heat: Label
var _buffs: HFlowContainer
var _tut: PanelContainer
var _tut_body: VBoxContainer
var _inbox: VBoxContainer
var _inbox_rows: Array = []
var _prompt: PanelContainer
var _prompt_title: Label
var _prompt_hint: Label
var _tag: PanelContainer
var _tag_label: Label
var _act: PanelContainer
var _act_label: Label
var _act_bar: StatBar
var _toasts: VBoxContainer
var _menu: PanelContainer
var _menu_thing: Interactable
var _column: VBoxContainer
var _dirty := true
var _layout_dirty := true
var _feed_last: Dictionary = {}
var _t := 0.0


class StatBar:
	extends Control
	## Smoothly animated bar with optional threshold ticks.
	var value := 0.0
	var shown := 0.0
	var max_value := 100.0
	var color := Color.WHITE
	var ticks: Array = []
	var pulse := false
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(40, 12)

	func _process(delta: float) -> void:
		_t += delta
		if not is_equal_approx(shown, value) or pulse:
			shown = lerpf(shown, value, minf(1.0, delta * 9.0))
			if absf(shown - value) < 0.05:
				shown = value
			queue_redraw()

	func _draw() -> void:
		var r := size.y / 2.0
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.38)
		bg.set_corner_radius_all(int(r))
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		var f := clampf(shown / max_value, 0.0, 1.0)
		if f > 0.005:
			var fill := StyleBoxFlat.new()
			var c := color
			if pulse:
				c = c.lerp(Color.WHITE, 0.25 + 0.25 * sin(_t * 9.0))
			fill.bg_color = c
			fill.set_corner_radius_all(int(r))
			draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(maxf(size.y, size.x * f), size.y)))
		for tk in ticks:
			var x := size.x * float(tk) / max_value
			draw_line(Vector2(x, 1), Vector2(x, size.y - 1), Color(1, 1, 1, 0.55), 1.5)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full(self)
	_build_clock()
	_build_column()
	_build_bottom()
	_build_toasts()
	Game.stat_changed.connect(_on_stat)
	Game.money_changed.connect(_on_money)
	Game.buffs_changed.connect(func(): _dirty = true)
	Game.favor_changed.connect(func(_v): _dirty = true)
	Bus.toast.connect(toast)
	Bus.comms_changed.connect(func(): _dirty = true)
	Bus.meeting_changed.connect(func(_m): _dirty = true)
	Bus.tutorial_changed.connect(func(): _dirty = true)
	Bus.gadget_changed.connect(func(_g): _dirty = true)
	Bus.state_loaded.connect(_on_loaded)
	Game.day_started.connect(func(_d): _dirty = true)


func _on_loaded() -> void:
	_dirty = true
	_why.text = ""
	for st2 in _deltas:
		(_deltas[st2] as Label).text = ""
	UI.clear(_toasts)
	for st in _bars:
		(_bars[st] as StatBar).shown = Game.get_stat(st)


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.shadowed(UI.sb(Color(UI.PANEL, 0.94), 16, 0, Color.TRANSPARENT, 14, 12), 14, 0.28))
	return p


func _build_clock() -> void:
	var p := _card()
	p.position = Vector2(16, 16)
	p.custom_minimum_size = Vector2(250, 0)
	add_child(p)
	_clock_card = p
	var v := UI.vbox(5)
	p.add_child(v)
	var top := UI.hbox(10)
	v.add_child(top)
	_time = UI.title("08:59", 44)
	top.add_child(_time)
	var side := UI.vbox(2)
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(side)
	_day = UI.title("MONDAY", 17, UI.ACCENT)
	side.add_child(_day)
	_speed = UI.pill(">> FAST", UI.TEAL, 11, true)
	side.add_child(_speed)
	_day_bar = StatBar.new()
	_day_bar.color = UI.ACCENT
	_day_bar.max_value = float(Cfg.WORK_END - Cfg.WORK_START)
	_day_bar.custom_minimum_size = Vector2(0, 8)
	v.add_child(_day_bar)
	var row := UI.hbox(8)
	v.add_child(row)
	_presence = PanelContainer.new()
	_presence.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0.3), 20, 0, Color.TRANSPARENT, 9, 3))
	var pr := UI.hbox(6)
	_presence_dot = Panel.new()
	_presence_dot.custom_minimum_size = Vector2(10, 10)
	_presence_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.add_child(_presence_dot)
	_presence_label = UI.label("Away", 13, UI.TEXT, true)
	pr.add_child(_presence_label)
	_presence.add_child(pr)
	row.add_child(_presence)
	_next_label = UI.label("", 12, UI.DIM)
	_next_label.clip_text = true
	_next_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_next_label.custom_minimum_size = Vector2(222, 0)
	v.add_child(_next_label)
	_slack_label = UI.label("", 12, UI.TEAL, true)
	_slack_label.tooltip_text = "Leisure between 09:00 and 17:00. This is what your final grade is made of."
	v.add_child(_slack_label)


func _stat_row(parent: Control, stat: String, text: String) -> void:
	var col: Color = UI.STAT_COLORS[stat]
	var row := UI.hbox(8)
	row.add_child(UI.icon(str(UI.STAT_ICONS[stat]), 20, col))
	var name_l := UI.label(text, 13, UI.TEXT, true)
	name_l.custom_minimum_size = Vector2(74, 0)
	row.add_child(name_l)
	var b := StatBar.new()
	b.color = col
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(60, 13)
	row.add_child(b)
	var val := UI.title("100", 17)
	val.custom_minimum_size = Vector2(34, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	var dl := UI.label("", 13, UI.GREEN, true)
	dl.custom_minimum_size = Vector2(32, 0)
	row.add_child(dl)
	parent.add_child(row)
	_bars[stat] = b
	_vals[stat] = val
	_deltas[stat] = dl
	_delta_state[stat] = {"sum": 0.0, "until": 0.0}


func _chip(icon_name: String, color: Color, tip: String) -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0.28), 20, 0, Color.TRANSPARENT, 9, 3))
	p.tooltip_text = tip
	var h := UI.hbox(5)
	h.add_child(UI.icon(icon_name, 15, color))
	var l := UI.label("0", 13, UI.TEXT, true)
	h.add_child(l)
	p.add_child(h)
	return [p, l]


func _build_column() -> void:
	_column = UI.vbox(10)
	_column.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_column.anchor_left = 1.0
	_column.anchor_right = 1.0
	_column.offset_left = -(COL_W + 16.0)
	_column.offset_right = -16.0
	_column.offset_top = 16.0
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	# Resources
	var p := _card()
	_column.add_child(p)
	var v := UI.vbox(7)
	p.add_child(v)
	_stat_row(v, "health", "Health")
	_stat_row(v, "energy", "Energy")
	_stat_row(v, "susp", "Suspicion")
	_stat_row(v, "ill", "Illusion")
	(_bars.susp as StatBar).ticks = [50, 75]
	(_bars.ill as StatBar).ticks = [25, 60]
	(_bars.health as StatBar).get_parent().tooltip_text = "Health: destroyed by real work, meetings and desk time. Restored by leisure, food and sleep. At 0 you burn out."
	(_bars.energy as StatBar).get_parent().tooltip_text = "Energy: spent on lying, faking and walking. Restored by food, coffee and naps."
	(_bars.susp as StatBar).get_parent().tooltip_text = "Suspicion: how sure management is that you do nothing. At 100 you are fired."
	(_bars.ill as StatBar).get_parent().tooltip_text = "Productivity Illusion: how productive you LOOK. Above 60 suspicion fades; below 25 it climbs."
	var chips := UI.hbox(6)
	v.add_child(chips)
	var c1 := _chip("coin", UI.ACCENT, "Money. Salary lands at 17:00.")
	_money = c1[1]
	chips.add_child(c1[0])
	var c2 := _chip("favor", Color("ff9ecb"), "Favours colleagues owe you. Spend them to delegate tickets.")
	_favor = c2[1]
	chips.add_child(c2[0])
	var c3 := _chip("phone", UI.BLUE, "Phone battery. Press Tab to answer from anywhere.")
	_battery = c3[1]
	chips.add_child(c3[0])
	var c4 := _chip("warn", UI.ORANGE, "Heat: how detectable your running gadgets are to a SynerWatch scan.")
	_heat = c4[1]
	_heat_chip = c4[0]
	chips.add_child(c4[0])
	_why = UI.label("", 12, UI.DIM)
	_why.clip_text = true
	_why.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_why.custom_minimum_size = Vector2(0, 17)
	v.add_child(_why)
	_buffs = HFlowContainer.new()
	_buffs.add_theme_constant_override("h_separation", 5)
	_buffs.add_theme_constant_override("v_separation", 5)
	v.add_child(_buffs)
	# Tutorial
	_tut = _card()
	_tut.add_theme_stylebox_override("panel", UI.shadowed(UI.sb(Color("3b2f6b"), 16, 2, UI.ACCENT, 14, 12), 14, 0.28))
	_column.add_child(_tut)
	_tut_body = UI.vbox(6)
	_tut.add_child(_tut_body)
	# Inbox
	_inbox = UI.vbox(7)
	_column.add_child(_inbox)


func _build_bottom() -> void:
	# Name tag floating over the focused object.
	_tag = PanelContainer.new()
	_tag.add_theme_stylebox_override("panel", UI.sb(Color(UI.INK, 0.86), 20, 0, Color.TRANSPARENT, 10, 4))
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag_label = UI.title("", 15)
	_tag.add_child(_tag_label)
	_tag.visible = false
	add_child(_tag)
	# Interaction prompt
	_prompt = _card()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	var h := UI.hbox(12)
	_prompt.add_child(h)
	var key := UI.pill("F", UI.ACCENT, 18, true)
	h.add_child(key)
	var v := UI.vbox(1)
	h.add_child(v)
	_prompt_title = UI.title("", 19)
	v.add_child(_prompt_title)
	_prompt_hint = UI.label("", 13, UI.DIM)
	v.add_child(_prompt_hint)
	_prompt.visible = false
	# Activity progress
	_act = _card()
	_act.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_act)
	var av := UI.vbox(7)
	_act.add_child(av)
	var ah := UI.hbox(10)
	av.add_child(ah)
	ah.add_child(UI.icon("fast", 18, UI.TEAL))
	_act_label = UI.title("", 18)
	_act_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ah.add_child(_act_label)
	ah.add_child(UI.pill("F  stop", UI.ACCENT, 12, true))
	_act_bar = StatBar.new()
	_act_bar.color = UI.TEAL
	_act_bar.custom_minimum_size = Vector2(380, 10)
	av.add_child(_act_bar)
	_act.visible = false
	# Object options menu
	_menu = _card()
	_menu.visible = false
	add_child(_menu)


func _build_toasts() -> void:
	_toasts = UI.vbox(6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)
	_place_toasts()


func _place_toasts() -> void:
	if desk_mode:
		# Bottom of the side strip, growing upwards, clear of the desktop.
		_toasts.anchor_left = 1.0
		_toasts.anchor_right = 1.0
		_toasts.anchor_top = 1.0
		_toasts.anchor_bottom = 1.0
		_toasts.offset_left = -(COL_W + 16.0)
		_toasts.offset_right = -16.0
		_toasts.offset_bottom = -16.0
		_toasts.offset_top = -16.0
		_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_toasts.alignment = BoxContainer.ALIGNMENT_END
	else:
		_toasts.anchor_left = 0.5
		_toasts.anchor_right = 0.5
		_toasts.anchor_top = 0.0
		_toasts.anchor_bottom = 0.0
		_toasts.offset_left = -250.0
		_toasts.offset_right = 250.0
		_toasts.offset_top = 14.0
		_toasts.offset_bottom = 14.0
		_toasts.grow_vertical = Control.GROW_DIRECTION_END
		_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN


# ---------------------------------------------------------------------------
# Toasts and feed
# ---------------------------------------------------------------------------

func toast(text: String, kind: String = "info") -> void:
	if not is_inside_tree():
		return
	while _toasts.get_child_count() >= 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var col := UI.DIM
	var icon_name := "dot"
	match kind:
		"good":
			col = UI.GREEN
			icon_name = "check"
		"bad":
			col = UI.RED
			icon_name = "warn"
		"warn":
			col = UI.ACCENT
			icon_name = "warn"
		"money":
			col = UI.ACCENT
			icon_name = "coin"
		"tip":
			col = UI.PURPLE
			icon_name = "spark"
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.shadowed(UI.sb(Color(UI.INK, 0.93), 12, 2, Color(col, 0.75), 12, 8), 10, 0.3))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UI.hbox(9)
	h.add_child(UI.icon(icon_name, 18, col))
	var l := UI.wrap(("TIP: " if kind == "tip" else "") + text, 14)
	h.add_child(l)
	p.add_child(h)
	_toasts.add_child(p)
	p.modulate.a = 0.0
	var life := 9.0 if kind == "tip" else clampf(2.6 + float(text.length()) * 0.045, 3.2, 7.0)
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.tween_interval(life)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


func _on_stat(stat: String, _value: float, delta: float, reason: String) -> void:
	if reason == "" or absf(delta) < 0.6:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var st: Dictionary = _delta_state[stat]
	if now > float(st.until):
		st.sum = 0.0
	st.sum = float(st.sum) + delta
	st.until = now + 3.2
	var total := float(st.sum)
	var good := total > 0.0
	if stat == "susp":
		good = not good
	var dl: Label = _deltas[stat]
	dl.text = "%+d" % int(round(total))
	dl.add_theme_color_override("font_color", UI.GREEN if good else UI.RED)
	dl.modulate.a = 1.0
	_why.text = "%s %+d: %s" % [str(Game.STAT_NAMES[stat]).get_slice(" ", -1) if stat == "ill" else str(Game.STAT_NAMES[stat]), int(round(total)), reason]
	_why.add_theme_color_override("font_color", UI.GREEN if good else Color("ff9aa8"))
	_why.modulate.a = 1.0
	_why_until = now + 4.5
	if stat == "susp" and delta >= 4.0:
		Bus.sfx.emit("alarm")


func _on_money(_value: int, delta: int, reason: String) -> void:
	if delta == 0:
		return
	toast("%s$%d  %s" % ["+" if delta > 0 else "-", absi(delta), reason], "money")
	Bus.sfx.emit("coin" if delta > 0 else "buy")


# ---------------------------------------------------------------------------
# Object menu
# ---------------------------------------------------------------------------

func open_menu(thing: Interactable) -> void:
	_menu_thing = thing
	for c in _menu.get_children():
		_menu.remove_child(c)
		c.queue_free()
	var v := UI.vbox(7)
	_menu.add_child(v)
	var head := UI.hbox(8)
	var t := UI.title(thing.title, 21)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UI.pill("Esc", UI.DIM, 11))
	v.add_child(head)
	var opts := Interact.options(thing.thing_id)
	for i in opts.size():
		var o: Dictionary = opts[i]
		var c := UI.Clicky.new()
		c.setup(UI.PANEL2, UI.LINE, 1, false)
		c.custom_minimum_size = Vector2(430, 0)
		c.disabled = not bool(o.ok)
		var row := UI.hbox(10)
		row.add_child(UI.pill(str(i + 1), UI.ACCENT, 13, true))
		var col := UI.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UI.title(str(o.label), 16))
		var hint: String = str(o.hint) if bool(o.ok) else str(o.why)
		if hint != "":
			col.add_child(UI.wrap(hint, 12, UI.DIM if bool(o.ok) else UI.RED))
		var badge := Actions.badge(str(o.act))
		if str(badge.text) != "":
			col.add_child(UI.pill(str(badge.text), badge.color, 10))
		row.add_child(col)
		c.add_child(row)
		c.pressed.connect(_menu_pick.bind(str(o.id)))
		v.add_child(c)
	_menu.visible = true
	_menu.reset_size()
	_place_menu.call_deferred()


func _place_menu() -> void:
	_menu.reset_size()
	_menu.position = Vector2((size.x - _menu.size.x) / 2.0, size.y - _menu.size.y - 30.0)


func menu_open() -> bool:
	return _menu.visible


func close_menu() -> void:
	if _menu.visible:
		_menu.visible = false
		_menu_thing = null
		menu_closed.emit()


func _menu_pick(opt_id: String) -> void:
	var t := _menu_thing
	_menu.visible = false
	_menu_thing = null
	menu_closed.emit()
	if t != null:
		option_chosen.emit(t, opt_id)


func _unhandled_key_input(e: InputEvent) -> void:
	if not _menu.visible:
		return
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var n := int(k.physical_keycode) - KEY_1
	var opts := Interact.options(_menu_thing.thing_id) if _menu_thing != null else []
	if n >= 0 and n < opts.size() and bool(opts[n].ok):
		get_viewport().set_input_as_handled()
		_menu_pick(str(opts[n].id))


# ---------------------------------------------------------------------------
# Per-frame
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not Game.active:
		return
	_t += delta
	var s: Dictionary = Game.s
	var evening: bool = s.phase == "evening"
	# Clock
	var t := Game.clock()
	_time.text = Cfg.fmt_time(fposmod(t, 1440.0))
	_day.text = "%s%s" % [Game.day_name().to_upper(), "  NIGHT" if evening else ""]
	_day_bar.value = clampf(t - Cfg.WORK_START, 0.0, _day_bar.max_value)
	_day_bar.color = UI.PURPLE if evening else UI.ACCENT
	_speed.visible = Game.speed > 1.0
	var st: String = "offline" if evening else str(s.pres.status)
	var pinfo: Dictionary = Cfg.PRESENCE[st]
	_presence_label.text = "Off the clock" if evening else str(pinfo.label)
	var pcol: Color = pinfo.color
	if not evening and Game.absent() and Game.in_work_hours():
		pcol = pcol.lerp(UI.RED, 0.5 + 0.5 * sin(_t * 6.0))
		_presence_label.text += "  !"
	elif not evening and Game.covered() and st in ["away", "offline"]:
		_presence_label.text += " (excused)"
	_presence_dot.add_theme_stylebox_override("panel", UI.sb(pcol, 5))
	if evening:
		_next_label.text = "Sleep in the bed to start %s." % (Cfg.DAYS[int(s.day) + 1] if int(s.day) < 4 else "the weekend")
	else:
		var nm := Corp.next_meeting()
		if not nm.is_empty():
			_next_label.text = "Next: %s at %s" % [str(nm.title), Cfg.fmt_time(float(nm.start))]
		else:
			_next_label.text = "No more meetings today."
	_slack_label.text = "Slacked on the clock: %s" % Cfg.fmt_dur(float(s.today.get("slack_min", 0)))
	# Resources
	for stat in _bars:
		var v := Game.get_stat(stat)
		(_bars[stat] as StatBar).value = v
		(_vals[stat] as Label).text = str(int(round(v)))
	var now_s := Time.get_ticks_msec() / 1000.0
	for stat in _deltas:
		var left := float(_delta_state[stat].until) - now_s
		(_deltas[stat] as Label).modulate.a = clampf(left / 0.6, 0.0, 1.0)
	_why.modulate.a = clampf((_why_until - now_s) / 0.8, 0.0, 1.0)
	(_bars.susp as StatBar).pulse = Game.get_stat("susp") >= 75.0
	(_bars.health as StatBar).pulse = Game.get_stat("health") <= 25.0
	_money.text = "$%d" % int(s.money)
	_favor.text = str(int(s.favor))
	_battery.text = "%d%%%s" % [int(s.things.phone_bat), "" if Interact.phone_carried() else " (dock)"]
	var heat := Auto.heat()
	_heat_chip.visible = heat > 0.0
	_heat.text = "%d" % int(heat)
	if _dirty:
		_dirty = false
		_rebuild_lists()
	# Inbox countdowns
	var now := float(Game.now()) + fposmod(Game.clock(), 1.0)
	for row in _inbox_rows:
		if is_instance_valid(row.bar):
			var left := float(row.due) - now
			(row.bar as StatBar).value = clampf(left, 0.0, float(row.window))
			(row.bar as StatBar).color = UI.RED if left < 6.0 else (UI.ACCENT if left < 12.0 else UI.GREEN)
			(row.time as Label).text = "%d min" % int(maxf(0.0, ceil(left)))
	_clock_card.visible = not desk_mode
	if _layout_dirty:
		_layout_dirty = false
		_place_toasts()
	_update_world_widgets()


func _update_world_widgets() -> void:
	var show_world := world != null and not desk_mode and world.interactive and not Game.paused
	var busy := Game.busy()
	_act.visible = busy and (show_world or desk_mode) and not Game.paused
	if _act.visible:
		var a: Dictionary = Game.s.act
		_act_label.text = "%s  -  %s left" % [str(a.label), Cfg.fmt_dur(float(a.left))]
		_act_bar.max_value = float(a.total)
		_act_bar.value = float(a.total) - float(a.left)
		_act.reset_size()
		var span := size.x - (COL_W + 28.0) if desk_mode else size.x
		_act.position = Vector2((span - _act.size.x) / 2.0, size.y - _act.size.y - 28.0)
	var f: Interactable = world.focused if show_world and not busy and not _menu.visible else null
	_prompt.visible = f != null
	_tag.visible = f != null
	if f != null:
		var opts := Interact.options(f.thing_id)
		_prompt_title.text = f.title
		if opts.size() == 1:
			_prompt_hint.text = str(opts[0].label) if bool(opts[0].ok) else str(opts[0].why)
		else:
			_prompt_hint.text = "%d options" % opts.size()
		_prompt.reset_size()
		_prompt.position = Vector2((size.x - _prompt.size.x) / 2.0, size.y - _prompt.size.y - 28.0)
		_tag_label.text = f.title
		_tag.reset_size()
		var sp := world.rig.cam.unproject_position(f.focus_point())
		_tag.position = (sp - Vector2(_tag.size.x / 2.0, _tag.size.y + 6.0)).round()
	if _menu.visible and (world == null or not world.interactive and false):
		close_menu()


func _rebuild_lists() -> void:
	# Buffs
	UI.clear(_buffs)
	for id in Game.s.buffs:
		var b: Dictionary = Game.BUFFS.get(id, {"name": id, "desc": "", "good": true})
		var pl := UI.pill(str(b.name), UI.GREEN if bool(b.good) else UI.ORANGE, 11)
		pl.mouse_filter = Control.MOUSE_FILTER_STOP
		pl.tooltip_text = str(b.desc)
		_buffs.add_child(pl)
	if str(Game.s.outfit) != "casual":
		var o: Dictionary = Interact.OUTFITS[str(Game.s.outfit)]
		var pl := UI.pill("Wearing: %s" % ("shirt" if str(Game.s.outfit) == "shirt" else "pajamas"), UI.BLUE, 11)
		pl.mouse_filter = Control.MOUSE_FILTER_STOP
		pl.tooltip_text = str(o.hint)
		_buffs.add_child(pl)
	if Interact.desk_staged():
		_buffs.add_child(UI.pill("Desk staged", UI.GREEN, 11))
	_buffs.visible = _buffs.get_child_count() > 0
	# Tutorial
	_tut.visible = Tutor.active()
	if _tut.visible:
		UI.clear(_tut_body)
		var pr := Tutor.progress()
		var st := Tutor.step()
		var head := UI.hbox(6)
		var ht := UI.title("FIRST DAY  %d/%d" % [pr.x, pr.y], 13, UI.ACCENT)
		ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(ht)
		var skip := UI.button("skip", Tutor.skip, "ghost", 11)
		head.add_child(skip)
		_tut_body.add_child(head)
		if not st.is_empty():
			_tut_body.add_child(UI.title(str(st.title), 19))
			_tut_body.add_child(UI.wrap(str(st.text), 13, Color("e6dcff")))
		if bool(Game.s.get("hold", false)):
			_tut_body.add_child(UI.wrap("The clock is paused until you use something.", 12, UI.TEAL))
	# Inbox
	UI.clear(_inbox)
	_inbox_rows.clear()
	if Game.s.phase != "work":
		return
	var ring := Corp.ringing()
	if not ring.is_empty() and not Corp.in_call():
		var c := UI.Clicky.new()
		c.setup(Color("7a2b3d"), UI.RED, 2, false, 14)
		var h := UI.hbox(10)
		h.add_child(UI.icon("call", 26, UI.TEXT))
		var col := UI.vbox(1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UI.title("RINGING", 13, Color("ffd3da")))
		var rt := UI.title(str(ring.title), 15)
		rt.clip_text = true
		rt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(rt)
		col.add_child(UI.label("Click to respond", 12, Color("ffd3da")))
		h.add_child(col)
		c.add_child(h)
		c.pressed.connect(func(): ring_clicked.emit())
		_inbox.add_child(c)
	var list := Corp.prompts()
	if not Game.can_notice():
		if not list.is_empty():
			var p := UI.panel(Color(UI.INK, 0.7), 12, 10)
			p.add_child(UI.wrap("Something buzzed in the office. You can't tell what from here (no phone on you).", 12, UI.DIM))
			_inbox.add_child(p)
		return
	for i in mini(list.size(), 4):
		var pd: Dictionary = list[i]
		var c := UI.Clicky.new()
		c.setup(Color(UI.PANEL, 0.95), Color(Content.person_color(str(pd.from)), 0.8), 1, false, 12)
		var h := UI.hbox(9)
		h.add_child(UI.avatar(str(pd.from), 30))
		var col := UI.vbox(3)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top := UI.hbox(6)
		var nm := UI.label(Content.person_name(str(pd.from)), 13, UI.TEXT, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		top.add_child(nm)
		var tl := UI.label("", 12, UI.DIM, true)
		top.add_child(tl)
		col.add_child(top)
		var txt := UI.label(str(pd.text), 12, UI.DIM)
		txt.clip_text = true
		txt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(txt)
		var bar := StatBar.new()
		bar.max_value = maxf(1.0, float(pd.window))
		bar.custom_minimum_size = Vector2(0, 6)
		col.add_child(bar)
		h.add_child(col)
		c.add_child(h)
		c.pressed.connect(func(): inbox_clicked.emit(str(pd.id)))
		_inbox.add_child(c)
		_inbox_rows.append({"bar": bar, "time": tl, "due": int(pd.due), "window": int(pd.window)})
	if list.size() > 4:
		_inbox.add_child(UI.label("+ %d more waiting" % (list.size() - 4), 12, UI.DIM))
