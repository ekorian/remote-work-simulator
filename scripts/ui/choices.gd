class_name ChoiceList
extends VBoxContainer
## The answer buttons for a chat prompt, a mail or a call question, including
## the excuse picker and the "are you sure you want to WORK?" confirmation.
## Every button carries the class badge supplied by WorkSystem.badge().

signal chosen(index: int, excuse_id: String)
signal picking_changed(picking: bool)    ## the excuse picker opened or closed

var light := false                 ## SynerOS (light) or game chrome (dark)
var context := "chat"              ## chat | video | phone | ticket
var listener := ""                 ## npc the answers are addressed to
var hotkeys := false               ## number keys pick answers
var only: Array = []               ## restrict the excuse picker to these claim ids
var picker_height := 330.0         ## visible height of the (scrolling) excuse picker
var columns := 2
var _choices: Array = []
var _picking := -1                 ## index of the excuse choice being expanded
var _armed := -1                   ## index of a lethal choice awaiting confirmation


func _init() -> void:
	add_theme_constant_override("separation", 7)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func show_choices(list: Array, ctx: String = "chat", to: String = "") -> void:
	_choices = list
	context = ctx
	listener = to if to != "" else Game.npcs.boss_id()
	_picking = -1
	_armed = -1
	_build()


func show_excuses(ctx: String, to: String = "", restrict: Array = []) -> void:
	## Open straight on the excuse picker (meetings, tickets).
	only = restrict
	show_choices([{"t": "Make an excuse...", "a": "excuse", "excuse": true}], ctx, to)
	_picking = 0
	_build()
	picking_changed.emit(true)


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
		var view := Game.comms.choice_view(c, context, listener)
		if i == _armed:
			view.text = "This is REAL WORK. It ends your run on this difficulty. Click again to throw it all away."
		add_child(UI.choice(view, _pick.bind(i), light, str(i + 1) if hotkeys else ""))


func _build_excuses() -> void:
	var head := UI.hbox(8)
	if _choices.size() > 1:
		head.add_child(UI.button("< Back", func():
			_picking = -1
			_build()
			picking_changed.emit(false)
		, "os_ghost" if light else "ghost", 13))
	var t := UI.label("Pick your story. It goes on record: while it lasts, don't do what would contradict it.", 13, _dim())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(t)
	add_child(head)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sc := UI.scroll(grid)
	sc.custom_minimum_size.y = picker_height
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(sc)
	var text_col: Color = UI.OS_TEXT if light else UI.TEXT
	var good_col: Color = Color("1f8f4a") if light else Color("8fe0a6")
	var bad_col: Color = Color("b3243a") if light else Color("ff9aa8")
	for e in Game.deception.options(context, listener):
		if not only.is_empty() and not str(e.id) in only:
			continue
		var c := UI.Clicky.new()
		c.setup(UI.OS_SOFT if light else UI.PANEL2, UI.OS_LINE if light else UI.LINE, 1, light)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col := UI.vbox(3)
		var top := HFlowContainer.new()
		top.add_theme_constant_override("h_separation", 6)
		top.add_theme_constant_override("v_separation", 3)
		top.add_child(UI.label(str(e.title), 14, text_col, true))
		var pct := float(e.chance)
		if bool(e.burned):
			top.add_child(UI.pill("WORN OUT: will backfire", UI.RED, 10, true))
		elif str(e.conflict) != "":
			top.add_child(UI.pill("CLASHES with '%s'" % str(e.conflict), UI.RED, 10, true))
		else:
			var oc: Color = DeceptionManager.odds_color(pct)
			top.add_child(UI.pill("%s %d%%" % [DeceptionManager.odds_word(pct), int(round(pct))], oc.darkened(0.25) if light else oc, 10))
		for ev in e.evidence:
			top.add_child(UI.pill("EVIDENCE: %s" % str(ev), good_col, 10))
		if int(e.uses) > 0:
			top.add_child(UI.pill("used %dx" % int(e.uses), bad_col, 10))
		col.add_child(top)
		col.add_child(UI.wrap("\"%s\"" % str(e.label).replace("{subject}", "..."), 12, text_col))
		col.add_child(UI.wrap("+ %s" % str(e.strength), 11, good_col))
		col.add_child(UI.wrap("- %s" % str(e.weakness), 11, bad_col))
		c.add_child(col)
		c.pressed.connect(_pick_excuse.bind(str(e.id)))
		grid.add_child(c)


func _pick(i: int) -> void:
	if i < 0 or i >= _choices.size():
		return
	var c: Dictionary = _choices[i]
	if not Game.comms.choice_view(c, context, listener).ok:
		return
	if bool(c.get("excuse", false)):
		_picking = i
		_build()
		picking_changed.emit(true)
		return
	if Game.work.lethal(str(c.get("a", "ack"))) and _armed != i:
		_armed = i
		Bus.sfx.emit("bad")
		_build()
		return
	chosen.emit(i, "")


func _pick_excuse(id: String) -> void:
	var i := _picking
	_picking = -1
	picking_changed.emit(false)
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
