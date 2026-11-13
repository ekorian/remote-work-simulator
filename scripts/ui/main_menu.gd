class_name MainMenu
extends Control

signal new_game()
signal continue_game(slot: String)
signal quit()

var _buttons: VBoxContainer
var _side: PanelContainer
var _side_body: VBoxContainer
var _mode := ""

func _ready() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.055, 0.065, 0.07, 0.94))
	grad.set_color(1, Color(0.055, 0.065, 0.07, 0.0))
	grad.add_point(0.45, Color(0.055, 0.065, 0.07, 0.72))
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
	var tag := UI.title("Get paid. Do nothing. Don't get caught.", 24, UI.TEXT)
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
	var latest := Game.saves.latest()
	if latest != "":
		var cb := _big("Continue", func(): continue_game.emit(latest), true)
		cb.tooltip_text = Game.saves.describe(Game.saves.meta(latest))
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
			_side_body.add_child(Panels.settings_panel())
		"how":
			_side_body.add_child(UI.title("How to Play", 26))
			_side_body.add_child(Panels.how_to_panel())
			_side_body.add_child(UI.gap(1, 4))
			_side_body.add_child(Panels.controls_panel())
		"load":
			_side_body.add_child(UI.title("Load Game", 26))
			for e in Game.saves.list():
				var c := UI.Clicky.new()
				c.setup(UI.PANEL2, UI.LINE, 1, false)
				var v := UI.vbox(1)
				v.add_child(UI.title(str(e.name), 16))
				v.add_child(UI.label(Game.saves.describe(e.meta), 12, UI.DIM))
				c.add_child(v)
				var slot: String = str(e.slot)
				c.pressed.connect(func(): continue_game.emit(slot))
				_side_body.add_child(c)
	_side.reset_size()
	_side.position = Vector2(470, minf(390.0, size.y - _side.size.y - 30.0))


# ---------------------------------------------------------------------------
# New game: difficulty + character
# ---------------------------------------------------------------------------
