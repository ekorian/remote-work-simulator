class_name ShopPanel
extends Dim

signal closed()

var _grid: GridContainer
var _money: Label
var _dirty := true

func _ready() -> void:
	setup(1.0)
	bg.color = UI.BG
	visible = false
	# Same footprint as the work desktop: the HUD column keeps the right strip.
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sb(Color("14121f"), 16, 2, Color("b48cff"), 22, 16))
	UI.full(p)
	p.offset_left = 12
	p.offset_top = 12
	p.offset_bottom = -12
	p.offset_right = -(Hud.COL_W + 28.0)
	add_child(p)
	var v := UI.vbox(10)
	p.add_child(v)
	var head := UI.hbox(12)
	v.add_child(head)
	var tv := UI.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UI.title("ShadyDeals.biz", 32, Color("b48cff")))
	tv.add_child(UI.label("\"Solutions\" for the modern remote professional. No refunds. No questions.", 13, UI.DIM))
	head.add_child(tv)
	_money = UI.title("$0", 28, UI.ACCENT)
	head.add_child(_money)
	head.add_child(UI.button("Close  (Esc)", close, "ghost", 14))
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	v.add_child(UI.scroll(_grid))
	Bus.gadget_changed.connect(func(_g): _dirty = true)
	Game.economy.money_changed.connect(func(_a, _b, _c): _dirty = true)
	Game.economy.favors_changed.connect(func(_f): _dirty = true)

func open() -> void:
	visible = true
	_dirty = true

func close() -> void:
	if visible:
		visible = false
		closed.emit()

func _process(_delta: float) -> void:
	if visible and _dirty and Game.active:
		_dirty = false
		_build()

func _gadget_tile(id: String) -> Control:
	## One gadget: what it does now, what the next level adds, and the price.
	var auto := Game.automation
	var def := auto.def(id)
	var lv := auto.level(id)
	var top := auto.max_level(id)
	var owned := lv > 0
	var maxed := lv >= top
	var why := auto.locked_reason(id)
	var p := UI.panel(Color("1f3a2b") if owned else Color("211d36"), 14, 14, 1, UI.GREEN if owned else UI.LINE)
	p.custom_minimum_size = Vector2(300, 250)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6)
	p.add_child(v)
	var head := UI.hbox(8)
	var t := UI.title(str(def.display_name), 19, UI.DIM if why != "" and not owned else UI.TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var pips := UI.hbox(3)
	for i in top:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(14, 8)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.add_theme_stylebox_override("panel", UI.sb(UI.GREEN if i < lv else Color(1, 1, 1, 0.16), 3))
		pips.add_child(pip)
	pips.tooltip_text = "Level %d of %d" % [lv, top]
	head.add_child(pips)
	v.add_child(head)
	v.add_child(UI.wrap(str(def.blurb), 12, UI.DIM))
	var next: Dictionary = auto.data(id, mini(lv + 1, top))
	var box := UI.panel(Color(0, 0, 0, 0.25), 8, 8)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bv := UI.vbox(3)
	box.add_child(bv)
	if maxed:
		bv.add_child(UI.label("FULLY UPGRADED", 11, UI.GREEN, true))
		bv.add_child(UI.wrap(str(auto.data(id).text), 12, UI.TEXT))
	else:
		bv.add_child(UI.label("LEVEL %d" % (lv + 1) if owned else "LEVEL 1", 11, UI.ACCENT, true))
		bv.add_child(UI.wrap(str(next.text), 12, UI.TEXT))
	v.add_child(box)
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 5)
	tags.add_theme_constant_override("v_separation", 3)
	tags.add_child(UI.pill("RELIABILITY %d%%" % int(round(float(next.reliability))), UI.BLUE, 10))
	tags.add_child(UI.pill("HEAT +%d" % int(next.heat), UI.ORANGE, 10))
	tags.add_child(UI.pill("RUNS CONTINUOUSLY" if str(def.kind) == "always" else "FIRES WHEN NEEDED", UI.PURPLE, 10))
	if bool(def.needs_net):
		tags.add_child(UI.pill("NEEDS INTERNET", UI.TEAL, 10))
	v.add_child(tags)
	var foot := UI.hbox(8)
	v.add_child(foot)
	if maxed:
		foot.add_child(UI.spacer())
		foot.add_child(UI.pill("MAX LEVEL", UI.GREEN, 12, true))
		return p
	var cost := auto.price(id)
	foot.add_child(UI.title("$%d" % cost, 20, UI.ACCENT))
	foot.add_child(UI.spacer())
	if why != "":
		foot.add_child(UI.pill(why.to_upper(), UI.DIM, 10))
	else:
		var bb := UI.button("Upgrade" if owned else "Buy", func(): auto.buy(id), "primary", 15)
		bb.disabled = not Game.economy.can_afford(cost)
		foot.add_child(bb)
	return p


func _build() -> void:
	_money.text = "$%d" % Game.economy.money
	UI.clear(_grid)
	for id in Db.gadget_order():
		_grid.add_child(_gadget_tile(id))
	# The gift card: buy a favour.
	var gp := UI.panel(Color("211d36"), 14, 14, 1, UI.LINE)
	gp.custom_minimum_size = Vector2(300, 250)
	gp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gv := UI.vbox(6)
	gp.add_child(gv)
	gv.add_child(UI.title("Gift Card \"For The Team\"", 19))
	var gt := UI.wrap("Send Dave a gift card. Dave will owe you one favour, which you can spend in SynerTasks to hand him a ticket. One per day. You have %d favour(s)." % Game.economy.favors, 12, UI.DIM)
	gt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gv.add_child(gt)
	gv.add_child(UI.pill("SOCIAL", Color("ff9ecb"), 10))
	var gf := UI.hbox(8)
	gv.add_child(gf)
	var gcost := Game.economy.price(AutomationManager.BRIBE_PRICE)
	gf.add_child(UI.title("$%d" % gcost, 20, UI.ACCENT))
	gf.add_child(UI.spacer())
	if Game.automation.can_bribe():
		var gb := UI.button("Buy", func(): Game.automation.bribe(), "primary", 15)
		gb.disabled = not Game.economy.can_afford(gcost)
		gf.add_child(gb)
	else:
		gf.add_child(UI.pill("ONE PER DAY", UI.DIM, 10))
	_grid.add_child(gp)
