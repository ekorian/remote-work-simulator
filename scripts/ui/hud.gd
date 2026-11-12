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
var _earned: Label
var _claims: VBoxContainer
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
var _key: Label
var _cross: Control
var _held: PanelContainer
var _held_title: Label
var _held_hint: Label
var _held_keys: Label
var _pockets: HBoxContainer
var _icons: ItemIcons
var _pocket_sig := ""
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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full(self)
	_build_clock()
	_build_column()
	_build_bottom()
	_build_toasts()
	Game.stats.changed.connect(_on_stat)
	Game.economy.money_changed.connect(_on_money)
	Game.stats.buffs_changed.connect(func(): _dirty = true)
	Game.economy.favors_changed.connect(func(_v): _dirty = true)
	Bus.toast.connect(toast)
	Bus.comms_changed.connect(func(): _dirty = true)
	Bus.meeting_changed.connect(func(_m): _dirty = true)
	Bus.tutorial_changed.connect(func(): _dirty = true)
	Bus.gadget_changed.connect(func(_g): _dirty = true)
	Bus.state_loaded.connect(_on_loaded)
	Game.day_started.connect(func(_d): _dirty = true)
	Game.deception.claim_added.connect(func(_c): _dirty = true)
	Game.deception.claim_changed.connect(func(_c): _dirty = true)
	Game.time.minute_passed.connect(func(): if not Game.deception.live_claims().is_empty(): _dirty = true)


func _on_loaded() -> void:
	_dirty = true
	_why.text = ""
	for st2 in _deltas:
		(_deltas[st2] as Label).text = ""
	UI.clear(_toasts)
	for st in _bars:
		(_bars[st] as StatBar).shown = Game.stats.get_value(st)


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
	var c1 := _chip("coin", UI.ACCENT, "Cash to spend. Salary lands at 17:00.")
	_money = c1[1]
	chips.add_child(c1[0])
	var c0 := _chip("check", UI.GREEN, "Salary earned this week, for doing nothing.")
	_earned = c0[1]
	chips.add_child(c0[0])
	var c2 := _chip("favor", Color("ff9ecb"), "Favours colleagues owe you. Spend them on a colleague in SynerTeams: tickets, meetings, a good word.")
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
	# Live stories
	_claims = UI.vbox(5)
	_claims.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_claims)
	# Inbox
	_inbox = UI.vbox(7)
	_column.add_child(_inbox)


