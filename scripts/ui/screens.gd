class_name Screens
extends RefCounted
## Namespace for the full-screen menus: main menu, new game, pause/settings,
## the end-of-day report and the end-of-run results.


static func settings_panel() -> Control:
	## Audio + display options. Shared by the main menu and the pause menu.
	var v := UI.vbox(10)
	for row in [["Master volume", "master"], ["Music", "music"], ["Sound effects", "sfx"], ["Ambience", "ambience"]]:
		var h := UI.hbox(12)
		var l := UI.label(str(row[0]), 15)
		l.custom_minimum_size = Vector2(150, 0)
		h.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = float(Prefs.get_v(str(row[1])))
		s.custom_minimum_size = Vector2(240, 22)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.focus_mode = Control.FOCUS_NONE
		var key: String = str(row[1])
		s.value_changed.connect(func(val: float):
			Prefs.set_v(key, val)
			if key == "sfx":
				Bus.sfx.emit("click")
		)
		h.add_child(s)
		v.add_child(h)
	for row in [["Fullscreen", "fullscreen"], ["V-Sync", "vsync"], ["Camera shake", "shake"], ["Contextual tips", "hints"]]:
		var h := UI.hbox(12)
		var l := UI.label(str(row[0]), 15)
		l.custom_minimum_size = Vector2(150, 0)
		h.add_child(l)
		var key: String = str(row[1])
		var b := UI.button("", Callable(), "ghost", 14)
		b.custom_minimum_size = Vector2(90, 0)
		var refresh := func():
			var on := bool(Prefs.get_v(key))
			b.text = "ON" if on else "OFF"
			b.add_theme_color_override("font_color", UI.GREEN if on else UI.DIM)
		refresh.call()
		b.pressed.connect(func():
			Prefs.set_v(key, not bool(Prefs.get_v(key)))
			Bus.sfx.emit("click")
			refresh.call()
		)
		h.add_child(b)
		v.add_child(h)
	return v


static func controls_panel() -> Control:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 7)
	for row in [
		["W A S D / arrows", "Walk"], ["Left click", "Walk there / use an object"], ["F  or  Space", "Use the highlighted object / stop an activity"],
		["1 - 9", "Pick an option or an answer"], ["Tab", "Phone: answer chats and calls from anywhere"], ["Q / E", "Rotate the camera"],
		["Mouse wheel", "Zoom"], ["Esc", "Leave the desk / close / pause"],
	]:
		g.add_child(UI.pill(str(row[0]), UI.ACCENT, 13))
		g.add_child(UI.label(str(row[1]), 14))
	return g


static func how_to_panel() -> Control:
	var v := UI.vbox(9)
	for row in [
		["heart", UI.RED, "Health", "Real work destroys it. So do meetings and long stretches at the desk. Leisure, food and sleep restore it. At 0 you burn out."],
		["bolt", UI.ACCENT, "Energy", "Every lie, fake update and excuse costs Energy. Eat, drink coffee, nap."],
		["eye", UI.ORANGE, "Suspicion", "Rises when you are visibly absent, ignore messages, miss meetings or get caught lying. At 100 you are fired."],
		["spark", UI.BLUE, "Productivity Illusion", "How busy you LOOK. Feed it with fake updates, fake reports and emoji. High Illusion makes Suspicion fade."],
		["moon", UI.TEAL, "Paid slacking", "Surviving is a pass. Your grade is the hours you spent on the sofa, the console and the bed between 09:00 and 17:00."],
	]:
		var h := UI.hbox(10)
		h.add_child(UI.icon(str(row[0]), 26, row[1]))
		var c := UI.vbox(0)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_child(UI.title(str(row[2]), 17, row[1]))
		c.add_child(UI.wrap(str(row[3]), 13, UI.DIM))
		h.add_child(c)
		v.add_child(h)
	v.add_child(UI.wrap("Anything tagged REAL WORK in red costs Health. On Professional Unemployed it ends the run. Everything else is fair game: fake it, delegate it, excuse it, automate it, or bury it in paperwork.", 14, UI.TEXT))
	return v


# ---------------------------------------------------------------------------
# Main menu
# ---------------------------------------------------------------------------

