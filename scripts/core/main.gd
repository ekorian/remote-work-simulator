extends Node
## Main — builds the scene tree (world + UI layers) and owns the screen flow:
## menu -> new game -> play (desk / shop / phone / calls / pause) -> reports.

var world: World
var ui_root: Control
var hud: Hud
var desktop: Desktop
var phone: PhonePanel
var ring: RingDialog
var call_view: CallView
var shop: ShopPanel
var menu: MainMenu
var new_game: NewGameScreen
var pause: PauseMenu
var report: DayReport
var results: ResultsScreen
var fade: ColorRect
var day_card: VBoxContainer

var state := "boot"                ## menu | setup | play
var shots_dir := ""
var _ring_seen := ""               ## meeting id the ring dialog already popped for
var _pending_report: Dictionary = {}
var _last_run := {"diff": "survivor", "look": {}, "tutorial": true}
var _amb := ""


func _ready() -> void:
	get_tree().auto_accept_quit = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.trim_prefix("--shots=")
	world = $World
	ui_root = $UI/Root
	ui_root.theme = UI.setup()
	_build_ui()
	_connect()
	show_menu()
	if shots_dir != "" and ResourceLoader.exists("res://tests/harness/shots.gd"):
		var dev: Node = load("res://tests/harness/shots.gd").new()
		dev.set("main", self)
		dev.set("out_dir", shots_dir)
		add_child(dev)


func _exit_tree() -> void:
	# Drop shared caches so the engine shuts down without "still in use" noise.
	Sfx.stop_loops()
	UI.theme = null
	UI.font_title = null
	UI.font_body = null
	UI.font_bold = null
	Kit._mats.clear()
	Kit._meshes.clear()
	Interactable._overlay = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


func quit_game() -> void:
	## Save if there is a run in progress, let audio wind down, then exit.
	if state == "play":
		Game.saves.autosave()
	Sfx.silence()
	await get_tree().create_timer(0.15, true, false, true).timeout
	get_tree().quit()


func _screen(path: String) -> Control:
	## Instantiate a UI scene under the root (order = draw order).
	var node: Control = (load(path) as PackedScene).instantiate()
	ui_root.add_child(node)
	return node