func _build_bottom() -> void:
	# Crosshair: a dot that opens into a ring over something you can use.
	_cross = Control.new()
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cross.draw.connect(_draw_cross)
	add_child(_cross)
	# What is in your hand, and what you can do with it.
	_held = _card()
	_held.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held.visible = false
	add_child(_held)
	var hv := UI.vbox(2)
	_held.add_child(hv)
	_held_title = UI.title("", 18)
	hv.add_child(_held_title)
	_held_hint = UI.label("", 13, UI.DIM)
	hv.add_child(_held_hint)
	_held_keys = UI.label("", 12, UI.ACCENT, true)
	hv.add_child(_held_keys)
	# Pockets: one square per thing you are carrying.
	_icons = ItemIcons.new()
	add_child(_icons)
	_pockets = UI.hbox(5)
	_pockets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pockets)
	# Interaction prompt
	_prompt = _card()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	var h := UI.hbox(12)
	_prompt.add_child(h)
	var key := UI.pill("E", UI.ACCENT, 18, true)
	_key = key.get_child(0)
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
	ah.add_child(UI.pill("E  stop", UI.ACCENT, 12, true))
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
	_why.text = "%s %+d: %s" % [str(PlayerStats.STAT_NAMES[stat]).get_slice(" ", -1) if stat == "ill" else str(PlayerStats.STAT_NAMES[stat]), int(round(total)), reason]
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
	var opts := Game.home.options(thing.thing_id)
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
		var badge := Game.work.badge(str(o.act))
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
	_menu.position = Vector2((size.x - _menu.size.x) / 2.0, maxf(20.0, (size.y - _menu.size.y) / 2.0 + 40.0))


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
	var opts := Game.home.options(_menu_thing.thing_id) if _menu_thing != null else []
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
	var evening: bool = Game.time.phase == "evening"
	# Clock
	var t := Game.time.clock()
	_time.text = Cfg.fmt_time(fposmod(t, 1440.0))
	_day.text = "%s%s" % [Game.time.day_name().to_upper(), "  NIGHT" if evening else ""]
	_day_bar.value = clampf(t - Cfg.WORK_START, 0.0, _day_bar.max_value)
	_day_bar.color = UI.PURPLE if evening else UI.ACCENT
	_speed.visible = Game.time.speed > 1.0
	var st: String = "offline" if evening else Game.presence.status
	var pinfo: Dictionary = Cfg.PRESENCE[st]
	_presence_label.text = "Off the clock" if evening else str(pinfo.label)
	var pcol: Color = pinfo.color
	if not evening and Game.presence.absent() and Game.time.in_work_hours():
		pcol = pcol.lerp(UI.RED, 0.5 + 0.5 * sin(_t * 6.0))
		_presence_label.text += "  !"
	elif not evening and Game.presence.covered() and st in ["away", "offline"]:
		_presence_label.text += " (excused)"
	_presence_dot.add_theme_stylebox_override("panel", UI.sb(pcol, 5))
	if evening:
		_next_label.text = "Sleep in the bed to start %s." % (Cfg.DAYS[Game.time.day + 1] if Game.time.day < 4 else "the weekend")
	else:
		var nm := Game.comms.next_meeting()
		if not nm.is_empty():
			_next_label.text = "Next: %s at %s" % [str(nm.title), Cfg.fmt_time(float(nm.start))]
		else:
			_next_label.text = "No more meetings today."
	_slack_label.text = "Slacked on the clock: %s" % Cfg.fmt_dur(float(Game.today.get("slack_min", 0)))
	# Resources
	for stat in _bars:
		var v := Game.stats.get_value(stat)
		(_bars[stat] as StatBar).value = v
		(_vals[stat] as Label).text = str(int(round(v)))
	var now_s := Time.get_ticks_msec() / 1000.0
	for stat in _deltas:
		var left := float(_delta_state[stat].until) - now_s
		(_deltas[stat] as Label).modulate.a = clampf(left / 0.6, 0.0, 1.0)
	_why.modulate.a = clampf((_why_until - now_s) / 0.8, 0.0, 1.0)
	(_bars.susp as StatBar).pulse = Game.stats.get_value("susp") >= 75.0
	(_bars.health as StatBar).pulse = Game.stats.get_value("health") <= 25.0
	_money.text = "$%d" % Game.economy.money
	_earned.text = "$%d" % Game.economy.earned
	_favor.text = str(Game.economy.favors)
	_battery.text = "%d%%%s" % [int(Game.home.things.phone_bat), "" if Game.home.phone_carried() else " (dock)"]
	var heat := Game.automation.heat()
	_heat_chip.visible = heat > 0.0
	_heat.text = "%d" % int(heat)
	if _dirty:
		_dirty = false
		_rebuild_lists()
	# Inbox countdowns
	var now := float(Game.time.now()) + fposmod(Game.time.clock(), 1.0)
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
	var busy := Game.activities.busy()
	_act.visible = busy and (show_world or desk_mode) and not Game.paused
	if _act.visible:
		var a: Dictionary = Game.activities.current
		_act_label.text = "%s  -  %s left" % [str(a.label), Cfg.fmt_dur(float(a.left))]
		_act_bar.max_value = float(a.total)
		_act_bar.value = float(a.total) - float(a.left)
		_act.reset_size()
		var span := size.x - (COL_W + 28.0) if desk_mode else size.x
		_act.position = Vector2((span - _act.size.x) / 2.0, size.y - _act.size.y - 28.0)
	var aiming := show_world and not busy and not _menu.visible and world.view == "play"
	var f: Interactable = world.focused if aiming else null
	var fi: Holdable = world.focused_item if aiming else null
	var fp: TownPerson = world.focused_person if aiming else null
	var fw: Dictionary = world.focused_ware if aiming else {}
	_cross.visible = aiming
	_cross.set_meta("on", f != null or fi != null or fp != null or not fw.is_empty())
	_cross.queue_redraw()
	_prompt.visible = f != null or fi != null or fp != null or not fw.is_empty()
	if fp != null:
		_prompt_title.text = fp.title
		var giving: bool = world.held != null and fp.npc != "" and Game.social.is_colleague(fp.npc) and not bool(Game.home.item(world.held.item_id).get("trash", false))
		_prompt_hint.text = ("Give them the %s" % world.held.title.to_lower()) if giving else "Talk"
		if fp.npc != "" and Game.social.is_colleague(fp.npc):
			_prompt_hint.text += "  -  %s" % Game.social.tier_name(fp.npc)
	elif not fw.is_empty():
		var what := str(fw.what)
		var cost := Game.home.price_of(what)
		_prompt_title.text = "%s  -  $%d" % [Game.home.name_of(what), cost]
		if not Game.home.shop_open(str(fw.shop)):
			_prompt_hint.text = "Closed"
		elif not Game.economy.can_afford(cost):
			_prompt_hint.text = "You can't afford it"
		else:
			_prompt_hint.text = "Buy" + (("  -  +%d Energy" % int(Db.foods[what].energy)) if Db.foods.has(what) else "")
	elif fi != null:
		var it := Game.home.item(fi.item_id)
		_prompt_title.text = fi.title
		_prompt_hint.text = "Pick up" if world.held == null else "Swap for what you are holding"
		if not it.is_empty() and bool(it.get("hot", false)):
			_prompt_hint.text += "  -  hot"
	elif f != null:
		var opts := Game.home.options(f.thing_id)
		_prompt_title.text = f.title
		if opts.size() == 1:
			_prompt_hint.text = str(opts[0].label) if bool(opts[0].ok) else str(opts[0].why)
		else:
			_prompt_hint.text = "%d options" % opts.size()
	if _prompt.visible:
		_prompt.reset_size()
		_prompt.position = Vector2((size.x - _prompt.size.x) / 2.0, size.y * 0.5 + 54.0)
	# The thing in your hand.
	var hb: Holdable = world.held if show_world and world.view == "play" and not _menu.visible else null
	_held.visible = hb != null and not busy
	if _held.visible:
		var it := Game.home.item(hb.item_id)
		_held_title.text = hb.title
		var keys := "RMB put down    Q throw    R pocket"
		if Game.home.is_prop(it):
			_held_hint.text = str(Game.home.prop(it).get("blurb", ""))
			var verb := Game.home.prop_verb(it)
			if verb != "":
				keys = "LMB %s    %s" % [verb, keys]
		elif bool(it.get("trash", false)):
			_held_hint.text = "Rubbish. It belongs in a bin."
		else:
			var view := Game.home.bite_view(it)
			var total := int(Game.home.food(it).get("bites", 1))
			var parts: Array = ["%d of %d left" % [int(it.bites), total]]
			if float(view.energy) >= 0.5:
				parts.append("+%d Energy a bite" % int(round(float(view.energy))))
			if absf(float(view.health)) >= 0.5:
				parts.append("%+d Health" % int(round(float(view.health))))
			if bool(it.get("hot", false)):
				parts.append("hot")
			_held_hint.text = "  -  ".join(parts) if bool(view.ok) else str(view.why)
			keys = "LMB %s    %s" % [str(view.verb).to_lower(), keys]
		_held_keys.text = keys
		_held.reset_size()
		_held.position = Vector2((size.x - _held.size.x) / 2.0, size.y - _held.size.y - 92.0)
	_update_pockets(show_world and world.view == "play" and not _menu.visible)