class MainMenu:
	extends Control
	signal new_game()
	signal continue_game(slot: String)
	signal quit()

	var _buttons: VBoxContainer
	var _side: PanelContainer
	var _side_body: VBoxContainer
	var _mode := ""

	func _init() -> void:
		UI.full(self)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		var shade := TextureRect.new()
		var grad := Gradient.new()
		grad.set_color(0, Color(0.07, 0.06, 0.13, 0.94))
		grad.set_color(1, Color(0.07, 0.06, 0.13, 0.0))
		grad.add_point(0.45, Color(0.07, 0.06, 0.13, 0.72))
		var gt := GradientTexture2D.new()
		gt.gradient = grad
		gt.width = 256
		gt.height = 4
		shade.texture = gt
		shade.stretch_mode = TextureRect.STRETCH_SCALE
		UI.full(shade)
		shade.anchor_right = 0.62
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
		var left := UI.vbox(0)
		left.position = Vector2(84, 88)
		left.custom_minimum_size = Vector2(520, 0)
		add_child(left)
		left.add_child(UI.pill("SYNERCORP  -  PEOPLE & CULTURE & COMPLIANCE", UI.ACCENT, 12, true))
		left.add_child(UI.gap(1, 10))
		var t1 := UI.title("REMOTE WORK", 82)
		t1.add_theme_constant_override("line_spacing", -18)
		t1.add_theme_constant_override("outline_size", 14)
		t1.add_theme_color_override("font_outline_color", UI.INK)
		left.add_child(t1)
		var t2 := UI.title("SIMULATOR", 82, UI.ACCENT)
		t2.custom_minimum_size = Vector2(0, 0)
		t2.add_theme_constant_override("outline_size", 14)
		t2.add_theme_color_override("font_outline_color", UI.INK)
		left.add_child(t2)
		var tag := UI.title("Get paid. Do nothing. Don't get caught.", 24, Color("e6dcff"))
		tag.add_theme_constant_override("outline_size", 8)
		tag.add_theme_color_override("font_outline_color", UI.INK)
		left.add_child(tag)
		left.add_child(UI.gap(1, 30))
		_buttons = UI.vbox(9)
		_buttons.custom_minimum_size = Vector2(330, 0)
		_buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		left.add_child(_buttons)
		_side = PanelContainer.new()
		_side.add_theme_stylebox_override("panel", UI.shadowed(UI.sb(Color(UI.PANEL, 0.96), 18, 0, Color.TRANSPARENT, 22, 20), 24, 0.4))
		_side.position = Vector2(470, 390)
		_side.custom_minimum_size = Vector2(560, 0)
		_side.visible = false
		add_child(_side)
		_side_body = UI.vbox(10)
		_side.add_child(_side_body)
		var ver := UI.label("v%s  -  vertical slice" % Cfg.VERSION, 12, Color(1, 1, 1, 0.55))
		ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		ver.anchor_top = 1.0
		ver.anchor_bottom = 1.0
		ver.offset_left = 20
		ver.offset_top = -30
		add_child(ver)

	func open() -> void:
		visible = true
		_mode = ""
		_side.visible = false
		UI.clear(_buttons)
		var latest := SaveSys.latest()
		if latest != "":
			var cb := _big("Continue", func(): continue_game.emit(latest), true)
			cb.tooltip_text = SaveSys.describe(SaveSys.meta(latest))
			_buttons.add_child(cb)
		_buttons.add_child(_big("New Game", func(): new_game.emit(), latest == ""))
		if latest != "":
			_buttons.add_child(_big("Load Game", _toggle.bind("load")))
		_buttons.add_child(_big("How to Play", _toggle.bind("how")))
		_buttons.add_child(_big("Settings", _toggle.bind("settings")))
		_buttons.add_child(_big("Quit", func(): quit.emit()))

	func _big(text: String, cb: Callable, primary: bool = false) -> Button:
		var b := UI.button(text, cb, "primary" if primary else "ghost", 22)
		b.custom_minimum_size = Vector2(330, 52)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not primary:
			b.add_theme_stylebox_override("normal", UI.sb(Color(UI.PANEL, 0.92), 12, 0, Color.TRANSPARENT, 18, 8))
			b.add_theme_stylebox_override("hover", UI.sb(Color(UI.PANEL2, 0.98), 12, 0, Color.TRANSPARENT, 18, 8))
		else:
			b.add_theme_stylebox_override("normal", UI.sb(UI.ACCENT, 12, 0, Color.TRANSPARENT, 18, 8))
			b.add_theme_stylebox_override("hover", UI.sb(UI.ACCENT.lightened(0.15), 12, 0, Color.TRANSPARENT, 18, 8))
		return b

	func _toggle(mode: String) -> void:
		if _mode == mode:
			_mode = ""
			_side.visible = false
			return
		_mode = mode
		_side.visible = true
		UI.clear(_side_body)
		match mode:
			"settings":
				_side_body.add_child(UI.title("Settings", 26))
				_side_body.add_child(Screens.settings_panel())
			"how":
				_side_body.add_child(UI.title("How to Play", 26))
				_side_body.add_child(Screens.how_to_panel())
				_side_body.add_child(UI.gap(1, 4))
				_side_body.add_child(Screens.controls_panel())
			"load":
				_side_body.add_child(UI.title("Load Game", 26))
				for e in SaveSys.list():
					var c := UI.Clicky.new()
					c.setup(UI.PANEL2, UI.LINE, 1, false)
					var v := UI.vbox(1)
					v.add_child(UI.title(str(e.name), 16))
					v.add_child(UI.label(SaveSys.describe(e.meta), 12, UI.DIM))
					c.add_child(v)
					var slot: String = str(e.slot)
					c.pressed.connect(func(): continue_game.emit(slot))
					_side_body.add_child(c)
		_side.reset_size()
		_side.position = Vector2(470, minf(390.0, size.y - _side.size.y - 30.0))


