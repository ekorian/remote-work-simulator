extends Node
## Dev-only: scripted screenshot capture for visual checks.
##   tools/shots.sh <scene> [out_dir]      scenes: world menu play desk overlays ends night

var main: Node
var out_dir := ""
var scene := "world"

const LOOK := {"name": "Alex", "skin": 1, "hair": 0, "hair_color": 1, "shirt": 0, "pants": 0, "accessory": 1}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene = a.trim_prefix("--scene=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.saves.enabled = false
	Prefs.persist = false
	_run.call_deferred()


func snap(shot: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, shot])
	print("shot: ", shot)


func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _run() -> void:
	await wait(0.5)
	for s in scene.split(","):
		if has_method("_scene_" + s):
			await call("_scene_" + s)
		else:
			print("unknown scene: ", s)
	main.quit_game()


func _start(diff: String = "survivor", tutorial: bool = false, seed_v: int = 42) -> void:
	main.start_run(diff, LOOK, tutorial)
	Game.rng.seed = seed_v
	await wait(0.7)


func _skip(minutes: int) -> void:
	## Advance the sim without the clock running in real time.
	Game.time.manual = true
	for i in minutes:
		if Game.comms.in_call() or not Game.active or Game.time.phase != "work":
			break
		Game.time.advance(1)
	Game.time.manual = false


func _scene_world() -> void:
	var w: World = main.world
	await _start()
	main.hud.visible = false
	Game.paused = true
	w.rig.zoom = 19.0
	w.rig.target = null
	w.rig.snap_to(Vector3(0, 0.9, 0))
	await wait(0.6)
	await snap("world_overview")
	w.rig.target = w.player
	w.rig.zoom = 9.0
	for spot in [["office", Vector3(-4.2, 0, -2.6)], ["bedroom", Vector3(3.2, 0, -2.6)], ["living", Vector3(-3.6, 0, 3.4)], ["kitchen", Vector3(4.0, 0, 2.2)]]:
		w.place_player(spot[1], 0.6)
		w.rig.snap_to(spot[1] + Vector3(0, 0.9, 0))
		await wait(0.5)
		await snap("room_" + str(spot[0]))


func _scene_menu() -> void:
	await wait(1.0)
	await snap("menu_main")
	main.menu._toggle("how")
	await wait(0.3)
	await snap("menu_how")
	main.show_setup()
	await wait(0.9)
	await snap("menu_setup")
	main.show_menu()
	await wait(0.3)


func _scene_play() -> void:
	var w: World = main.world
	await _start("survivor", true)
	await wait(0.6)
	await snap("play_start_tutorial")
	Game.tutor.skip()
	Game.time.hold = false
	# Walk to the kitchen and look at the fridge.
	w.place_player(w.apartment.things["fridge"].use_point(), 0.0)
	w.rig.snap_to(w.player.global_position + Vector3(0, 0.9, 0))
	_skip(45)
	await wait(0.5)
	await snap("play_focus_fridge")
	w.place_player(w.apartment.things["mug"].use_point() + Vector3(0, 0, 0.0), 0.0)
	w.rig.snap_to(w.player.global_position + Vector3(0, 0.9, 0))
	await wait(0.4)
	main.hud.open_menu(w.apartment.things["mug"])
	main._refresh()
	await wait(0.3)
	await snap("play_object_menu")
	main.hud.close_menu()
	# An activity in progress.
	w.interact(w.apartment.things["console"])
	await wait(0.2)
	w.place_player(w.apartment.things["console"].use_point(), 0.0)
	w.interact(w.apartment.things["console"])
	await wait(1.2)
	w.rig.snap_to(w.player.global_position + Vector3(0, 0.9, 0))
	await wait(0.4)
	await snap("play_activity_console")
	Game.activities.stop()
	w.place_player(w.apartment.things["bed"].use_point(), 0.0)
	Game.home.use("bed", "power_nap")
	await wait(0.8)
	w.rig.snap_to(w.player.global_position + Vector3(0, 0.9, 0))
	await wait(0.3)
	await snap("play_activity_nap")
	Game.activities.stop()