func _update_pockets(show: bool) -> void:
	var ids: Array = Game.home.pockets
	_pockets.visible = show and not ids.is_empty()
	if not _pockets.visible:
		return
	var sig := ",".join(ids) + "|" + str(Game.home.items.size())
	var ready := true
	if sig != _pocket_sig:
		_pocket_sig = sig
		UI.clear(_pockets)
		for i in ids.size():
			var it := Game.home.item(str(ids[i]))
			var slot := PanelContainer.new()
			slot.add_theme_stylebox_override("panel", UI.sb(Color(UI.PANEL, 0.92), 12, 1, UI.LINE, 4, 4))
			slot.custom_minimum_size = Vector2(62, 62)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.tooltip_text = Game.home.item_name(it)
			var tint: Color = Game.home.food(it).get("tint", Color("5ad1c8"))
			var tex := _icons.icon(Game.home.item_model(it), tint)
			if tex != null:
				var pic := TextureRect.new()
				pic.texture = tex
				pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				pic.custom_minimum_size = Vector2(54, 54)
				pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.add_child(pic)
			else:
				ready = false
				var name_l := UI.label(Game.home.item_name(it), 10, UI.TEXT, true)
				name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				name_l.custom_minimum_size = Vector2(54, 54)
				slot.add_child(name_l)
			var key := UI.label(str(i + 1), 11, UI.ACCENT, true)
			key.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			slot.add_child(key)
			_pockets.add_child(slot)
		if not ready:
			_pocket_sig = ""            # pictures still rendering: build again next frame
	_pockets.reset_size()
	_pockets.position = Vector2((size.x - _pockets.size.x) / 2.0, size.y - _pockets.size.y - 18.0)


func _draw_cross() -> void:
	var c := size / 2.0
	if bool(_cross.get_meta("on", false)):
		_cross.draw_arc(c, 11.0, 0.0, TAU, 28, Color(UI.INK, 0.55), 5.0, true)
		_cross.draw_arc(c, 11.0, 0.0, TAU, 28, UI.ACCENT, 2.5, true)
	_cross.draw_circle(c, 3.6, Color(UI.INK, 0.55))
	_cross.draw_circle(c, 2.2, Color.WHITE)