# ---------------------------------------------------------------------------
# New game: difficulty + character
# ---------------------------------------------------------------------------

class NewGame:
	extends Control
	signal start(difficulty: String, look: Dictionary, tutorial: bool)
	signal back()
	signal look_changed(look: Dictionary)

	var diff := "survivor"
	var look: Dictionary = Character.DEFAULT_LOOK.duplicate()
	var tutorial := true
	var _cards: Dictionary = {}
	var _name: LineEdit
	var _swatches: Dictionary = {}
	var _tut_btn: Button
	var _desc: Label

	func _init() -> void:
		UI.full(self)
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shade := ColorRect.new()
		shade.color = Color(0.07, 0.06, 0.13, 0.5)
		UI.full(shade)
		shade.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(shade)
		var root := UI.hbox(18)
		UI.full(root)
		root.offset_left = 40
		root.offset_right = -40
		root.offset_top = 34
		root.offset_bottom = -34
		add_child(root)
		# Difficulty
		var dp := PanelContainer.new()
		dp.add_theme_stylebox_override("panel", UI.shadowed(UI.sb(Color(UI.PANEL, 0.96), 18, 0, Color.TRANSPARENT, 20, 18), 24, 0.4))
		dp.custom_minimum_size = Vector2(560, 0)
		root.add_child(dp)
		var dv := UI.vbox(9)
		dp.add_child(dv)
		dv.add_child(UI.title("Choose your work ethic", 28))
		for id in Cfg.DIFF_ORDER:
			var d: Dictionary = Cfg.DIFFS[id]
			var c := UI.Clicky.new()
			c.setup(UI.PANEL2, UI.LINE, 2, false, 12)
			var v := UI.vbox(3)
			var h := UI.hbox(8)
			h.add_child(UI.title(str(d.name), 20, d.color))
			h.add_child(UI.pill(str(d.tag), d.color, 10, true))
			h.add_child(UI.spacer())
			h.add_child(UI.label("score x%.1f" % float(d.score), 12, UI.DIM, true))
			v.add_child(h)
			v.add_child(UI.wrap(str(d.desc), 13, UI.DIM))
			c.add_child(v)
			c.pressed.connect(_pick_diff.bind(str(id)))
			dv.add_child(c)
			_cards[id] = c
		dv.add_child(UI.spacer())
		var foot := UI.hbox(10)
		foot.add_child(UI.button("Back", func(): back.emit(), "ghost", 18))
		foot.add_child(UI.spacer())
		dv.add_child(foot)
		# Spacer where the 3D character shows through
		var mid := UI.spacer()
		root.add_child(mid)
		# Character
		var cp := PanelContainer.new()
		cp.add_theme_stylebox_override("panel", UI.shadowed(UI.sb(Color(UI.PANEL, 0.96), 18, 0, Color.TRANSPARENT, 20, 18), 24, 0.4))
		cp.custom_minimum_size = Vector2(470, 0)
		root.add_child(cp)
		var cv := UI.vbox(9)
		cp.add_child(cv)
		cv.add_child(UI.title("Employee file", 28))
		cv.add_child(UI.label("Name", 13, UI.DIM, true))
		_name = LineEdit.new()
		_name.max_length = 14
		_name.text = str(look.name)
		_name.text_changed.connect(func(t: String):
			look.name = t.strip_edges() if t.strip_edges() != "" else "Alex"
		)
		cv.add_child(_name)
		_swatch_row(cv, "Skin", "skin", Character.SKINS)
		_style_row(cv)
		_swatch_row(cv, "Hair colour", "hair_color", Character.HAIR_COLORS)
		_swatch_row(cv, "Hoodie", "shirt", Character.SHIRTS)
		_swatch_row(cv, "Trousers", "pants", Character.PANTS)
		var gh := UI.hbox(10)
		gh.add_child(UI.label("Glasses", 13, UI.DIM, true))
		var gb := UI.button("OFF", Callable(), "ghost", 13)
		gb.pressed.connect(func():
			look.glasses = not bool(look.glasses)
			gb.text = "ON" if bool(look.glasses) else "OFF"
			Bus.sfx.emit("click")
			look_changed.emit(look)
		)
		gh.add_child(gb)
		gh.add_child(UI.spacer())
		gh.add_child(UI.button("Randomise", _randomise, "ghost", 13))
		cv.add_child(gh)
		cv.add_child(UI.spacer())
		var th := UI.hbox(10)
		th.add_child(UI.label("Guided first day", 14))
		_tut_btn = UI.button("ON", Callable(), "ghost", 14)
		_tut_btn.pressed.connect(func():
			tutorial = not tutorial
			_tut_btn.text = "ON" if tutorial else "OFF"
			Bus.sfx.emit("click")
		)
		th.add_child(_tut_btn)
		cv.add_child(th)
		var go := UI.button("Clock in", func():
			start.emit(diff, look.duplicate(true), tutorial)
		, "primary", 26)
		go.custom_minimum_size = Vector2(0, 62)
		cv.add_child(go)

	func open() -> void:
		visible = true
		_pick_diff(diff)
		look_changed.emit(look)

	func _pick_diff(id: String) -> void:
		diff = id
		for k in _cards:
			var c: UI.Clicky = _cards[k]
			var on: bool = k == id
			var col: Color = Cfg.DIFFS[k].color
			c._normal = UI.sb(UI.PANEL2.lightened(0.06) if on else UI.PANEL2, 12, 3 if on else 1, col if on else UI.LINE, 12, 9)
			c._hover = c._normal
			c.add_theme_stylebox_override("panel", c._normal)

	func _swatch_row(parent: Control, label_text: String, key: String, colors: Array) -> void:
		parent.add_child(UI.label(label_text, 13, UI.DIM, true))
		var h := UI.hbox(6)
		parent.add_child(h)
		var list: Array = []
		for i in colors.size():
			var b := UI.Clicky.new()
			b.custom_minimum_size = Vector2(38, 30)
			b.pressed.connect(func():
				look[key] = i
				_refresh_swatches()
				look_changed.emit(look)
			)
			h.add_child(b)
			list.append(b)
		_swatches[key] = {"buttons": list, "colors": colors}
		_refresh_swatches()

	func _refresh_swatches() -> void:
		for key in _swatches:
			var e: Dictionary = _swatches[key]
			for i in e.buttons.size():
				var b: UI.Clicky = e.buttons[i]
				var on: bool = int(look[key]) == i
				var sbx := UI.sb(e.colors[i], 8, 3 if on else 0, Color.WHITE)
				b._normal = sbx
				b._hover = UI.sb((e.colors[i] as Color).lightened(0.15), 8, 3 if on else 1, Color.WHITE)
				b.add_theme_stylebox_override("panel", sbx)

	func _style_row(parent: Control) -> void:
		parent.add_child(UI.label("Hair style", 13, UI.DIM, true))
		var h := UI.hbox(8)
		parent.add_child(h)
		var name_l := UI.title(Character.HAIR_STYLES[int(look.hair)], 16)
		name_l.custom_minimum_size = Vector2(110, 0)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var step := func(d: int):
			look.hair = posmod(int(look.hair) + d, Character.HAIR_STYLES.size())
			name_l.text = Character.HAIR_STYLES[int(look.hair)]
			look_changed.emit(look)
		h.add_child(UI.button("<", step.bind(-1), "ghost", 16))
		h.add_child(name_l)
		h.add_child(UI.button(">", step.bind(1), "ghost", 16))

	func _randomise() -> void:
		look.skin = randi() % Character.SKINS.size()
		look.hair = randi() % Character.HAIR_STYLES.size()
		look.hair_color = randi() % Character.HAIR_COLORS.size()
		look.shirt = randi() % Character.SHIRTS.size()
		look.pants = randi() % Character.PANTS.size()
		look.glasses = randf() < 0.4
		_refresh_swatches()
		look_changed.emit(look)