func _scene_desk() -> void:
	await _start("survivor", false)
	_skip(20)
	main.open_desktop("teams")
	await wait(0.8)
	await snap("desk_teams_prompt")
	# Open the excuse picker on the pending prompt.
	var p: Dictionary = Game.comms.prompt_for_thread(Game.npcs.boss_id())
	if not p.is_empty():
		for c in main.desktop.find_children("*", "VBoxContainer", true, false):
			if c is ChoiceList:
				(c as ChoiceList)._pick(Game.comms.choices_of(p).size() - 1)
				break
		await wait(0.3)
		await snap("desk_teams_excuses")
	_skip(90)
	Game.work.task_fake(str(Game.work.tasks[0].id))
	main.desktop.open_app("tasks")
	await wait(0.5)
	await snap("desk_tasks")
	main.desktop.block_for = str(Game.work.tasks[0].id)
	main.desktop.task_id = str(Game.work.tasks[0].id)
	main.desktop._dirty = true
	await wait(0.5)
	await snap("desk_tasks_blocked")
	main.desktop.block_for = ""
	main.desktop.open_app("cal")
	Game.comms.add_block(840, 30)
	await wait(0.5)
	await snap("desk_calendar")
	_skip(60)
	main.desktop.open_app("mail")
	await wait(0.5)
	await snap("desk_mail")
	Game.economy.money = 900
	Game.time.day = 3
	for gid in ["mousemover", "duck", "chatbot"]:
		Game.automation.buy(gid)
	Game.automation.buy("mousemover")
	Game.automation.toggle("mousemover")
	Game.automation.toggle("chatbot")
	Game.home.use("router", "off")
	Game.deception.attempt("family_emergency", "chat", Game.npcs.boss_id(), "Quick status check", "", true)
	Game.home.use("router", "on")
	Game.deception.attempt("computer_crash", "chat", Game.npcs.boss_id(), "Standup")
	Game.deception.observe("social_post")
	Game.time.minute += 3.0
	main.desktop.open_app("shadow")
	await wait(0.5)
	await snap("desk_shadow")
	main.desktop.close()
	await wait(0.3)


func _scene_overlays() -> void:
	var w: World = main.world
	await _start("survivor", false)
	_skip(30)
	# Ring dialog (standup at 09:30)
	main.open_ring(true)
	await wait(0.5)
	await snap("ov_ring")
	var m := Game.comms.ringing()
	if not m.is_empty():
		main.join_call(str(m.id), true)
		await wait(0.6)
		await snap("ov_call")
		main.call_view._on_chosen(0, "")
		await wait(0.5)
		await snap("ov_call_reply")
		while Game.comms.in_call():
			Game.comms.call_timeout()
		main.call_view._finish()
	await wait(0.3)
	_skip(60)
	main.toggle_phone()
	await wait(0.5)
	await snap("ov_phone")
	main.phone.close()
	Game.economy.money = 900
	Game.time.day = 3
	Game.automation.buy("mousemover")
	Game.automation.buy("mousemover")
	Game.automation.buy("chatbot")
	Game.economy.money = 400
	w.place_player(w.apartment.things["gaming_pc"].use_point(), 0.0)
	main.open_shop()
	await wait(0.5)
	await snap("ov_shop")
	main.shop.close()
	main.open_pause()
	await wait(0.4)
	await snap("ov_pause")
	main.close_pause()


func _quiet() -> void:
	## Nothing else is planned, pending or ringing.
	Game.time.timers.clear()
	Game.events.deferred.clear()
	Game.events.last_attention = -999
	Game.comms.meetings.clear()
	Game.stats.values.susp = 20.0
	main.ring.visible = false


func _ring_now(event: String) -> Dictionary:
	## Make a call event ring right now, whatever else was planned.
	_quiet()
	Game.events.fire(event, {"asked": true, "urgent": true})
	_skip(1)
	return Game.comms.ringing()


