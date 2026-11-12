class_name ChoiceList
extends VBoxContainer
## The answer buttons for a chat prompt, a mail or a call question — including
## the excuse picker and the "are you sure you want to WORK?" confirmation.
## Every button carries the class badge supplied by Actions.badge().

signal chosen(index: int, excuse_id: String)

var light := false                 ## SynerOS (light) or game chrome (dark)
var context := "chat"              ## chat | video | phone
var hotkeys := false               ## number keys pick answers
var _choices: Array = []
var _picking := -1                 ## index of the excuse choice being expanded
var _armed := -1                   ## index of a lethal choice awaiting confirmation


func _init() -> void:
	add_theme_constant_override("separation", 7)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func show_choices(list: Array, ctx: String = "chat") -> void:
	_choices = list
	context = ctx
	_picking = -1
	_armed = -1
	_build()


func refresh() -> void:
	_build()


func _dim() -> Color:
	return UI.OS_DIM if light else UI.DIM


func _build() -> void:
	UI.clear(self)
	if _picking >= 0:
		_build_excuses()
		return
	for i in _choices.size():
		var c: Dictionary = _choices[i]
		var view := Corp.choice_view(c, context)
		if i == _armed:
			view.text = "This is REAL WORK. It ends your run on this difficulty. Click again to throw it all away."
		add_child(UI.choice(view, _pick.bind(i), light, str(i + 1) if hotkeys else ""))


func _build_excuses() -> void:
	var head := UI.hbox(8)
	head.add_child(UI.button("< Back", func():
		_picking = -1
		_build()
	, "os_ghost" if light else "ghost", 13))
	var t := UI.label("Pick your story. Reused excuses wear out; some get checked.", 13, _dim())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(t)
	add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(grid)
	for e in Deception.options(context):
		var c := UI.Clicky.new()
		c.setup(UI.OS_SOFT if light else UI.PANEL2, UI.OS_LINE if light else UI.LINE, 1, light)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col := UI.vbox(3)
		col.add_child(UI.wrap("\"%s\"" % str(e.label), 14, UI.OS_TEXT if light else UI.TEXT))
		var meta := UI.hbox(5)
		var pct := float(e.chance)
		if bool(e.burned):
			meta.add_child(UI.pill("WORN OUT - will backfire", UI.RED, 10, true))
		else:
			var oc: Color = Deception.odds_color(pct)
			meta.add_child(UI.pill("%s %d%%" % [Deception.odds_word(pct), int(round(pct))], oc.darkened(0.25) if light else oc, 10))
		if bool(e.evidence):
			meta.add_child(UI.pill("EVIDENCE", Color("1f8f4a") if light else UI.GREEN, 10))
		if int(e.uses) > 0:
			meta.add_child(UI.pill("used %dx" % int(e.uses), Color("b3243a") if light else UI.ORANGE, 10))
		col.add_child(meta)
		col.add_child(UI.wrap(str(e.hint), 11, _dim()))
		c.add_child(col)
		c.pressed.connect(_pick_excuse.bind(str(e.id)))
		grid.add_child(c)


func _pick(i: int) -> void:
	if i < 0 or i >= _choices.size():
		return
	var c: Dictionary = _choices[i]
	if not Corp.choice_view(c, context).ok:
		return
	if bool(c.get("excuse", false)):
		_picking = i
		_build()
		return
	if Actions.lethal(str(c.get("a", "ack"))) and _armed != i:
		_armed = i
		Bus.sfx.emit("bad")
		_build()
		return
	chosen.emit(i, "")


func _pick_excuse(id: String) -> void:
	var i := _picking
	_picking = -1
	chosen.emit(i, id)


func _unhandled_key_input(e: InputEvent) -> void:
	if not hotkeys or not is_visible_in_tree() or _picking >= 0:
		return
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var n := int(k.physical_keycode) - KEY_1
	if n >= 0 and n < _choices.size():
		get_viewport().set_input_as_handled()
		_pick(n)