# ---------------------------------------------------------------------------
# Pause
# ---------------------------------------------------------------------------

class Pause:
	extends Overlays.Dim
	signal resume()
	signal to_menu()
	signal load_slot(slot: String)

	var _body: VBoxContainer
	var _mode := "main"

	func _init() -> void:
		super(0.72)
		visible = false
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.shadowed(UI.sb(UI.PANEL, 20, 0, Color.TRANSPARENT, 26, 22), 30, 0.5))
		p.custom_minimum_size = Vector2(560, 0)
		center(p)
		_body = UI.vbox(9)
		p.add_child(_body)

	func open() -> void:
		visible = true
		_mode = "main"
		_build()

	func back() -> bool:
		## Esc: returns true if it handled the key (went up a level).
		if _mode != "main":
			_mode = "main"
			_build()
			return true
		return false

	func _nav(mode: String) -> void:
		_mode = mode
		_build()

	func _build() -> void:
		UI.clear(_body)
		match _mode:
			"main":
				_body.add_child(UI.title("Paused", 34))
				_body.add_child(UI.label("%s, %s  -  %s" % [Game.day_name(), Cfg.fmt_time(fposmod(float(Game.s.t), 1440.0)), str(Game.diff().name)], 14, UI.DIM))
				_body.add_child(UI.gap(1, 6))
				_body.add_child(_big("Resume", func(): resume.emit(), true))
				var sv := _big("Save Game", _nav.bind("save"))
				sv.disabled = not SaveSys.can_save()
				_body.add_child(sv)
				var ld := _big("Load Game", _nav.bind("load"))
				ld.disabled = SaveSys.list().is_empty()
				_body.add_child(ld)
				_body.add_child(_big("Settings", _nav.bind("settings")))
				_body.add_child(_big("How to Play", _nav.bind("how")))
				_body.add_child(_big("Quit to Main Menu", func(): to_menu.emit()))
			"settings":
				_body.add_child(UI.title("Settings", 28))
				_body.add_child(Screens.settings_panel())
				_body.add_child(_big("Back", _nav.bind("main")))
			"how":
				_body.add_child(UI.title("How to Play", 28))
				_body.add_child(Screens.how_to_panel())
				_body.add_child(Screens.controls_panel())
				_body.add_child(_big("Back", _nav.bind("main")))
			"save", "load":
				var saving := _mode == "save"
				_body.add_child(UI.title("Save Game" if saving else "Load Game", 28))
				for slot in SaveSys.SLOTS:
					if saving and slot == "auto":
						continue
					var m := SaveSys.meta(slot)
					if not saving and m.is_empty():
						continue
					var c := UI.Clicky.new()
					c.setup(UI.PANEL2, UI.LINE, 1, false)
					var v := UI.vbox(1)
					v.add_child(UI.title(str(SaveSys.SLOT_NAMES[slot]), 17))
					v.add_child(UI.label(SaveSys.describe(m), 12, UI.DIM))
					c.add_child(v)
					c.pressed.connect(func():
						if saving:
							if SaveSys.save(slot):
								Bus.toast.emit("Saved to %s." % str(SaveSys.SLOT_NAMES[slot]), "good")
							_nav("main")
						else:
							load_slot.emit(slot)
					)
					_body.add_child(c)
				_body.add_child(_big("Back", _nav.bind("main")))

	func _big(text: String, cb: Callable, primary: bool = false) -> Button:
		var b := UI.button(text, cb, "primary" if primary else "ghost", 19)
		b.custom_minimum_size = Vector2(0, 46)
		return b