func _scene_colleagues() -> void:
	## Colleague and stranger calls, the friendship panel, favours.
	var w: World = main.world
	await _start("survivor", false)
	Game.time.timers.clear()
	Game.comms.prompts.clear()
	Game.presence.set_at_desk(true)
	_skip(100)
	await wait(2.5)                   # let the day card fade
	Game.npcs.adjust("dave", 12.0)
	Game.npcs.adjust("kevin", -8.0)
	Game.economy.add_favor(2)
	main.open_desktop("teams")
	var m := _ring_now("brenda_hello")
	main.open_ring(true)
	await wait(0.5)
	await snap("col_ring_colleague")
	main.join_call(str(m.id), false)
	await wait(0.5)
	await snap("col_call_colleague")
	main.call_view._on_chosen(1, "")
	await wait(0.6)
	await snap("col_call_reply")
	while Game.comms.in_call():
		Game.comms.call_choose(0)
	main.call_view._finish()
	await wait(0.3)
	Game.time.day = 1
	m = _ring_now("gerald_first")
	main.open_ring(true)
	await wait(0.4)
	main.join_call(str(m.id), false)
	await wait(2.6)
	await snap("col_call_gerald")
	while Game.comms.in_call():
		Game.comms.call_choose(0)
	main.call_view._finish()
	await wait(0.3)
	Game.events.last_attention = -999
	m = _ring_now("weird_warranty")
	main.open_ring(true)
	await wait(0.5)
	await snap("col_ring_stranger")
	if not m.is_empty():
		main.join_call(str(m.id), false)
		await wait(0.7)
		await snap("col_call_stranger")
		Game.comms.call_hang_up()
		main.call_view._finish()
	else:
		print("weird_warranty did not ring: ", Game.events.can_interrupt(Db.events["weird_warranty"], {"urgent": true}), " deferred ", Game.events.deferred)
	await wait(0.3)
	# SynerTeams: where you stand with each of them.
	_quiet()
	Game.work.add_task("deck")
	for who in ["dave", "kevin", "priya"]:
		main.desktop.thread = who
		main.desktop._dirty = true
		await wait(0.5)
		await snap("col_teams_" + who)
	Game.social.small_talk("dave")
	Game.social.ask("dave", "cover")
	main.desktop.thread = "dave"
	main.desktop._dirty = true
	await wait(0.5)
	await snap("col_teams_dave_asked")
	Game.events.fire("priya_vent", {"urgent": true})
	main.desktop.thread = "priya"
	main.desktop._dirty = true
	await wait(0.5)
	await snap("col_teams_ask")
	main.desktop.task_id = str(Game.work.tasks.back().id)
	main.desktop.open_app("tasks")
	await wait(0.5)
	await snap("col_tasks")
	main.desktop.close()
	await wait(0.3)
	Game.economy.money = 400
	w.place_player(w.apartment.things["gaming_pc"].use_point(), 0.0)
	main.open_shop()
	await wait(0.5)
	await snap("col_shop")
	main.shop.close()


func _scene_ends() -> void:
	await _start("survivor", false)
	Game.time.manual = true
	Game.presence.set_at_desk(true)
	var guard := 0
	while Game.active and str(Game.time.phase) == "work" and guard < 700:
		guard += 1
		Game.stats.values.susp = 22.0
		Game.stats.values.ill = 74.0
		if Game.comms.in_call():
			Game.comms.call_timeout()
		var r := Game.comms.ringing()
		if not r.is_empty():
			Game.comms.join(str(r.id))
		if guard == 200:
			Game.home.use("console", "console")
		Game.time.advance(1)
	Game.time.manual = false
	await wait(2.4)
	await snap("end_report")
	main.report.visible = false
	main._on_report_done()
	await wait(0.6)
	await snap("end_evening")
	Game.end_run("fired", {"reason": "Missed: Daily Standup"})
	await wait(0.8)
	await snap("end_fired")
	main.results.visible = false
	await _start("unemployed", false)
	Game.time.day = 4
	Game.week.salary = 1320
	Game.week.leisure_min = 612
	Game.week.excuses = 9
	Game.week.meetings_avoided = 6
	Game.economy.money = 540
	for d in 5:
		Game.reports.append({"day": d, "title": ["Certified Seat Warmer", "Sultan of Excuses", "Paid Vacationer", "Fully Automated Luxury Employee", "Thought Leader (Zero Thoughts)"][d], "salary": 320, "susp": 30.0 + d * 4.0})
	Game.end_run("win", {})
	await wait(0.8)
	await snap("end_win")


