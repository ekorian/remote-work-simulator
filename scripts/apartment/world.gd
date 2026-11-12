class_name World
extends Node3D
## World — the 3D scene: apartment, player, camera, day/night lighting, and
## the glue between apartment objects and the rules in Game.home.

signal focus_changed(thing: Interactable)
signal menu_requested(thing: Interactable)

const REACH := 1.25

## minute -> [sun colour, sun energy, ambient colour, ambient energy, sky colour, window colour, lamp level]
const SKY := [
	[0, Color("6f7fd0"), 0.10, Color("5560a8"), 0.55, Color("141428"), Color("1d2547"), 1.0],
	[330, Color("6f7fd0"), 0.10, Color("5560a8"), 0.55, Color("161630"), Color("222b55"), 1.0],
	[420, Color("ffb37a"), 0.75, Color("d9b3b8"), 0.70, Color("f2b596"), Color("ffd6ae"), 0.35],
	[540, Color("fff1d6"), 0.98, Color("d6e4ff"), 0.66, Color("a9d6f2"), Color("cdeaff"), 0.0],
	[840, Color("fffaf0"), 1.05, Color("dbe8ff"), 0.70, Color("9fd0f0"), Color("d6efff"), 0.0],
	[990, Color("ffd9a6"), 0.98, Color("f2d9cc"), 0.66, Color("f6c79a"), Color("ffdcae"), 0.0],
	[1080, Color("ff9d6b"), 0.80, Color("d9a9b3"), 0.68, Color("e9907a"), Color("ffb38a"), 0.45],
	[1170, Color("8f7fd0"), 0.25, Color("7a6fb8"), 0.60, Color("3d3466"), Color("6a5aa8"), 0.9],
	[1260, Color("6f7fd0"), 0.10, Color("5560a8"), 0.55, Color("16162e"), Color("222b55"), 1.0],
	[1640, Color("6f7fd0"), 0.10, Color("5560a8"), 0.55, Color("141428"), Color("1d2547"), 1.0],
]

var apartment: Apartment
var player: Player
var rig: CameraRig
var sun: DirectionalLight3D
var env: Environment
var focused: Interactable
var hovered: Interactable
var interactive := true            ## false in menus / while a UI overlay owns input
var demo := false                  ## main-menu backdrop
var demo_minute := 600.0
var _lamp_base: Array = []
var _t := 0.0
var _pending_thing: Interactable
var _using: Interactable
var _at_desktop := false
var _ring_flash := 0.0


func _ready() -> void:
	_environment()
	apartment = $Apartment
	player = $Player
	rig = $CameraRig
	for l in apartment.lamps:
		_lamp_base.append((l as OmniLight3D).light_energy)
	# Diorama base.
	Kit.cyl(self, 12.5, 0.5, Vector3(0, -0.58, 0), Color("3a3260"), 48)
	Kit.cyl(self, 13.2, 0.3, Vector3(0, -0.95, 0), Color("2b2542"), 48)
	player.apartment = apartment
	rig.target = player
	player.blocked.connect(func(): _pending_thing = null)
	Bus.activity_started.connect(_on_activity_started)
	Bus.activity_ended.connect(_on_activity_ended)
	Bus.state_loaded.connect(sync_from_state)
	Bus.desktop_opened.connect(_on_desktop_opened)
	Bus.desktop_closed.connect(_on_desktop_closed)
	Game.day_started.connect(_on_day_started)
	Game.saves.about_to_save.connect(_store_position)
	place_player(Vector3(3.0, 0, -3.6), PI * 0.5)
	rig.snap_to(player.global_position + Vector3(0, 0.9, 0))


func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a9d6f2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d6e4ff")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.6
	env.ssao_enabled = true
	env.ssao_radius = 0.7
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_blur = 1.6
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.light_angular_distance = 1.5
	add_child(sun)


# ---------------------------------------------------------------------------
# State sync
# ---------------------------------------------------------------------------

func place_player(p: Vector3, yaw: float) -> void:
	player.stand_up()
	player.stop()
	player.global_position = Vector3(p.x, 0, p.z)
	player.rotation = Vector3(0, yaw, 0)
	player.velocity = Vector3.ZERO