# ---------------------------------------------------------------------------
# End-of-day report
# ---------------------------------------------------------------------------

class Report:
	extends Overlays.Dim
	signal done()

	var _body: VBoxContainer

	func _init() -> void:
		super(0.8)
		visible = false
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.shadowed(UI.sb(Color("fbf6ea"), 14, 0, Color.TRANSPARENT, 34, 28), 34, 0.55))
		p.custom_minimum_size = Vector2(760, 0)
		center(p)
		_body = UI.vbox(8)
		p.add_child(_body)

	func _row(label_text: String, value: String, color: Color = UI.INK, note: String = "") -> Control:
		var h := UI.hbox(10)
		var l := UI.label(label_text, 16, Color("4a4270"))
		l.custom_minimum_size = Vector2(290, 0)
		h.add_child(l)
		var v := UI.title(value, 19, color)
		v.custom_minimum_size = Vector2(110, 0)
		h.add_child(v)
		if note != "":
			var n := UI.wrap(note, 12, Color("8a86a8"))
			h.add_child(n)
		h.modulate.a = 0.0
		return h

	func show_report(rep: Dictionary) -> void:
		visible = true
		UI.clear(_body)
		var ink := UI.INK
		var head := UI.hbox(10)
		var hv := UI.vbox(0)
		hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hv.add_child(UI.label("SYNERCORP  -  DAILY PERFORMANCE SUMMARY", 12, Color("8a86a8"), true))
		hv.add_child(UI.title("%s" % Cfg.DAYS[int(rep.day)], 40, ink))
		head.add_child(hv)
		var stamp := UI.panel(Color.TRANSPARENT, 8, 10, 3, Color("d6455b"))
		var st := UI.title(str(rep.title).to_upper(), 15, Color("d6455b"))
		st.custom_minimum_size = Vector2(190, 0)
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stamp.add_child(st)
		stamp.rotation_degrees = -4.0
		head.add_child(stamp)
		_body.add_child(head)
		var sep := ColorRect.new()
		sep.color = Color("d9d2c0")
		sep.custom_minimum_size = Vector2(0, 2)
		_body.add_child(sep)
		var worked := int(rep.worked_min)
		var rows: Array = [
			_row("Hours employed", "%.1f h" % float(rep.hours_employed), ink),
			_row("Minutes actually worked", "%d min" % worked, Color("1f8f4a") if worked == 0 else Color("d6455b"), "Flawless." if worked == 0 else "Every one of them hurt."),
			_row("Time spent pretending to work", Cfg.fmt_dur(float(rep.pretend_min)), ink, "Sitting at the desk, or in meetings."),
			_row("Paid time spent slacking", Cfg.fmt_dur(float(rep.get("slack_min", 0))), Color("1f8f4a") if int(rep.get("slack_min", 0)) >= 90 else ink, "Sofa, TV, console, naps and snacks on company time."),
			_row("Excuses used", str(int(rep.excuses)), ink),
			_row("Meetings avoided", "%d of %d" % [int(rep.meetings_avoided), int(rep.meetings_avoided) + int(rep.meetings_attended) + int(rep.meetings_missed)], ink, "%d missed without a story" % int(rep.meetings_missed) if int(rep.meetings_missed) > 0 else ""),
			_row("Suspicion generated", "+%d" % int(round(float(rep.susp_gained))), Color("d6455b") if float(rep.susp_gained) >= 30.0 else ink, "and -%d talked back down" % int(round(float(rep.susp_lost)))),
			_row("Health remaining", "%d%%" % int(round(float(rep.health))), Color("d6455b") if float(rep.health) < 40.0 else ink),
			_row("Automation efficiency", "n/a" if float(rep.auto_eff) < 0.0 else "%d%%" % int(round(float(rep.auto_eff))), ink, "no gadgets ran" if float(rep.auto_eff) < 0.0 else "%d gadget cycles" % int(rep.auto_runs)),
		]
		for r in rows:
			_body.add_child(r)
		var sep2 := ColorRect.new()
		sep2.color = Color("d9d2c0")
		sep2.custom_minimum_size = Vector2(0, 2)
		_body.add_child(sep2)
		var pay := UI.vbox(2)
		for line in rep.salary_lines:
			var ph := UI.hbox(10)
			var pl := UI.label(str(line[0]), 14, Color("4a4270"))
			pl.custom_minimum_size = Vector2(290, 0)
			ph.add_child(pl)
			ph.add_child(UI.label("%s$%d" % ["+" if int(line[1]) >= 0 else "-", absi(int(line[1]))], 15, Color("1f8f4a") if int(line[1]) >= 0 else Color("d6455b"), true))
			pay.add_child(ph)
		_body.add_child(pay)
		var total := _row("Salary earned today", "$%d" % int(rep.salary), Color("1f8f4a"))
		_body.add_child(total)
		rows.append(total)
		var verdict := UI.wrap(str(rep.verdict), 15, Color("4a4270"))
		_body.add_child(verdict)
		_body.add_child(UI.gap(1, 4))
		var last: bool = int(rep.day) >= 4
		var b := UI.button("See how the week went" if last else "Clock out", func():
			visible = false
			done.emit()
		, "primary", 22)
		b.custom_minimum_size = Vector2(0, 54)
		_body.add_child(b)
		var tw := create_tween()
		for r in rows:
			tw.tween_property(r, "modulate:a", 1.0, 0.11)
			tw.tween_callback(func(): Bus.sfx.emit("tick"))
		Bus.sfx.emit("payday")


