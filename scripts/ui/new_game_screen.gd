class_name NewGameScreen
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
var _cyclers: Dictionary = {}
var _tut_btn: Button
var _desc: Label

func _ready() -> void:
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
		var d: Dictionary = Db.difficulties[id]
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
	_cycle_row(cv, "Hair style", "hair", Character.HAIR_STYLES)
	_swatch_row(cv, "Hair colour", "hair_color", Character.HAIR_COLORS)
	_swatch_row(cv, "Hoodie", "shirt", Character.SHIRTS)
	_swatch_row(cv, "Trousers", "pants", Character.PANTS)
	_cycle_row(cv, "Accessory", "accessory", Character.ACCESSORIES)
	var gh := UI.hbox(10)
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
		var col: Color = Db.difficulties[k].color
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

func _cycle_row(parent: Control, label_text: String, key: String, names: Array) -> void:
	## A "< name >" picker for options that are shapes rather than colours.
	parent.add_child(UI.label(label_text, 13, UI.DIM, true))
	var h := UI.hbox(8)
	parent.add_child(h)
	var name_l := UI.title(str(names[int(look[key]) % names.size()]), 16)
	name_l.custom_minimum_size = Vector2(130, 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var step := func(d: int):
		look[key] = posmod(int(look[key]) + d, names.size())
		name_l.text = str(names[int(look[key])])
		Bus.sfx.emit("click")
		look_changed.emit(look)
	h.add_child(UI.button("<", step.bind(-1), "ghost", 16))
	h.add_child(name_l)
	h.add_child(UI.button(">", step.bind(1), "ghost", 16))
	_cyclers[key] = {"label": name_l, "names": names}


func _randomise() -> void:
	look.skin = randi() % Character.SKINS.size()
	look.hair = randi() % Character.HAIR_STYLES.size()
	look.hair_color = randi() % Character.HAIR_COLORS.size()
	look.shirt = randi() % Character.SHIRTS.size()
	look.pants = randi() % Character.PANTS.size()
	look.accessory = randi() % Character.ACCESSORIES.size()
	_refresh_swatches()
	for key in _cyclers:
		(_cyclers[key].label as Label).text = str(_cyclers[key].names[int(look[key])])
	look_changed.emit(look)


# ---------------------------------------------------------------------------
# Pause
# ---------------------------------------------------------------------------
