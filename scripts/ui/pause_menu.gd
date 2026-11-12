class_name PauseMenu
extends Dim

signal resume()
signal to_menu()
signal load_slot(slot: String)

var _body: VBoxContainer
var _mode := "main"

func _ready() -> void:
	setup(0.72)
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
			_body.add_child(UI.label("%s, %s  -  %s" % [Game.time.day_name(), Cfg.fmt_time(fposmod(float(Game.time.minute), 1440.0)), str(Game.diff().name)], 14, UI.DIM))
			_body.add_child(UI.gap(1, 6))
			_body.add_child(_big("Resume", func(): resume.emit(), true))
			var sv := _big("Save Game", _nav.bind("save"))
			sv.disabled = not Game.saves.can_save()
			_body.add_child(sv)
			var ld := _big("Load Game", _nav.bind("load"))
			ld.disabled = Game.saves.list().is_empty()
			_body.add_child(ld)
			_body.add_child(_big("Settings", _nav.bind("settings")))
			_body.add_child(_big("How to Play", _nav.bind("how")))
			_body.add_child(_big("Quit to Main Menu", func(): to_menu.emit()))
		"settings":
			_body.add_child(UI.title("Settings", 28))
			_body.add_child(Panels.settings_panel())
			_body.add_child(_big("Back", _nav.bind("main")))
		"how":
			_body.add_child(UI.title("How to Play", 28))
			_body.add_child(Panels.how_to_panel())
			_body.add_child(Panels.controls_panel())
			_body.add_child(_big("Back", _nav.bind("main")))
		"save", "load":
			var saving := _mode == "save"
			_body.add_child(UI.title("Save Game" if saving else "Load Game", 28))
			for slot in SaveManager.SLOTS:
				if saving and slot == "auto":
					continue
				var m := Game.saves.meta(slot)
				if not saving and m.is_empty():
					continue
				var c := UI.Clicky.new()
				c.setup(UI.PANEL2, UI.LINE, 1, false)
				var v := UI.vbox(1)
				v.add_child(UI.title(str(SaveManager.SLOT_NAMES[slot]), 17))
				v.add_child(UI.label(Game.saves.describe(m), 12, UI.DIM))
				c.add_child(v)
				c.pressed.connect(func():
					if saving:
						if Game.saves.save(slot):
							Bus.toast.emit("Saved to %s." % str(SaveManager.SLOT_NAMES[slot]), "good")
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