func sync_from_state() -> void:
	## Called after new_run / load: put the body where the save says it is.
	if not Game.active:
		return
	_at_desktop = false
	_using = null
	player.body.set_look(Game.player, str(Game.home.outfit))
	var pos: Array = Game.player_pos
	if pos.size() >= 3:
		place_player(Vector3(float(pos[0]), 0, float(pos[1])), float(pos[2]))
	else:
		place_player(Vector3(3.0, 0, -3.6), PI * 0.5)
	rig.snap_to(player.global_position + Vector3(0, 0.9, 0))
	if Game.activities.busy():
		_on_activity_started(Game.activities.current)
	elif Game.presence.at_desk:
		Game.presence.set_at_desk(false)


func _store_position() -> void:
	if not Game.active:
		return
	var p := player.global_position
	if player.seated and _using != null:
		p = _using.use_point()
	Game.player_pos = [p.x, p.z, player.rotation.y]


func _on_day_started(_day: int) -> void:
	if not Game.active:
		return
	player.body.set_look(Game.player, str(Game.home.outfit))
	if int(Game.time.day) > 0:
		# Wake up next to the bed.
		_using = null
		_at_desktop = false
		place_player(apartment.things["bed"].use_point(), PI * 0.5)
		rig.snap_to(player.global_position + Vector3(0, 0.9, 0))


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func nearest_thing() -> Interactable:
	var best: Interactable = null
	var best_d := REACH
	var pp := player.global_position
	for id in apartment.things:
		var t: Interactable = apartment.things[id]
		var d := pp.distance_to(t.use_point())
		# Standing right against the object also counts.
		var c := t.global_position
		d = minf(d, Vector2(pp.x - c.x, pp.z - c.z).length() - 0.35)
		if d < best_d:
			best_d = d
			best = t
	return best


func interact(t: Interactable) -> void:
	## Walk to an object (if needed) and use it or open its menu.
	if t == null or not Game.active or Game.activities.busy() or _at_desktop:
		return
	var up := t.use_point()
	if player.global_position.distance_to(up) > 0.45:
		_pending_thing = t
		if not player.go_to(up, _arrived_at.bind(t)):
			_pending_thing = null
			Bus.toast.emit("Can't get there from here.", "warn")
		return
	_arrived_at(t)


func _arrived_at(t: Interactable) -> void:
	_pending_thing = null
	if not Game.active or Game.activities.busy():
		return
	player.face(t.focus_point())
	var opts := Game.home.options(t.thing_id)
	if opts.is_empty():
		return
	_using = t
	if opts.size() == 1 and bool(opts[0].ok):
		Game.home.use(t.thing_id, str(opts[0].id))
		after_use(t)
	else:
		menu_requested.emit(t)


func choose(t: Interactable, opt_id: String) -> void:
	_using = t
	if Game.home.use(t.thing_id, opt_id):
		after_use(t)


func after_use(t: Interactable) -> void:
	## Visual follow-up for instant (non-timed) options.
	if not Game.active:
		return
	player.body.set_outfit(str(Game.home.outfit))
	if not Game.activities.busy() and not _at_desktop:
		player.pose("use")
		get_tree().create_timer(0.45).timeout.connect(func():
			if is_instance_valid(player) and not player.seated and player.body.anim == "use":
				player.pose("idle")
		)
	if t.thing_id == focused_id():
		focus_changed.emit(focused)


func focused_id() -> String:
	return focused.thing_id if focused != null else ""


func _seat_player(t: Interactable, anim: String) -> void:
	if t != null and not t.seat.is_empty():
		player.sit(t.seat_transform(), bool(t.seat.get("lie", false)), anim)
	else:
		player.stop()
		player.pose(anim)
		if t != null:
			player.face(t.focus_point())