func _scene_poses() -> void:
	## Close-ups of every seated / lying pose, to check facings by eye.
	var w: World = main.world
	await _start("survivor", false)
	main.hud.visible = false
	Game.paused = true
	w.rig.zoom = 5.2
	for pose in [["workstation", "type"], ["gaming_pc", "game"], ["sofa", "lounge"], ["console", "game"], ["bed", "sleep"], ["table", "sit_eat"], ["exercise", "workout"], ["chair", "sit_sleep"]]:
		w.sit_at(str(pose[0]), str(pose[1]))
		w.rig.snap_to(w.player.global_position + Vector3(0, 0.7, 0))
		await wait(0.7)
		await snap("pose_%s" % str(pose[0]))
		w.leave_seat()
	Game.paused = false


func _scene_stretch() -> void:
	## Run at a window size other than the base resolution to verify that 3D
	## picking and the floating name tag still line up (canvas_items stretch).
	var w: World = main.world
	await _start("survivor", false)
	Game.paused = true
	var win := get_viewport().get_visible_rect().size
	print("window %s  canvas %s" % [str(DisplayServer.window_get_size()), str(win)])
	var bad := 0
	for id in w.apartment.things:
		var t: Interactable = w.apartment.things[id]
		w.place_player(t.use_point(), 0.0)
		w.rig.snap_to(w.player.global_position + Vector3(0, 0.9, 0))
		await get_tree().process_frame
		await get_tree().physics_frame
		# Aim at the middle of the object's pick volume, as the mouse would.
		var centre: Vector3 = (t.get_child(0) as Node3D).global_position
		var sp := w.rig.cam.unproject_position(centre)
		var hit := w._thing_under(sp)
		if hit == null:
			bad += 1
			print("  MISS: %s at %s" % [id, str(sp.round())])
	print("STRETCH picking: %d/%d objects hit through their projected centre" % [w.apartment.things.size() - bad, w.apartment.things.size()])
	w.place_player(w.apartment.things["fridge"].use_point(), 0.0)
	w.rig.snap_to(w.player.global_position + Vector3(0, 0.9, 0))
	Game.paused = false
	await wait(0.6)
	await snap("stretch_tag")


func _scene_saveload() -> void:
	## Save through the pause menu path, quit to the menu, continue, compare.
	var w: World = main.world
	Game.saves.enabled = true
	Game.saves.dir = "user://test_saves"
	await _start("senior", false)
	_skip(75)
	Game.economy.money = 432
	Game.time.day = 1
	Game.automation.buy("mousemover")
	w.place_player(w.apartment.things["fridge"].use_point(), 1.1)
	Game.home.use("fridge", "snack")
	await wait(0.4)
	var before := {"t": int(Game.time.minute), "susp": Game.stats.get_value("susp"), "money": int(Game.economy.money), "tasks": Game.work.tasks.size(), "act": str(Game.activities.current.get("id", "")), "prompts": Game.comms.prompts.size()}
	var ok := Game.saves.save("slot2")
	var pos_saved: Array = Game.player_pos.duplicate()
	main.show_menu()
	await wait(0.5)
	var listed := Game.saves.latest()
	main.load_run("slot2")
	var after := {"t": int(Game.time.minute), "susp": Game.stats.get_value("susp"), "money": int(Game.economy.money), "tasks": Game.work.tasks.size(), "act": str(Game.activities.current.get("id", "")), "prompts": Game.comms.prompts.size()}
	var p := w.player.global_position
	var same: bool = ok and listed == "slot2" and absi(int(after.t) - int(before.t)) <= 1 and is_equal_approx(float(after.susp), float(before.susp)) and after.money == before.money and after.tasks == before.tasks and after.act == before.act and Game.automation.owns("mousemover") and Game.difficulty_id == "senior"
	await wait(0.6)
	p = w.player.global_position
	print("SAVELOAD %s  before=%s  after=%s  saved_pos=%s  player=%s  hud=%s" % ["OK" if same else "MISMATCH", str(before), str(after), str(pos_saved), str(p.snapped(Vector3(0.1, 0.1, 0.1))), str(main.hud.visible)])
	await snap("saveload_after")
	Game.activities.stop()
	# Frame rate in normal play.
	await wait(2.5)
	print("FPS in play: %d" % int(Engine.get_frames_per_second()))
	Game.saves.delete("slot2")
	Game.saves.delete("auto")
	Game.saves.enabled = false


