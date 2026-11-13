class_name Panels
extends RefCounted
## Panels — shared settings, controls and how-to panels.


static func settings_panel() -> Control:
	## Audio + display options. Shared by the main menu and the pause menu.
	var v := UI.vbox(10)
	# [label, key, min, max, step]
	for row in [["Master volume", "master", 0.0, 1.0, 0.05], ["Music", "music", 0.0, 1.0, 0.05], ["Sound effects", "sfx", 0.0, 1.0, 0.05], ["Ambience", "ambience", 0.0, 1.0, 0.05],
			["Mouse sensitivity", "look", 0.05, 1.0, 0.05], ["Field of view", "fov", 60.0, 100.0, 2.0],
			["Pixel size", "pixel", 1.0, 4.0, 1.0]]:
		var h := UI.hbox(12)
		var l := UI.label(str(row[0]), 15)
		l.custom_minimum_size = Vector2(150, 0)
		h.add_child(l)
		var s := HSlider.new()
		s.min_value = float(row[2])
		s.max_value = float(row[3])
		s.step = float(row[4])
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
	for row in [["Fullscreen", "fullscreen"], ["V-Sync", "vsync"], ["Head bob", "shake"], ["Contextual tips", "hints"]]:
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
		["Mouse", "Look around"], ["W A S D / arrows", "Walk"], ["Shift", "Hurry (costs more Energy)"],
		["E  or  left click", "Use what the crosshair is on / pick it up / stop an activity"],
		["Left click", "Eat, drink or use what you are holding"], ["Right click", "Put it down where you are looking"], ["Q", "Throw it"],
		["R", "Pocket what you are holding / take the next thing out"], ["1 - 8  or  wheel", "Take something out of a pocket"],
		["1 - 9", "Pick an option or an answer (when a list is open)"], ["Tab", "Phone: answer chats and calls from anywhere"],
		["Alt (hold)", "Free the mouse pointer"], ["Esc", "Leave the desk / close / pause"],
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
		["bolt", UI.GREEN, "Junk food", "It turns up around the flat every morning. Pick it up, carry it about, eat it a bite at a time for Energy. You can only eat so much at once, and the wrappers belong in a bin."],
		["coin", UI.ACCENT, "The town", "Your front door opens onto a street: three shops, a coffee cart, a park. Buy things by looking at them. While you are out your status says Away, and a colleague who sees you during work hours may tell your manager. Lunch and evenings are safe."],
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