func _on_activity_started(a: Dictionary) -> void:
	var id := str(a.get("thing", ""))
	var t: Interactable = apartment.things.get(id)
	if t == null:
		t = _using
	if id == "" and _at_desktop:
		return                                  # working at the desk: already seated
	if _at_desktop and id == "workstation":
		player.body.anim = "type"
		return
	_using = t
	var anim := str(a.get("anim", "idle"))
	if anim == "sleep" and t != null and t.thing_id == "bed":
		_seat_player(t, "sleep")
	else:
		_seat_player(t, anim)
	Game.presence.set_at_desk(t != null and t.thing_id == "chair")


func _on_activity_ended(a: Dictionary, _completed: bool) -> void:
	if _at_desktop:
		player.body.anim = "type"
		return
	if str(a.get("id", "")) == "desk_nap":
		Game.presence.set_at_desk(false)
	if player.seated:
		player.stand_up(_using.use_point() if _using != null else Vector3.INF)
	player.pose("idle")
	player.body.set_outfit(str(Game.home.outfit) if Game.active else "casual")


func _on_desktop_opened() -> void:
	_at_desktop = true
	var t: Interactable = apartment.things["workstation"]
	_using = t
	player.sit(t.seat_transform(), false, "type")
	rig.close_up = true


func _on_desktop_closed() -> void:
	_at_desktop = false
	rig.close_up = false
	if Game.active and Game.activities.busy():
		return
	if player.seated:
		player.stand_up(apartment.things["workstation"].use_point())
	player.pose("idle")


func sit_at(thing_id: String, anim: String) -> void:
	## Used by the shop: sit somewhere without an activity.
	var t: Interactable = apartment.things[thing_id]
	_using = t
	_seat_player(t, anim)


func leave_seat() -> void:
	if player.seated and not Game.activities.busy():
		player.stand_up(_using.use_point() if _using != null else Vector3.INF)
		player.pose("idle")


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _pick(screen: Vector2) -> Dictionary:
	var from := rig.cam.project_ray_origin(screen)
	var dir := rig.cam.project_ray_normal(screen)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.collision_mask = Interactable.PICK_LAYER | 1
	return get_world_3d().direct_space_state.intersect_ray(q)


func _thing_under(screen: Vector2) -> Interactable:
	var from := rig.cam.project_ray_origin(screen)
	var dir := rig.cam.project_ray_normal(screen)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = Interactable.PICK_LAYER
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	return hit.collider.get_meta("thing", null)


func _unhandled_input(e: InputEvent) -> void:
	if demo or not interactive or not Game.active or Game.paused:
		return
	if e.is_action_pressed("interact"):
		if Game.activities.busy():
			Game.activities.stop()
		elif focused != null:
			interact(focused)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if Game.activities.busy():
			return
		var t := _thing_under(e.position)
		if t != null:
			interact(t)
			Bus.sfx.emit("click")
		else:
			var hit := _pick(e.position)
			if not hit.is_empty():
				var p: Vector3 = hit.position
				if absf(p.y) < 0.4:
					player.go_to(Vector3(p.x, 0, p.z))
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	player.cam_yaw = rig.yaw
	var playing := Game.active and not demo
	player.controllable = playing and interactive and not Game.paused and not Game.activities.busy() and not _at_desktop
	rig.input_enabled = playing and interactive and not Game.paused
	_update_focus(playing)
	_update_walls(delta)
	_update_sky(delta)
	_update_props(delta, playing)
	rig.shake = 0.0
	if playing and Game.stats.has_buff("wired") and not _at_desktop and bool(Prefs.get_v("shake")):
		rig.shake = 0.6


func _update_focus(playing: bool) -> void:
	var want: Interactable = null
	var hover: Interactable = null
	if playing and interactive and not Game.paused and not Game.activities.busy() and not _at_desktop and not player.seated:
		hover = _thing_under(get_viewport().get_mouse_position())
		if _pending_thing != null and player.walking_to_target():
			want = _pending_thing
		else:
			want = nearest_thing()
	if hover != hovered:
		if hovered != null and hovered != focused:
			hovered.set_highlight(false)
		hovered = hover
	if want != focused:
		if focused != null and focused != hovered:
			focused.set_highlight(false)
		focused = want
		focus_changed.emit(focused)
	if focused != null:
		focused.set_highlight(true)
	if hovered != null:
		hovered.set_highlight(true)