# ---------------------------------------------------------------------------
# End-of-run results
# ---------------------------------------------------------------------------

class Results:
	extends Overlays.Dim
	signal again()
	signal to_menu()

	const TEXT := {
		"win": ["YOU SURVIVED THE WEEK", "Five days. Forty paid hours. Management still believes you work here.", "5ad17a"],
		"fired": ["YOU'RE FIRED", "\"We've decided to go in a different direction. The direction is: without you.\"", "ff5d73"],
		"burnout": ["BURNOUT", "You worked. It broke you. The doctor's note this time is real.", "ff8c5a"],
		"worked": ["DISQUALIFIED: YOU DID WORK", "A Professional Unemployed never, ever does the job.", "ff5d73"],
	}

	var _body: VBoxContainer

	func _init() -> void:
		super(0.86)
		visible = false
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.shadowed(UI.sb(UI.PANEL, 22, 0, Color.TRANSPARENT, 34, 28), 34, 0.55))
		p.custom_minimum_size = Vector2(900, 0)
		center(p)
		_body = UI.vbox(10)
		p.add_child(_body)

	func _stat(label_text: String, value: String, color: Color = UI.TEXT) -> Control:
		var p := UI.panel(UI.PANEL2, 12, 12)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UI.vbox(0)
		var t := UI.title(value, 26, color)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var l := UI.label(label_text, 12, UI.DIM, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		p.add_child(v)
		return p

	func show_result(res: Dictionary) -> void:
		visible = true
		UI.clear(_body)
		var kind: String = str(res.kind)
		var info: Array = TEXT.get(kind, TEXT["fired"])
		var col := Color(str(info[2]))
		var wk: Dictionary = res.week
		var head := UI.hbox(18)
		_body.add_child(head)
		var hv := UI.vbox(2)
		hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hv.add_child(UI.pill("%s  -  %s%s" % [str(Cfg.diff(str(res.diff)).name).to_upper(), Cfg.DAYS[clampi(int(res.day), 0, 4)], "" if bool(res.won) else " %s" % Cfg.fmt_time(fposmod(float(res.time), 1440.0))], col, 12, true))
		hv.add_child(UI.title(str(info[0]), 46, col))
		var sub: String = str(info[1])
		if kind == "worked" and str(res.action) != "":
			sub += "\nYour mistake: \"%s\"." % str(res.action)
		elif not bool(res.won) and str(res.reason) != "":
			sub += "\nThe final straw: %s." % str(res.reason)
		hv.add_child(UI.wrap(sub, 16, Color("e6dcff")))
		head.add_child(hv)
		var gp := UI.panel(Color(col, 0.16), 20, 14, 3, col)
		gp.custom_minimum_size = Vector2(130, 130)
		var gv := UI.vbox(0)
		gv.alignment = BoxContainer.ALIGNMENT_CENTER
		var gl := UI.title(str(res.grade), 74, col)
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gv.add_child(gl)
		var gs := UI.label("GRADE", 12, UI.DIM, true)
		gs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gv.add_child(gs)
		gp.add_child(gv)
		head.add_child(gp)
		var worked := int(wk.worked_min)
		var g1 := UI.hbox(8)
		g1.add_child(_stat("FINAL SCORE", str(int(res.score)), UI.ACCENT))
		g1.add_child(_stat("MINUTES ACTUALLY WORKED", str(worked), UI.GREEN if worked == 0 else UI.RED))
		g1.add_child(_stat("SALARY COLLECTED", "$%d" % int(wk.salary), UI.ACCENT))
		g1.add_child(_stat("PAID HOURS SLACKED", Cfg.fmt_dur(float(wk.get("slack_min", 0))), UI.TEAL))
		_body.add_child(g1)
		var g2 := UI.hbox(8)
		g2.add_child(_stat("EXCUSES", "%d (%d rejected)" % [int(wk.excuses), int(wk.excuses_failed)]))
		g2.add_child(_stat("MEETINGS AVOIDED", str(int(wk.meetings_avoided))))
		g2.add_child(_stat("TICKETS FAKED / DELEGATED", "%d / %d" % [int(wk.tasks_faked), int(wk.tasks_delegated)]))
		g2.add_child(_stat("CONTRADICTIONS CAUGHT", str(int(wk.contradictions)), UI.RED if int(wk.contradictions) > 0 else UI.TEXT))
		_body.add_child(g2)
		if bool(res.won):
			var line := "Not one minute of real work." if worked == 0 else "You survived, but you WORKED %d minutes to do it. We don't talk about that." % worked
			var slack := int(wk.get("slack_min", 0))
			if worked == 0 and slack < Cfg.SLACK_S:
				line += " Slack %s on company time for an %s." % [Cfg.fmt_dur(float(Cfg.SLACK_A if slack < Cfg.SLACK_A else Cfg.SLACK_S)), "A" if slack < Cfg.SLACK_A else "S"]
			elif worked == 0:
				line += " And over a third of your paid hours on the sofa. Perfection."
			var review: String = str(Game.s.get("flags", {}).get("review", ""))
			if review == "exceeds":
				line += " Your review said EXCEEDS EXPECTATIONS."
			elif review == "pip":
				line += " You are on a Performance Improvement Plan, which you will also ignore."
			_body.add_child(UI.wrap(line, 15, UI.GREEN if worked == 0 else UI.ACCENT))
		# Day strip
		var days := UI.hbox(8)
		for rep in res.reports:
			var dp := UI.panel(Color(0, 0, 0, 0.25), 10, 10)
			dp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var dv := UI.vbox(1)
			dv.add_child(UI.title(Cfg.DAYS_SHORT[int(rep.day)], 15, UI.ACCENT))
			dv.add_child(UI.wrap(str(rep.title), 12, UI.TEXT))
			dv.add_child(UI.label("$%d  -  %d%% susp" % [int(rep.salary), int(round(float(rep.get("susp_end", rep.susp))))], 11, UI.DIM))
			dp.add_child(dv)
			days.add_child(dp)
		if not res.reports.is_empty():
			_body.add_child(days)
		_body.add_child(UI.gap(1, 4))
		var foot := UI.hbox(10)
		var b1 := UI.button("Main Menu", func(): to_menu.emit(), "ghost", 20)
		b1.custom_minimum_size = Vector2(220, 52)
		foot.add_child(b1)
		foot.add_child(UI.spacer())
		var b2 := UI.button("Try another week", func(): again.emit(), "primary", 20)
		b2.custom_minimum_size = Vector2(280, 52)
		foot.add_child(b2)
		_body.add_child(foot)
		Bus.sfx.emit("win" if bool(res.won) else "fired")