func _scene_night() -> void:
	var w: World = main.world
	await _start("survivor", false)
	Game.time.manual = true
	Game.time.phase = "evening"
	Game.time.minute = 1290.0
	main.hud.visible = false
	w.rig.zoom = 18.0
	w.rig.target = null
	w.rig.snap_to(Vector3(0, 0.9, 0))
	await wait(1.6)
	await snap("night_overview")
	Game.time.minute = 1085.0
	await wait(1.0)
	await snap("dusk_overview")
	w.rig.yaw_step = 2
	await wait(1.4)
	await snap("rotated_overview")


# ---------------------------------------------------------------------------
# Autoplay: a bot plays a whole week through the real UI and world, at high
# time scale, to shake out runtime errors.   tools/shots.sh autoplay
# ---------------------------------------------------------------------------

var _auto_diff := "survivor"
var _auto_next := 0.0
var _auto_walk := 0.0
var _auto_shots := {}


func _val(out: Dictionary) -> float:
	var v := -float(out.get("susp", 0)) + float(out.get("ill", 0)) * 0.4 + float(out.get("hp", 0)) * 0.5 + float(out.get("favor", 0)) * 3.0
	if out.has("task"):
		v -= 5.0
	return v


func _best(list: Array, context: String, listener: String = "") -> Array:
	var best := -1
	var best_v := -INF
	var best_ex := ""
	for i in list.size():
		var c: Dictionary = list[i]
		var act := str(c.get("a", "ack"))
		if Game.work.is_work(act) or not Game.comms.choice_view(c, context, listener).ok:
			continue
		if bool(c.get("excuse", false)):
			for e in Game.deception.options(context, listener):
				if bool(e.burned) or str(e.conflict) != "":
					continue
				var p := float(e.chance) / 100.0
				var ev := p * 1.5 - (1.0 - p) * 6.0 - 1.0 + randf() * 2.0
				if ev > best_v:
					best_v = ev
					best = i
					best_ex = str(e.id)
			continue
		var view := Game.comms.choice_view(c, context, listener)
		var v := _val(c.get("ok", {}))
		if float(view.odds) >= 0.0:
			var p := float(view.odds) / 100.0
			v = p * _val(c.get("ok", {})) + (1.0 - p) * _val(c.get("ko", c.get("ok", {})))
		if v > best_v:
			best_v = v
			best = i
			best_ex = ""
	return [best, best_ex]