func _update_walls(delta: float) -> void:
	var to_cam := rig.to_camera_dir()
	for side in apartment.outer:
		var d: Dictionary = apartment.outer[side]
		var facing: float = (d.normal as Vector3).dot(to_cam)
		var tall: Node3D = d.tall
		var low: Node3D = d.low
		var want_tall := facing < 0.1
		var target := 1.0 if want_tall else 0.02
		tall.scale.y = lerpf(tall.scale.y, target, minf(1.0, delta * 9.0))
		tall.visible = tall.scale.y > 0.05
		low.visible = not tall.visible


func _sky_at(minute: float) -> Array:
	var m := fposmod(minute, 1440.0)
	if minute >= 1440.0:
		m = minute
	for i in range(SKY.size() - 1):
		var a: Array = SKY[i]
		var b: Array = SKY[i + 1]
		if m >= float(a[0]) and m <= float(b[0]):
			var f := (m - float(a[0])) / maxf(1.0, float(b[0]) - float(a[0]))
			f = smoothstep(0.0, 1.0, f)
			return [
				(a[1] as Color).lerp(b[1], f), lerpf(a[2], b[2], f), (a[3] as Color).lerp(b[3], f),
				lerpf(a[4], b[4], f), (a[5] as Color).lerp(b[5], f), (a[6] as Color).lerp(b[6], f), lerpf(a[7], b[7], f),
			]
	return SKY[0].slice(1)


func _update_sky(delta: float) -> void:
	var minute := demo_minute
	if Game.active and not demo:
		minute = Game.time.clock()
	var k: Array = _sky_at(minute)
	sun.light_color = k[0]
	sun.light_energy = k[1]
	env.ambient_light_color = k[2]
	env.ambient_light_energy = k[3]
	env.background_color = k[4]
	# The sun arcs from the east in the morning to the west in the evening.
	var day_f := clampf((fposmod(minute, 1440.0) - 360.0) / 840.0, 0.0, 1.0)
	var azimuth := lerpf(deg_to_rad(-70.0), deg_to_rad(110.0), day_f)
	var elevation := deg_to_rad(28.0 + 30.0 * sin(day_f * PI))
	sun.rotation = Vector3(-elevation, azimuth, 0)
	for m in apartment.window_mats:
		var wm: StandardMaterial3D = m
		wm.albedo_color = k[5]
		wm.emission = k[5]
		wm.emission_energy_multiplier = 0.45 + 0.4 * float(k[1])
	var lamp_level := float(k[6])
	for i in apartment.lamps.size():
		var l: OmniLight3D = apartment.lamps[i]
		l.light_energy = lerpf(l.light_energy, float(_lamp_base[i]) * lamp_level, minf(1.0, delta * 3.0))
		l.visible = l.light_energy > 0.02