func _build_ui() -> void:
	# The desktop and shop sit under the HUD so the stat column stays visible.
	desktop = _screen("res://scenes/workstation/desktop.tscn")
	shop = _screen("res://scenes/workstation/shop.tscn")
	hud = _screen("res://scenes/ui/hud.tscn")
	hud.world = world
	hud.visible = false
	phone = _screen("res://scenes/ui/phone.tscn")
	ring = _screen("res://scenes/events/ring_dialog.tscn")
	call_view = _screen("res://scenes/events/call_view.tscn")
	report = _screen("res://scenes/ui/day_report.tscn")
	results = _screen("res://scenes/ui/results.tscn")
	menu = _screen("res://scenes/main_menu/main_menu.tscn")
	new_game = _screen("res://scenes/main_menu/new_game.tscn")
	pause = _screen("res://scenes/ui/pause_menu.tscn")
	fade = ColorRect.new()
	fade.color = Color(0.105, 0.094, 0.165, 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full(fade)
	ui_root.add_child(fade)
	day_card = UI.vbox(2)
	day_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	day_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	day_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	day_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_card.modulate.a = 0.0
	ui_root.add_child(day_card)
	create_tween().tween_property(fade, "color:a", 0.0, 0.7)


func _connect() -> void:
	menu.new_game.connect(show_setup)
	menu.continue_game.connect(load_run)
	menu.quit.connect(quit_game)
	new_game.back.connect(show_menu)
	new_game.start.connect(start_run)
	new_game.look_changed.connect(func(l: Dictionary): world.player.body.set_look(l, "casual"))
	pause.resume.connect(close_pause)
	pause.to_menu.connect(func():
		Game.saves.autosave()
		show_menu()
	)
	pause.load_slot.connect(load_run)
	report.done.connect(_on_report_done)
	results.to_menu.connect(show_menu)
	results.again.connect(func(): start_run(str(_last_run.diff), _last_run.look, false))
	desktop.closed.connect(_on_desktop_closed)
	desktop.join_requested.connect(func(mid: String): join_call(mid, false))
	shop.closed.connect(_on_shop_closed)
	phone.closed.connect(_refresh)
	phone.join.connect(func(mid: String): join_call(mid, true))
	ring.join.connect(join_call)
	ring.dismissed.connect(_refresh)
	call_view.ended.connect(_on_call_ended)
	hud.inbox_clicked.connect(_on_inbox_clicked)
	hud.ring_clicked.connect(func(): open_ring(true))
	hud.option_chosen.connect(func(t: Interactable, opt: String):
		world.choose(t, opt)
		_refresh()
	)
	hud.menu_closed.connect(_refresh)
	world.menu_requested.connect(func(t: Interactable):
		hud.open_menu(t)
		_refresh()
	)
	Bus.request_desktop.connect(open_desktop)
	Bus.request_shop.connect(open_shop)
	Bus.meeting_changed.connect(_on_meeting_changed)
	Game.workday_ended.connect(_on_workday_ended)
	Game.run_ended.connect(_on_run_ended)
	Game.time.phase_changed.connect(func(_p): _update_audio())
	Game.day_started.connect(func(d: int):
		_update_audio()
		if state == "play" and d > 0:
			show_day_card()
	)


# ---------------------------------------------------------------------------
# Screen flow
# ---------------------------------------------------------------------------

func _hide_all() -> void:
	day_card.modulate.a = 0.0
	for c in [desktop, shop, phone, ring, call_view, report, results, menu, new_game, pause]:
		(c as Control).visible = false
	hud.close_menu()
	hud.visible = false


func show_menu() -> void:
	_hide_all()
	Game.clear_run()
	state = "menu"
	world.demo = true
	world.demo_minute = 650.0
	world.interactive = false
	world.place_player(Vector3(-3.4, 0, 2.75), 0.0)
	world.player.body.set_look(Character.DEFAULT_LOOK, "pajamas")
	world.sit_at("sofa", "lounge")
	world.rig.target = null
	world.rig.close_up = false
	world.rig.zoom = 17.5
	world.rig.orbit = 0.07
	world.rig.pan = -6.2
	world.rig._focus = Vector3(0.0, 0.4, 0.0)
	menu.open()
	_update_audio()


func show_setup() -> void:
	_hide_all()
	state = "setup"
	world.demo = true
	world.demo_minute = 600.0
	world.place_player(Vector3(-1.4, 0, 3.0), 0.0)
	world.player.rotation.y = deg_to_rad(225.0)
	world.player.body.anim = "wave"
	world.rig.orbit = 0.0
	world.rig.pan = 0.0
	world.rig.yaw_step = 0
	world.rig.zoom = 4.6
	world.rig.target = world.player
	new_game.open()


func start_run(diff: String, look: Dictionary, tutorial: bool) -> void:
	_last_run = {"diff": diff, "look": look.duplicate(true), "tutorial": tutorial}
	_hide_all()
	_enter_play()
	Game.new_run(diff, look, tutorial)
	Game.saves.autosave()
	_begin_play()
	if tutorial:
		Bus.toast.emit("Monday, 08:59. You work from home for SynerCorp. The plan: don't.", "tip")
	else:
		Bus.toast.emit("Monday, 08:59. Survive until Friday 17:00. Don't work. Don't get caught.", "info")


func load_run(slot: String) -> void:
	_hide_all()
	_enter_play()
	if not Game.saves.load_game(slot):
		Bus.toast.emit("That save could not be loaded.", "bad")
		show_menu()
		return
	_last_run = {"diff": str(Game.difficulty_id), "look": Game.player.duplicate(true), "tutorial": false}
	_begin_play()
	Bus.toast.emit("Loaded: %s, %s." % [Game.time.day_name(), Cfg.fmt_time(fposmod(float(Game.time.minute), 1440.0))], "info")


func _enter_play() -> void:
	state = "play"
	world.demo = false
	world.rig.pan = 0.0
	world.rig.cam.h_offset = 0.0
	world.rig.orbit = 0.0
	world.rig.yaw_step = 0
	world.rig.zoom = 12.5
	world.rig.close_up = false
	world.rig.target = world.player
	world.player.body.anim = "idle"
	world.leave_seat()
	_ring_seen = ""
	_pending_report = {}


func _begin_play() -> void:
	hud.visible = true
	show_day_card()
	_refresh()
	_update_audio()


func show_day_card() -> void:
	## Fade in from black with the day's name: "TUESDAY - Day 2 of 5".
	if not Game.active:
		return
	UI.clear(day_card)
	var day := clampi(int(Game.time.day), 0, 4)
	var evening: bool = str(Game.time.phase) == "evening"
	var t := UI.title(Cfg.DAYS[day].to_upper(), 96)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_card.add_child(t)
	var lines := ["The plan: don't.", "They suspect nothing. Probably.", "Hump day. Stay horizontal.", "SynerWatch is watching.", "Review day. Wear a shirt."]
	var sub_l := UI.title("Day %d of 5  -  %s" % [day + 1, "after hours" if evening else str(lines[day])], 24, UI.ACCENT)
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_card.add_child(sub_l)
	fade.color.a = 1.0
	day_card.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(fade, "color:a", 0.0, 0.7)
	tw.parallel().tween_property(day_card, "modulate:a", 0.0, 0.6)
	Bus.sfx.emit("login")


func overlay_blocks_desk() -> bool:
	return ring.visible or call_view.visible or report.visible or results.visible or pause.visible


func overlay_open() -> bool:
	return desktop.visible or shop.visible or ring.visible or call_view.visible or report.visible or results.visible or pause.visible or hud.menu_open()


func _refresh() -> void:
	## Recompute who owns input and whether the clock runs.
	if state != "play":
		return
	world.interactive = not overlay_open()
	Game.paused = pause.visible or call_view.visible or report.visible or results.visible
	hud.desk_mode = desktop.visible or shop.visible
	hud.visible = not results.visible and not report.visible
	if Game.active and Game.time.phase != "over":
		Game.presence.set_at_desk(desktop.visible or (Game.activities.busy() and str(Game.activities.current.get("id", "")) in ["desk_nap", "work", "grind"] and bool(Game.presence.at_desk)))


func open_desktop(app: String = "") -> void:
	if state != "play" or desktop.visible:
		return
	hud.close_menu()
	phone.visible = false
	desktop.open(app)
	Game.presence.set_at_desk(true)
	Bus.desktop_opened.emit()
	Bus.sfx.emit("login")
	_refresh()
	if not Game.comms.ringing().is_empty() and not Game.comms.in_call():
		open_ring(true)


func _on_desktop_closed() -> void:
	Bus.desktop_closed.emit()
	Bus.sfx.emit("logout")
	_refresh()


func open_shop() -> void:
	if state != "play":
		return
	hud.close_menu()
	world.sit_at("gaming_pc", "game")
	shop.open()
	_refresh()


func _on_shop_closed() -> void:
	world.leave_seat()
	_refresh()


func open_ring(force: bool = false) -> void:
	var m := Game.comms.ringing()
	if m.is_empty() or Game.comms.in_call() or call_view.visible or report.visible:
		return
	if not force and (_ring_seen == str(m.id) or not Game.presence.can_notice()):
		return
	_ring_seen = str(m.id)
	hud.close_menu()
	ring.open(str(m.id))
	_refresh()


func join_call(mid: String, via_phone: bool) -> void:
	ring.visible = false
	phone.visible = false
	if via_phone:
		Game.home.phone_spend(10.0)
	if not Game.comms.join(mid, via_phone):
		_refresh()
		return
	call_view.start()
	_refresh()


func _on_call_ended() -> void:
	_refresh()
	if not _pending_report.is_empty() and Game.active and Game.time.phase != "over":
		var rep := _pending_report
		_pending_report = {}
		_show_report(rep)


func _on_meeting_changed(m: Dictionary) -> void:
	if state != "play":
		return
	if str(m.state) == "ringing":
		open_ring(false)


func _on_inbox_clicked(pid: String) -> void:
	if desktop.visible:
		desktop.open_prompt(pid)
	elif Game.home.phone_usable():
		phone.open(pid)
	else:
		Bus.toast.emit("Your phone isn't on you. Answer at the Work Computer.", "warn")
	_refresh()


func toggle_phone() -> void:
	if state != "play" or desktop.visible or call_view.visible or report.visible or pause.visible:
		return
	if phone.visible:
		phone.close()
	else:
		phone.open("")
	_refresh()


func open_pause() -> void:
	if state != "play" or not Game.active:
		return
	pause.open()
	_refresh()


func close_pause() -> void:
	pause.visible = false
	_refresh()


func _on_workday_ended(rep: Dictionary) -> void:
	if state != "play":
		return
	desktop.visible = false
	Bus.desktop_closed.emit()
	shop.visible = false
	ring.visible = false
	phone.visible = false
	hud.close_menu()
	if call_view.visible:
		_pending_report = rep
		return
	_show_report(rep)


func _show_report(rep: Dictionary) -> void:
	report.show_report(rep)
	_refresh()


func _on_report_done() -> void:
	if Game.active and int(Game.time.day) >= 4 and Game.time.phase != "over":
		Game.finish_week()
		return
	_refresh()
	Game.saves.autosave()
	Bus.toast.emit("17:00. You are free. Shop, recover, then sleep to start tomorrow.", "info")


func _on_run_ended(res: Dictionary) -> void:
	if state != "play":
		return
	for c in [desktop, shop, phone, ring, report, pause]:
		(c as Control).visible = false
	hud.close_menu()
	if bool(res.won):
		Game.saves.delete("auto")
	_show_results.call_deferred(res)


func _show_results(res: Dictionary) -> void:
	call_view.visible = false
	results.show_result(res)
	_refresh()
	_update_audio()


# ---------------------------------------------------------------------------
# Input and per-frame
# ---------------------------------------------------------------------------

func _unhandled_input(e: InputEvent) -> void:
	if state != "play":
		if e.is_action_pressed("pause") and state == "setup":
			show_menu()
		return
	if e.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if pause.visible:
			if not pause.back():
				close_pause()
		elif results.visible or report.visible or call_view.visible:
			pass
		elif ring.visible:
			ring.close()
		elif hud.menu_open():
			hud.close_menu()
		elif shop.visible:
			shop.close()
		elif phone.visible:
			phone.close()
		elif desktop.visible:
			desktop.close()
		else:
			open_pause()
	elif e.is_action_pressed("phone"):
		get_viewport().set_input_as_handled()
		toggle_phone()
	elif e.is_action_pressed("interact") and desktop.visible and Game.activities.busy() and not overlay_blocks_desk():
		get_viewport().set_input_as_handled()
		Game.activities.stop()


func _process(_delta: float) -> void:
	if state != "play" or not Game.active:
		return
	# Keep the "at desk" flag honest while the desktop is open.
	if desktop.visible and not bool(Game.presence.at_desk) and Game.time.phase != "over":
		Game.presence.set_at_desk(true)
	var busy := Game.activities.busy()
	var act := str(Game.activities.current.get("id", "")) if busy else ""
	Sfx.loop("typing", desktop.visible or act in ["work", "grind"], -16.0, "SFX")
	Sfx.loop("tv_loop", act in ["tv", "console"], -14.0, "SFX")
	# A colleague, a stranger and a meeting each ring differently.
	var ringing := Game.comms.ringing()
	var audible: bool = not ringing.is_empty() and not Game.comms.in_call() and (ring.visible or Game.presence.can_notice())
	var tone := Game.comms.ring_sound(ringing) if audible else ""
	for r in ["ring_loop", "ring_peer", "ring_weird"]:
		Sfx.loop(r, r == tone, -10.0, "SFX")
	Sfx.loop("snore", act in ["nap", "power_nap", "desk_nap"], -14.0, "SFX")


func _update_audio() -> void:
	var want := "amb_day"
	if state == "play" and Game.active and str(Game.time.phase) == "evening":
		want = "amb_night"
	if want != _amb:
		if _amb != "":
			Sfx.loop(_amb, false)
		_amb = want
		Sfx.loop(_amb, true, -15.0, "Ambience")
	if state != "play":
		Sfx.stop_loops()
		_amb = ""
		Sfx.music("music_menu", -11.0)
	elif results.visible:
		Sfx.music("music_menu", -13.0)
	else:
		Sfx.music("music_day", -17.0)
