class_name UI
extends RefCounted
## UI — palette, fonts, theme and small widget factories shared by every screen.
## Everything is built in code so the project has no hand-edited scene files.

# Game chrome (dark, cosy)
const BG := Color("1b182a")
const PANEL := Color("2b2542")
const PANEL2 := Color("3a3260")
const LINE := Color("4d4478")
const TEXT := Color("f6f2ff")
const DIM := Color("aaa3cc")
const ACCENT := Color("ffd166")
const GREEN := Color("5ad17a")
const RED := Color("ff5d73")
const BLUE := Color("4fb3ff")
const PURPLE := Color("b48cff")
const ORANGE := Color("ff8c5a")
const TEAL := Color("5ad1c8")
const INK := Color("1b182a")

# SynerOS (the in-fiction corporate desktop: light, sterile)
const OS_BG := Color("e9edf5")
const OS_PANEL := Color("ffffff")
const OS_SIDE := Color("243056")
const OS_LINE := Color("d3d9e6")
const OS_TEXT := Color("1d2440")
const OS_DIM := Color("6b7594")
const OS_ACCENT := Color("3b5bdb")
const OS_SOFT := Color("f3f5fa")

const STAT_COLORS := {"health": RED, "energy": ACCENT, "susp": ORANGE, "ill": BLUE}
const STAT_ICONS := {"health": "heart", "energy": "bolt", "susp": "eye", "ill": "spark"}

static var font_title: Font
static var font_body: Font
static var font_bold: Font
static var theme: Theme


static func _weight(base: Font, w: int) -> Font:
	var fv := FontVariation.new()
	fv.base_font = base
	var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	fv.variation_opentype = {tag: w}
	return fv


