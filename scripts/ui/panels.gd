class_name Panels
extends RefCounted
## Panels — shared settings, controls and how-to panels.


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