func _rebuild_lists() -> void:
	# Buffs
	UI.clear(_buffs)
	for id in Game.stats.buffs:
		var b: Dictionary = PlayerStats.BUFFS.get(id, {"name": id, "desc": "", "good": true})
		var pl := UI.pill(str(b.name), UI.GREEN if bool(b.good) else UI.ORANGE, 11)
		pl.mouse_filter = Control.MOUSE_FILTER_STOP
		pl.tooltip_text = str(b.desc)
		_buffs.add_child(pl)
	if str(Game.home.outfit) != "casual":
		var o: Dictionary = Home.OUTFITS[str(Game.home.outfit)]
		var pl := UI.pill("Wearing: %s" % ("shirt" if str(Game.home.outfit) == "shirt" else "pajamas"), UI.BLUE, 11)
		pl.mouse_filter = Control.MOUSE_FILTER_STOP
		pl.tooltip_text = str(o.hint)
		_buffs.add_child(pl)
	if Game.home.desk_staged():
		_buffs.add_child(UI.pill("Desk staged", UI.GREEN, 11))
	_buffs.visible = _buffs.get_child_count() > 0
	# Tutorial
	_tut.visible = Game.tutor.active()
	if _tut.visible:
		UI.clear(_tut_body)
		var pr := Game.tutor.progress()
		var st := Game.tutor.step()
		var head := UI.hbox(6)
		var ht := UI.title("%s  %d/%d" % [["FIRST DAY", "AUTOMATION", "THE LEDGER", "FAILURES", "REVIEW DAY"][clampi(Game.time.day, 0, 4)], pr.x, pr.y], 13, UI.ACCENT)
		ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(ht)
		var skip := UI.button("skip", Game.tutor.skip, "ghost", 11)
		head.add_child(skip)
		_tut_body.add_child(head)
		if not st.is_empty():
			_tut_body.add_child(UI.title(Game.comms.fmt(str(st.title)), 19))
			_tut_body.add_child(UI.wrap(Game.comms.fmt(str(st.text)), 13, Color("e6dcff")))
		if bool(Game.time.hold):
			_tut_body.add_child(UI.wrap("The clock is paused until you use something.", 12, UI.TEAL))
	# Stories on record: what you must not do while each one lasts.
	UI.clear(_claims)
	var live := Game.deception.live_claims()
	_claims.visible = not live.is_empty() and Game.time.phase == "work"
	for c in live:
		var d := Game.deception.describe(c)
		var cp := PanelContainer.new()
		var sbx := UI.sb(Color(UI.INK, 0.86), 12, 0, UI.PURPLE, 10, 7)
		sbx.border_width_left = 4
		cp.add_theme_stylebox_override("panel", sbx)
		cp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cv := UI.vbox(1)
		cp.add_child(cv)
		var ch := UI.hbox(6)
		var ct := UI.label("STORY: %s" % str(d.title), 12, UI.PURPLE, true)
		ct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ct.clip_text = true
		ch.add_child(ct)
		ch.add_child(UI.label("%s left" % Cfg.fmt_dur(float(d.left)), 11, UI.DIM, true))
		cv.add_child(ch)
		if not d.avoid.is_empty():
			cv.add_child(UI.wrap("Don't %s." % str(d.avoid[0]), 11, Color("ffb3bd")))
		_claims.add_child(cp)
	# Inbox
	UI.clear(_inbox)
	_inbox_rows.clear()
	if Game.time.phase != "work":
		return
	var ring := Game.comms.ringing()
	if not ring.is_empty() and not Game.comms.in_call():
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
	var list := Game.comms.pending()
	if not Game.presence.can_notice():
		if not list.is_empty():
			var p := UI.panel(Color(UI.INK, 0.7), 12, 10)
			p.add_child(UI.wrap("Something buzzed in the office. You can't tell what from here (no phone on you).", 12, UI.DIM))
			_inbox.add_child(p)
		return
	for i in mini(list.size(), 4):
		var pd: Dictionary = list[i]
		var c := UI.Clicky.new()
		c.setup(Color(UI.PANEL, 0.95), Color(Game.npcs.color(str(pd.from)), 0.8), 1, false, 12)
		var h := UI.hbox(9)
		h.add_child(UI.avatar(str(pd.from), 30))
		var col := UI.vbox(3)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top := UI.hbox(6)
		var nm := UI.label(Game.npcs.display_name(str(pd.from)), 13, UI.TEXT, true)
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