func _scene_autoplay() -> void:
	var max_ms := 420000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--diff="):
			_auto_diff = a.trim_prefix("--diff=")
		elif a.begins_with("--max="):
			max_ms = int(a.trim_prefix("--max=")) * 1000
	var w: World = main.world
	main.start_run(_auto_diff, LOOK, true)
	await wait(0.5)
	# Where the suspicion came from, for the summary.
	var why := {}
	Game.stats.changed.connect(func(stat: String, _v: float, delta: float, reason: String):
		if stat == "susp" and delta > 0.0:
			var key := reason.get_slice(":", 0) if reason != "" else "(passive)"
			why[key] = float(why.get(key, 0.0)) + delta
	)
	Engine.time_scale = 10.0
	var frames := 0
	var t0 := Time.get_ticks_msec()
	while frames < 400000 and Time.get_ticks_msec() - t0 < max_ms:
		frames += 1
		await get_tree().process_frame
		if main.results.visible:
			break
		if not Game.active:
			break
		_auto_step(w)
		# A few pictures along the way.
		var key := "d%d_%d" % [int(Game.time.day), int(float(Game.time.minute) / 240.0)]
		if not _auto_shots.has(key) and str(Game.time.phase) != "over" and frames % 7 == 0:
			_auto_shots[key] = true
			if _auto_shots.size() % 3 == 0:
				Engine.time_scale = 1.0
				await snap("auto_%02d_%s" % [_auto_shots.size(), key])
				Engine.time_scale = 10.0
	Engine.time_scale = 1.0
	await wait(1.0)
	await snap("auto_final")
	var res: Dictionary = Game.result
	if res.is_empty() and Game.active:
		print("AUTOPLAY STALLED: t=%s phase=%s hold=%s paused=%s busy=%s act=%s pos=%s seated=%s walking=%s desktop=%s shop=%s ring=%s call=%s report=%s pause=%s menu=%s phone=%s prompts=%d energy=%.0f fps=%d" % [
			Cfg.fmt_time(float(Game.time.minute)), str(Game.time.phase), str(Game.time.hold), str(Game.paused), str(Game.activities.busy()), str(Game.activities.current.get("id", "")),
			str(w.player.global_position.snapped(Vector3(0.1, 0.1, 0.1))), str(w.player.seated), str(w.player.walking_to_target()),
			str(main.desktop.visible), str(main.shop.visible), str(main.ring.visible), str(main.call_view.visible), str(main.report.visible),
			str(main.pause.visible), str(main.hud.menu_open()), str(main.phone.visible), Game.comms.prompts.size(), Game.stats.get_value("energy"), int(Engine.get_frames_per_second())])
	print("AUTOPLAY %s: %s  day=%s  susp=%.0f  hp=%.0f  worked=%s  money=%s  frames=%d" % [
		_auto_diff, str(res.get("kind", "unfinished")), str(Game.time.day), float(Game.stats.values.susp),
		float(Game.stats.values.health), str(Game.week.get("worked_min", "?")), str(Game.economy.money), frames])
	var keys: Array = why.keys()
	keys.sort_custom(func(a, b): return float(why[a]) > float(why[b]))
	var top: Array = []
	for k in keys.slice(0, 9):
		top.append("%s +%.0f" % [str(k), float(why[k])])
	print("  suspicion from: ", ", ".join(top))
	var wk := Game.week
	var parts: Array = []
	for k in ["absent_min", "prompts_answered", "prompts_ignored", "meetings_attended", "meetings_missed", "calls_taken", "calls_dodged", "colleagues_ignored", "snitched", "favours_called", "excuses"]:
		parts.append("%s=%d" % [k, int(wk.get(k, 0))])
	print("  week: ", ", ".join(parts))