static func setup() -> Theme:
	if theme != null:
		return theme
	var fred: Font = load("res://assets/fonts/Fredoka.ttf")
	var inter: Font = load("res://assets/fonts/Inter.ttf")
	font_title = _weight(fred, 600)
	# Fredoka's kerning collapses pairs like "VIV" at display sizes.
	(font_title as FontVariation).opentype_features = {TextServerManager.get_primary_interface().name_to_tag("kern"): 0}
	font_body = _weight(inter, 500)
	font_bold = _weight(inter, 700)
	var t := Theme.new()
	t.default_font = font_body
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("line_spacing", "Label", 3)
	# Buttons
	t.set_font("font", "Button", font_title)
	t.set_font_size("font_size", "Button", 17)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	t.set_stylebox("normal", "Button", sb(PANEL2, 10, 0, Color.TRANSPARENT, 12, 8))
	t.set_stylebox("hover", "Button", sb(PANEL2.lightened(0.12), 10, 0, Color.TRANSPARENT, 12, 8))
	t.set_stylebox("pressed", "Button", sb(PANEL2.darkened(0.15), 10, 0, Color.TRANSPARENT, 12, 8))
	t.set_stylebox("disabled", "Button", sb(Color(PANEL2, 0.45), 10, 0, Color.TRANSPARENT, 12, 8))
	t.set_stylebox("focus", "Button", sb(Color.TRANSPARENT, 10, 2, Color(ACCENT, 0.8), 12, 8))
	# Panels
	t.set_stylebox("panel", "PanelContainer", sb(PANEL, 14, 0, Color.TRANSPARENT, 14, 14))
	t.set_stylebox("panel", "Panel", sb(PANEL, 14))
	# Progress bars
	t.set_stylebox("background", "ProgressBar", sb(Color(0, 0, 0, 0.35), 6))
	t.set_stylebox("fill", "ProgressBar", sb(ACCENT, 6))
	# Line edits
	t.set_stylebox("normal", "LineEdit", sb(Color(0, 0, 0, 0.3), 8, 1, LINE, 10, 8))
	t.set_stylebox("focus", "LineEdit", sb(Color(0, 0, 0, 0.3), 8, 2, ACCENT, 10, 8))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_font_size("font_size", "LineEdit", 18)
	# Scrollbars
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, sb(Color(0, 0, 0, 0.0), 4, 0, Color.TRANSPARENT, 3, 3))
		t.set_stylebox("grabber", bar, sb(Color(0.5, 0.5, 0.6, 0.45), 4))
		t.set_stylebox("grabber_highlight", bar, sb(Color(0.5, 0.5, 0.6, 0.7), 4))
		t.set_stylebox("grabber_pressed", bar, sb(Color(0.5, 0.5, 0.6, 0.9), 4))
	# Sliders
	t.set_stylebox("slider", "HSlider", sb(Color(0, 0, 0, 0.4), 4, 0, Color.TRANSPARENT, 0, 4))
	t.set_stylebox("grabber_area", "HSlider", sb(ACCENT, 4, 0, Color.TRANSPARENT, 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", sb(ACCENT, 4, 0, Color.TRANSPARENT, 0, 4))
	# Tooltips
	t.set_stylebox("panel", "TooltipPanel", sb(INK, 8, 1, LINE, 10, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 14)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("separation", "VBoxContainer", 8)
	theme = t
	return t


static func sb(color: Color, radius: int = 12, border: int = 0, border_color: Color = Color.TRANSPARENT, pad_x: int = 0, pad_y: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	s.anti_aliasing_size = 0.7
	return s


static func shadowed(s: StyleBoxFlat, size: int = 18, alpha: float = 0.35) -> StyleBoxFlat:
	s.shadow_color = Color(0, 0, 0, alpha)
	s.shadow_size = size
	s.shadow_offset = Vector2(0, 4)
	return s


static func label(text: String, size: int = 16, color: Color = TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font_bold)
	return l


static func title(text: String, size: int = 28, color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", font_title)
	return l


static func wrap(text: String, size: int = 15, color: Color = TEXT, min_w: float = 0.0) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if min_w > 0.0:
		l.custom_minimum_size.x = min_w
	return l


static func panel(color: Color = PANEL, radius: int = 14, pad: int = 14, border: int = 0, border_color: Color = LINE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(color, radius, border, border_color, pad, pad))
	return p


static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func spacer(min_size: float = 0.0) -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(min_size, min_size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func gap(w: float = 8.0, h: float = 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func margin(child: Control, l: int = 12, t: int = 12, r: int = 12, b: int = 12) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	if child != null:
		m.add_child(child)
	return m


static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func button(text: String, cb: Callable, kind: String = "ghost", size: int = 17) -> Button:
	## kind: primary | ghost | danger | good | os | os_ghost | os_danger
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var base := PANEL2
	var fg := TEXT
	var radius := 10
	match kind:
		"primary":
			base = ACCENT
			fg = INK
		"danger":
			base = Color("7a2b3d")
		"good":
			base = Color("2f7d4f")
		"os":
			base = OS_ACCENT
			fg = Color.WHITE
			radius = 7
		"os_ghost":
			base = Color("e2e7f3")
			fg = OS_TEXT
			radius = 7
		"os_danger":
			base = Color("ffe1e5")
			fg = Color("b3243a")
			radius = 7
	if kind != "ghost":
		b.add_theme_stylebox_override("normal", sb(base, radius, 0, Color.TRANSPARENT, 12, 7))
		b.add_theme_stylebox_override("hover", sb(base.lightened(0.1) if kind != "os_ghost" else base.darkened(0.05), radius, 0, Color.TRANSPARENT, 12, 7))
		b.add_theme_stylebox_override("pressed", sb(base.darkened(0.12), radius, 0, Color.TRANSPARENT, 12, 7))
		b.add_theme_stylebox_override("disabled", sb(Color(base, 0.35), radius, 0, Color.TRANSPARENT, 12, 7))
		b.add_theme_color_override("font_color", fg)
		b.add_theme_color_override("font_hover_color", fg)
		b.add_theme_color_override("font_pressed_color", fg)
		b.add_theme_color_override("font_focus_color", fg)
		b.add_theme_color_override("font_disabled_color", Color(fg, 0.45))
	if kind.begins_with("os"):
		b.add_theme_font_override("font", font_bold)
	if cb.is_valid():
		b.pressed.connect(func():
			Bus.sfx.emit("click")
			cb.call()
		)
	return b


static func pill(text: String, color: Color, size: int = 11, solid: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(color if solid else Color(color, 0.18), 20, 0 if solid else 1, Color(color, 0.7), 8, 2))
	var l := label(text, size, INK if solid else color, true)
	p.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func bar(color: Color, height: float = 12.0, max_value: float = 100.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = max_value
	b.custom_minimum_size = Vector2(60, height)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("fill", sb(color, int(height / 2.0)))
	b.add_theme_stylebox_override("background", sb(Color(0, 0, 0, 0.35), int(height / 2.0)))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func icon(name: String, size: float = 22.0, color: Color = TEXT) -> UIIcon:
	var i := UIIcon.new()
	i.icon = name
	i.tint = color
	i.custom_minimum_size = Vector2(size, size)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return i


static func avatar(who: String, size: float = 34.0) -> Control:
	## Round initial-badge for a person.
	var p := PanelContainer.new()
	var col := Game.npcs.color(who)
	p.add_theme_stylebox_override("panel", sb(col, int(size / 2.0)))
	p.custom_minimum_size = Vector2(size, size)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var nm := Game.npcs.display_name(who)
	var l := label("?" if Game.npcs.kind(who) == "stranger" else nm.substr(0, 1).to_upper(), int(size * 0.5), INK, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func choice(view: Dictionary, cb: Callable, light: bool = false, key_hint: String = "") -> Clicky:
	## One answer button: text, class badge (REAL WORK / FAKE WORK / ...), odds.
	var c := Clicky.new()
	var badge: Dictionary = view.badge
	var warn: bool = bool(badge.warn)
	var badge_color: Color = badge.color
	var base: Color = OS_SOFT if light else PANEL2
	var border: Color = Color(badge_color, 0.9) if warn else (OS_LINE if light else LINE)
	c.setup(base, border, 2 if warn else 1, light)
	c.disabled = not bool(view.ok)
	var row := hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if key_hint != "":
		row.add_child(pill(key_hint, OS_DIM if light else DIM, 12))
	var col := vbox(3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var text_color: Color = OS_TEXT if light else TEXT
	col.add_child(UI.wrap(str(view.text), 15, text_color))
	var meta := hbox(6)
	if str(badge.text) != "":
		# On the light SynerOS background the pastel class colours need more ink.
		meta.add_child(pill(str(badge.text), badge_color.darkened(0.38) if light and not warn else badge_color, 10, warn))
	if float(view.odds) >= 0.0:
		var pct := float(view.odds)
		var oc: Color = DeceptionManager.odds_color(pct)
		meta.add_child(pill("%s %d%%" % [DeceptionManager.odds_word(pct), int(round(pct))], oc.darkened(0.25) if light else oc, 10))
	if float(view.get("cost", 0.0)) > 0.0:
		meta.add_child(pill("-%d energy" % int(ceil(float(view.cost))), Color("9a7b12") if light else ACCENT, 10))
	if not bool(view.ok):
		meta.add_child(pill(str(view.why), Color("b3243a") if light else RED, 10))
	if meta.get_child_count() > 0:
		col.add_child(meta)
	else:
		meta.free()
	row.add_child(col)
	c.add_child(row)
	if cb.is_valid():
		c.pressed.connect(cb)
	return c


class Clicky:
	extends PanelContainer
	## A panel that behaves like a button but sizes to arbitrary content.
	signal pressed

	var disabled := false:
		set(v):
			disabled = v
			modulate.a = 0.5 if v else 1.0
			mouse_default_cursor_shape = Control.CURSOR_ARROW if v else Control.CURSOR_POINTING_HAND
	var _normal: StyleBoxFlat
	var _hover: StyleBoxFlat

	func setup(base: Color, border: Color, border_w: int = 1, light: bool = false, radius: int = 10) -> void:
		_normal = UI.sb(base, radius, border_w, border, 12, 9)
		_hover = UI.sb(base.darkened(0.06) if light else base.lightened(0.1), radius, border_w, border.lightened(0.2), 12, 9)
		add_theme_stylebox_override("panel", _normal)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func():
			if not disabled:
				add_theme_stylebox_override("panel", _hover)
		)
		mouse_exited.connect(func(): add_theme_stylebox_override("panel", _normal))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_READY:
			_pass_through(self)

	func _pass_through(n: Node) -> void:
		for ch in n.get_children():
			if ch is Control:
				(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			_pass_through(ch)

	func _gui_input(e: InputEvent) -> void:
		if disabled:
			return
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			accept_event()
			Bus.sfx.emit("click")
			pressed.emit()