func _update_props(delta: float, playing: bool) -> void:
	var p: Dictionary = apartment.parts
	var act := str(Game.activities.current.get("id", "")) if playing and Game.activities.busy() else ""
	var router_on := true
	var jiggler := false
	var bird := false
	var docked := false
	var updating := false
	var ringing := false
	if playing:
		router_on = Game.home.router_on()
		jiggler = Game.automation.can("presence")
		bird = Game.automation.can("illusion")
		docked = not Game.home.phone_carried()
		updating = Game.home.laptop_updating()
		ringing = not Game.comms.ringing().is_empty()
		(p.jiggler as Node3D).visible = Game.automation.has("presence")
		(p.bird as Node3D).visible = Game.automation.has("illusion")
	else:
		(p.jiggler as Node3D).visible = false
		(p.bird as Node3D).visible = false
	# Router LEDs
	var leds: Array = p.router_leds
	for i in leds.size():
		var lm: StandardMaterial3D = leds[i]
		var on := router_on and (i == 0 or sin(_t * (5.0 + i * 2.3) + i) > -0.3)
		lm.emission = Color("5ad17a") if router_on else Color("ff5d73")
		lm.albedo_color = lm.emission
		lm.emission_energy_multiplier = 3.0 if on else (0.6 if not router_on and i == 0 else 0.0)
	(p.router_plug as Node3D).position.x = lerpf((p.router_plug as Node3D).position.x, 0.26 if router_on else 0.42, minf(1.0, delta * 10.0))
	# Mouse jiggler and desk bird
	var mouse: Node3D = p.mouse
	if jiggler:
		mouse.position = Vector3(0.3 + cos(_t * 4.0) * 0.035, 0.045, sin(_t * 4.0) * 0.035)
	else:
		mouse.position = mouse.position.lerp(Vector3(0.3, 0.02, 0), minf(1.0, delta * 8.0))
	var tilt: Node3D = p.bird_tilt
	tilt.rotation.x = (0.55 + sin(_t * 5.0) * 0.5) if bird else lerpf(tilt.rotation.x, 0.0, minf(1.0, delta * 6.0))
	# Phone on the charger
	(p.phone as Node3D).visible = docked
	var cl: StandardMaterial3D = p.charger_led
	cl.emission = Color("ffd166") if docked else Color("5ad17a")
	cl.emission_energy_multiplier = (1.5 + sin(_t * 3.0)) if docked else 0.6
	# Screens
	var ws: StandardMaterial3D = p.work_screen
	_ring_flash = lerpf(_ring_flash, 1.0 if ringing else 0.0, minf(1.0, delta * 8.0))
	var base := Color("3b5bdb") if router_on else Color("39405c")
	var flash := Color("ff5d73").lerp(Color("ffd166"), 0.5 + 0.5 * sin(_t * 12.0))
	ws.emission = base.lerp(flash, _ring_flash)
	ws.albedo_color = ws.emission
	var ls: StandardMaterial3D = p.laptop_screen
	ls.emission = Color("b48cff").lerp(Color("4fb3ff"), 0.5 + 0.5 * sin(_t * 2.0)) if updating else Color("3b5bdb")
	ls.albedo_color = ls.emission
	var gs: StandardMaterial3D = p.game_screen
	gs.emission = Color.from_hsv(fposmod(_t * 0.08, 1.0), 0.55, 1.0)
	gs.albedo_color = gs.emission
	var tv_on := act == "tv" or act == "console"
	var ts: StandardMaterial3D = p.tv_screen
	var tv_col := Color.from_hsv(fposmod(_t * (0.9 if act == "console" else 0.23), 1.0), 0.5, 1.0)
	ts.emission = tv_col if tv_on else Color("15131f")
	ts.albedo_color = ts.emission
	ts.emission_energy_multiplier = 1.8 if tv_on else 0.1
	var tl: OmniLight3D = p.tv_light
	tl.light_energy = lerpf(tl.light_energy, 1.6 if tv_on else 0.0, minf(1.0, delta * 6.0))
	tl.light_color = tv_col
	tl.visible = tl.light_energy > 0.02
	# Kitchen
	var md: StandardMaterial3D = p.microwave_door
	md.emission = Color("ffd166") if act == "burrito" else Color("2f2c3e")
	md.albedo_color = md.emission
	md.emission_energy_multiplier = 2.4 if act == "burrito" else 0.05
	var steam: Node3D = p.steam
	steam.visible = act == "brew"
	if steam.visible:
		steam.position.y = 0.3 + fmod(_t * 0.25, 0.14)
	(p.coffee_led as StandardMaterial3D).emission_energy_multiplier = (2.0 + sin(_t * 9.0) * 2.0) if act == "brew" else 1.2
	# Printer
	var paper: Node3D = p.printer_paper
	paper.position.z = 0.3 + (fmod(_t * 0.5, 0.12) if act == "forge" else 0.0)
	var pl: StandardMaterial3D = p.printer_led
	var jam := playing and bool(Game.home.things.get("jam", false))
	pl.emission = Color("ff5d73") if jam else Color("5ad17a")
	pl.albedo_color = pl.emission
	pl.emission_energy_multiplier = (2.0 + sin(_t * 10.0) * 2.0) if jam else 2.0
	# Exercise bike
	if act == "workout":
		(p.bike_wheel as Node3D).rotate_object_local(Vector3.UP, delta * 14.0)