func _auto_step(w: World) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _auto_next:
		return
	_auto_next = now + 0.06
	if main.report.visible:
		main.report.visible = false
		main.report.done.emit()
		return
	if main.pause.visible:
		main.close_pause()
		return
	if main.call_view.visible:
		if main.call_view._waiting:
			var pick := _best(Game.comms.call_choices(), Game.comms.call_context())
			if int(pick[0]) >= 0:
				main.call_view._on_chosen(int(pick[0]), str(pick[1]))
		return
	if Game.time.phase == "evening":
		_auto_evening(w)
		return
	var ring := Game.comms.ringing()
	if not ring.is_empty() and not Game.comms.in_call():
		main.open_ring(true)
		if Game.comms.can_dodge(ring) and Game.comms.conflicts(ring):
			Game.comms.decline_conflict(str(ring.id))
		else:
			if not Game.presence.at_desk and not Game.home.phone_usable():
				_auto_goto_desk(w)
				return
			main.join_call(str(ring.id), not Game.presence.at_desk)
		return
	if main.ring.visible:
		main.ring.close()
	var pending := Game.comms.pending()
	if not pending.is_empty():
		var p: Dictionary = pending[0]
		if main.desktop.visible:
			main.desktop.open_prompt(str(p.id))
			var pick := _best(Game.comms.choices_of(p), "chat")
			if int(pick[0]) >= 0:
				Game.comms.answer(str(p.id), int(pick[0]), str(pick[1]))
			return
		if Game.home.phone_usable() and randf() < 0.3:
			main.phone.open(str(p.id))
			var pick := _best(Game.comms.choices_of(p), "chat")
			if int(pick[0]) >= 0:
				Game.home.phone_spend(6.0)
				Game.comms.answer(str(p.id), int(pick[0]), str(pick[1]))
			main.phone.close()
			return
		_auto_goto_desk(w)
		return
	if Game.activities.busy():
		return
	# Nothing urgent: desk chores or a wander.
	if main.desktop.visible:
		var r := randf()
		if r < 0.25:
			main.desktop.open_app(["teams", "tasks", "cal", "mail", "shadow"][randi() % 5])
		elif r < 0.45:
			for task in Game.work.open_tasks():
				if str(task.by) == "" and not Game.work.task_looks_done(task) and Game.stats.get_value("energy") > 40.0:
					Game.work.task_fake(str(task.id))
					break
		elif r < 0.5:
			Game.work.fake_report(false)
		elif r < 0.55:
			Game.comms.react("team")
		elif r < 0.6:
			for gid in Game.automation.gadgets:
				if Game.automation.owns(gid) and not Game.automation.working(gid) and not bool(Game.automation.g(gid).broken):
					Game.automation.toggle(gid)
		elif r < 0.63 and (Game.automation.any_broken() or Game.automation.max_wear() > 30.0):
			Game.automation.maintain()
		elif r < 0.66:
			var nm := Game.comms.next_meeting()
			if not nm.is_empty() and not bool(nm.mandatory) and not Game.comms.conflicts(nm):
				Game.comms.add_block(int(nm.start), 30)
		elif r < 0.7 or Game.stats.get_value("energy") < 35.0 or Game.stats.get_value("health") < 55.0:
			main.desktop.close()
		return
	if main.shop.visible:
		for id in Db.gadget_order():
			if Game.automation.level(id) < Game.automation.max_level(id) and Game.automation.unlocked(id) and randf() < 0.8:
				Game.automation.buy(id)
		main.shop.close()
		return
	if main.hud.menu_open():
		var t: Interactable = main.hud._menu_thing
		var opts := Game.home.options(t.thing_id)
		var ok: Array = []
		for o in opts:
			if bool(o.ok) and not Game.work.is_work(str(o.act)) and not str(o.id) in ["off", "sleep", "dock"]:
				ok.append(str(o.id))
		if ok.is_empty():
			main.hud.close_menu()
		else:
			main.hud._menu_pick(ok[randi() % ok.size()])
		return
	if w.player.walking_to_target():
		return
	if now < _auto_walk:
		return
	_auto_walk = now + 0.4
	var roll := randf()
	if not Game.automation.has("presence") and Game.automation.unlocked("mousemover") and Game.economy.can_afford(Game.automation.price("mousemover")) and roll < 0.3:
		w.interact(w.apartment.things["gaming_pc"])
	elif Game.stats.get_value("energy") < 40.0:
		w.interact(w.apartment.things[["fridge", "coffee", "microwave", "table"][randi() % 4]])
	elif Game.stats.get_value("health") < 60.0:
		w.interact(w.apartment.things[["console", "sofa", "tv"][randi() % 3]])
	elif roll < 0.5:
		_auto_goto_desk(w)
	elif roll < 0.6:
		w.rig.rotate_step(1 if randf() < 0.5 else -1)
	elif roll < 0.65:
		main.open_pause()
	elif roll < 0.7:
		main.toggle_phone()
		main.phone.close()
	else:
		var ids: Array = w.apartment.things.keys()
		var id: String = ids[randi() % ids.size()]
		if id != "router" and id != "bed":
			w.interact(w.apartment.things[id])


func _auto_goto_desk(w: World) -> void:
	if Game.activities.busy():
		Game.activities.stop()
	if main.hud.menu_open():
		main.hud.close_menu()
	if not main.desktop.visible and not w.player.walking_to_target():
		w.interact(w.apartment.things["workstation"])


func _auto_evening(w: World) -> void:
	if main.desktop.visible:
		main.desktop.close()
		return
	if main.hud.menu_open():
		var t: Interactable = main.hud._menu_thing
		if t.thing_id == "bed":
			main.hud._menu_pick("sleep")
		else:
			main.hud.close_menu()
		return
	if main.shop.visible:
		for id in Db.gadget_order():
			if not Game.automation.owns(id) and Game.automation.unlocked(id) and int(Game.economy.money) >= Game.automation.price(id) + 40:
				Game.automation.buy(id)
		main.shop.close()
		Game.set_flag("auto_shopped_%d" % int(Game.time.day))
		return
	if Game.activities.busy() or w.player.walking_to_target():
		return
	if not Game.flag("auto_shopped_%d" % int(Game.time.day)):
		w.interact(w.apartment.things["gaming_pc"])
	elif Game.stats.get_value("health") < 85.0 and float(Game.time.minute) < 1300.0:
		w.interact(w.apartment.things["console"])
	else:
		w.interact(w.apartment.things["bed"])
