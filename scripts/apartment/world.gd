class_name World
extends Node3D
## World — the flat as you see it: first person, from inside. It owns the
## lighting, what the crosshair is on, the thing in your hand, and the glue
## between apartment objects and the rules in Game.home.

signal focus_changed(thing: Interactable)
signal menu_requested(thing: Interactable)

const REACH := 2.1               ## how far the crosshair reaches
const THROW := 6.5
const SOLID := 1

const LINES := 1080.0            ## the "pixel" setting is the size of one picture square on a 1080-line screen
const HAZE_IN := 0.024           ## fog density indoors
const HAZE_OUT := 0.017          ## and in the street, where there is further to see
const BAND := Color("cdc48c")    ## the light left along the horizon at dawn and dusk

## minute -> [sun colour, sun energy, ambient colour, ambient energy, sky overhead, sky at the horizon,
##            horizon glow, window colour, lamp level]
## An overcast town: the day is grey, and the only real colour in the sky is at either end of it.
const SKY := [
	[0, Color("5a6a8a"), 0.08, Color("3d4758"), 0.56, Color("0e1219"), Color("1c232b"), 0.0, Color("1a212e"), 1.0],
	[330, Color("5a6a8a"), 0.08, Color("3d4758"), 0.56, Color("10141c"), Color("1f262e"), 0.0, Color("1d2532"), 1.0],
	[420, Color("d9b48e"), 0.56, Color("868c8a"), 0.64, Color("434f5c"), Color("7d8a88"), 0.90, Color("c9c2a6"), 0.35],
	[540, Color("e6e2d2"), 0.74, Color("9aa49e"), 0.66, Color("4f5e69"), Color("86948f"), 0.35, Color("c5d0ce"), 0.0],
	[840, Color("ece8da"), 0.78, Color("9ea8a1"), 0.68, Color("526270"), Color("8b9892"), 0.25, Color("cbd5d2"), 0.0],
	[990, Color("e2d2b2"), 0.72, Color("9a9e95"), 0.66, Color("4b5a67"), Color("858f86"), 0.60, Color("cfcdb4"), 0.0],
	[1080, Color("c99c7a"), 0.52, Color("7e8587"), 0.64, Color("3d4a58"), Color("727f7c"), 1.0, Color("bfb48e"), 0.45],
	[1170, Color("6a7696"), 0.20, Color("545e6e"), 0.60, Color("252d39"), Color("48535e"), 0.40, Color("495365"), 0.9],
	[1260, Color("5a6a8a"), 0.08, Color("3d4758"), 0.56, Color("10141c"), Color("1f262e"), 0.0, Color("1d2532"), 1.0],
	[1640, Color("5a6a8a"), 0.08, Color("3d4758"), 0.56, Color("0e1219"), Color("1c232b"), 0.0, Color("1a212e"), 1.0],
]

var apartment: Apartment
var player: Player
var stage: Camera3D                ## looks at you from outside, for the menus
var sun: DirectionalLight3D
var env: Environment
var sky: MeshInstance3D            ## a dome that goes wherever the camera goes
var focused: Interactable          ## the object under the crosshair
var focused_item: Holdable         ## the loose item under the crosshair
var held: Holdable                 ## what is in your hand
var bodies: Dictionary = {}        ## item id -> Holdable
var people: Array = []             ## TownPerson: everybody out in the street
var wares: Array = []              ## Area3D on the shop shelves: look at one to buy it
var focused_person: TownPerson
var focused_ware: Dictionary = {}  ## {shop, what} under the crosshair
var _door := 0.0                   ## how far open the front door is (0..1)
var _tick := 0.0
var interactive := true            ## false in menus / while a UI overlay owns input
var demo := false                  ## main-menu backdrop
var demo_minute := 600.0
var view := "play"                 ## play | menu | setup
var _lamp_base: Array = []
var _ceiling_base: Array = []
var _t := 0.0
var _pending_thing: Interactable
var _using: Interactable
var _at_desktop := false
var _ring_flash := 0.0
var _stage_from := Vector3.ZERO
var _stage_at := Vector3.ZERO
var _sky_mat: ShaderMaterial
var _outside := 0.0                ## 0 indoors .. 1 in the street, eased, for the haze


func _ready() -> void:
	_environment()
	apartment = $Apartment
	player = $Player
	for l in apartment.lamps:
		_lamp_base.append((l as OmniLight3D).light_energy)
	for l in apartment.ceiling_lights:
		_ceiling_base.append((l as OmniLight3D).light_energy)
	for area in apartment.bins:
		(area as Area3D).body_entered.connect(_on_binned)
	(apartment.parts["hoop_ring"] as Area3D).body_entered.connect(_on_hoop)
	for i in Town.PEOPLE.size():
		var person := TownPerson.new()
		add_child(person)
		person.setup(Town.PEOPLE[i], i)
		people.append(person)
	player.apartment = apartment
	stage = Camera3D.new()
	stage.fov = 46.0
	stage.near = 0.05
	stage.far = 160.0
	add_child(stage)
	_build_sky()
	apply_prefs()
	Prefs.changed.connect(apply_prefs)
	get_viewport().size_changed.connect(apply_prefs)
	player.blocked.connect(func(): _pending_thing = null)
	Bus.activity_started.connect(_on_activity_started)
	Bus.activity_ended.connect(_on_activity_ended)
	Bus.state_loaded.connect(sync_from_state)
	Bus.desktop_opened.connect(_on_desktop_opened)
	Bus.desktop_closed.connect(_on_desktop_closed)
	Bus.items_changed.connect(_sync_items)
	Bus.item_bitten.connect(_on_bitten)
	Game.day_started.connect(_on_day_started)
	Game.saves.about_to_save.connect(_store_position)
	place_player(Vector3(3.0, 0, -3.6), PI * 0.5)
	set_view("play")


func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a9b3ad")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.ambient_light_color = Color("a2aca5")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.9
	# No bloom, no contact shadows, no line art: flat faces, and a haze that
	# takes the far side of every room.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color("656b67")
	env.fog_density = HAZE_IN
	env.fog_sun_scatter = 0.0
	env.fog_aerial_perspective = 0.0
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.94
	env.adjustment_contrast = 0.97
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Indoors the "sun" is the daylight that fills a room: it comes from the
	# window side and casts no shadows (the ceiling lamps do that).
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = false
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_blur = 1.4
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.4
	add_child(sun)


func _build_sky() -> void:
	## The sky is a dome that travels with the camera: slate overhead, paler
	## towards the ground, with a band of leftover light along the horizon.
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 top : source_color = vec3(0.31, 0.36, 0.42);
uniform vec3 low : source_color = vec3(0.56, 0.60, 0.58);
uniform vec3 band : source_color = vec3(0.79, 0.75, 0.54);
uniform float band_amount = 0.0;
varying vec3 dir;

void vertex() {
	dir = VERTEX;
}

void fragment() {
	float h = normalize(dir).y;
	vec3 c = mix(low, top, smoothstep(0.0, 0.46, h));
	c = mix(c, band, band_amount * exp(-max(h, 0.0) * 6.0));
	c = mix(c, low * 0.72, clamp(-h * 3.0, 0.0, 1.0));
	ALBEDO = c;
}
"""
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = sh
	var ball := SphereMesh.new()
	ball.radius = 130.0
	ball.height = 260.0
	ball.radial_segments = 20
	ball.rings = 10
	sky = MeshInstance3D.new()
	sky.mesh = ball
	sky.material_override = _sky_mat
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.extra_cull_margin = 16384.0
	add_child(sky)


func apply_prefs() -> void:
	player.sensitivity = 0.0009 + 0.0034 * float(Prefs.get_v("look"))
	player.bob = bool(Prefs.get_v("shake"))
	player.camera.fov = float(Prefs.get_v("fov"))
	# A small picture, blown up: every pixel of the 3D view is a square of
	# `block` screen pixels. The interface on top stays sharp.
	var port := get_viewport()
	var block := block_for(float(Prefs.get_v("pixel")), port.size.y)
	port.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST if block > 1 else Viewport.SCALING_3D_MODE_BILINEAR
	port.scaling_3d_scale = 1.0 / float(block)
	port.msaa_3d = Viewport.MSAA_DISABLED if block > 1 else Viewport.MSAA_2X


static func block_for(pixel: float, screen_lines: int) -> int:
	## How many screen pixels across one square of the picture is: the "pixel"
	## setting on a 1080-line screen, more on a bigger one, never less than 1.
	return maxi(1, int(round(pixel * float(screen_lines) / LINES)))


func cam() -> Camera3D:
	return player.camera if view == "play" else stage


# ---------------------------------------------------------------------------
# Views
# ---------------------------------------------------------------------------

func set_view(v: String) -> void:
	## "play": through your eyes. "menu" and "setup": a camera on you.
	view = v
	var first_person := v == "play"
	player.body.visible = not first_person
	player.hand.visible = first_person
	if first_person:
		player.camera.make_current()
		return
	if v == "menu":
		# You, on the sofa, in the right-hand half of the frame.
		_stage_from = Vector3(-5.75, 1.36, 5.25)
		_stage_at = Vector3(-4.8, 0.74, 2.3)
		stage.fov = 48.0
	else:
		var p := player.global_position
		var f := -player.global_transform.basis.z
		_stage_from = p + f * 3.3 + Vector3(0, 1.25, 0)
		_stage_at = p + Vector3(0, 0.9, 0)
		stage.fov = 38.0
	stage.global_position = _stage_from
	stage.look_at(_stage_at, Vector3.UP)
	stage.make_current()


func place_player(p: Vector3, yaw: float) -> void:
	player.stand_up()
	player.stop()
	player.global_position = Vector3(p.x, 0, p.z)
	player.set_view(yaw, 0.0)
	player.velocity = Vector3.ZERO


func sync_from_state() -> void:
	## Called after new_run / load: put the body where the save says it is.
	if not Game.active:
		return
	_at_desktop = false
	_using = null
	player.body.set_look(Game.player, str(Game.home.outfit))
	player.dress(Game.player, str(Game.home.outfit))
	var pos: Array = Game.player_pos
	if pos.size() >= 3:
		place_player(Vector3(float(pos[0]), 0, float(pos[1])), float(pos[2]))
		if pos.size() >= 4:
			player.set_view(float(pos[2]), float(pos[3]))
	else:
		place_player(Vector3(3.0, 0, -3.6), PI * 0.5)
	_sync_items(true)
	_stock_shelves()
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
	Game.player_pos = [p.x, p.z, player.rotation.y, player.pitch]
	# Where everything was left lying.
	for id in bodies:
		var b: Holdable = bodies[id]
		var it := Game.home.item(str(id))
		if it.is_empty() or b.carried:
			continue
		var q := b.global_transform.basis.get_rotation_quaternion()
		var o := b.global_position
		it.at = [o.x, o.y, o.z, q.x, q.y, q.z, q.w]


func _on_day_started(_day: int) -> void:
	if not Game.active:
		return
	player.body.set_look(Game.player, str(Game.home.outfit))
	_stock_shelves()
	if int(Game.time.day) > 0:
		# Wake up next to the bed.
		_using = null
		_at_desktop = false
		place_player(apartment.things["bed"].use_point(), PI * 0.5)


# ---------------------------------------------------------------------------
# Loose items
# ---------------------------------------------------------------------------

func _sync_items(reset: bool = false) -> void:
	## Bring the bodies in the flat in line with Game.home.items.
	if reset:
		for id in bodies:
			(bodies[id] as Holdable).queue_free()
		bodies.clear()
		held = null
		player.carried_size = Vector3.ZERO
	if not Game.active:
		return
	var seen := {}
	for it in Game.home.items:
		var id := str(it.id)
		if id in Game.home.pockets:
			continue                    # in a pocket: nothing to see
		seen[id] = true
		var b: Holdable = bodies.get(id)
		if b == null:
			b = _spawn(it)
		else:
			b.refresh(it)
	for id in bodies.keys():
		if not seen.has(id):
			var gone: Holdable = bodies[id]
			if gone == held:
				held = null
				player.carried_size = Vector3.ZERO
			if gone == focused_item:
				focused_item = null
			bodies.erase(id)
			gone.queue_free()
	# The hand follows the rules: Game.home.held is the truth.
	var want: Holdable = bodies.get(Game.home.held)
	if want != held:
		if held != null:
			_release_body(held, Vector3.ZERO)
		if want != null:
			_take_body(want)
	if held != null:
		player.carried_size = held.size
	player.show_arm(held != null)


func _spawn(it: Dictionary) -> Holdable:
	var b := Holdable.new()
	add_child(b)
	b.setup(it)
	bodies[str(it.id)] = b
	var at: Array = it.get("at", [])
	var spot := str(it.get("spot", ""))
	if at.size() >= 7:
		b.global_transform = Transform3D(Basis(Quaternion(float(at[3]), float(at[4]), float(at[5]), float(at[6]))), Vector3(float(at[0]), float(at[1]), float(at[2])))
		b.freeze = true
	elif apartment.spots.has(spot):
		b.global_position = apartment.spots[spot]
		b.rotation.y = fposmod(float(str(it.id).hash() % 628) / 100.0, TAU)
		b.freeze = true                 # resting where it was put: it wakes when touched
	else:
		# No place for it: it turns up at your feet.
		b.global_position = player.global_position + (-player.global_transform.basis.z) * 0.6 + Vector3(0, 0.6, 0)
	return b


func _take_body(b: Holdable) -> void:
	held = b
	b.pick_up()
	b.reparent(player.hand, false)
	b.position = Vector3(0, -b.size.y * 0.5, 0)
	b.rotation = Vector3.ZERO
	player.carried_size = b.size
	player.show_arm(true)


func _release_body(b: Holdable, velocity: Vector3, spin: Vector3 = Vector3.ZERO) -> void:
	var xf := b.global_transform
	b.reparent(self, false)
	b.global_transform = xf
	b.let_go(velocity, spin)
	if held == b:
		held = null
		player.carried_size = Vector3.ZERO
		player.show_arm(false)


func pick_up(b: Holdable) -> bool:
	## Take a loose item. What you were holding goes in a pocket, or on the floor.
	if b == null or not Game.active or b.carried:
		return false
	if held != null and Game.home.fits_pocket(Game.home.item(held.item_id)) != "":
		put_down()
	if not Game.home.hold(b.item_id):
		return false
	Bus.sfx.emit("pickup")
	return true


func stow_held() -> void:
	## R: put what you are holding away, or take the next thing out.
	if held != null:
		Game.home.stow(held.item_id)
	else:
		Game.home.cycle(1)


func _on_hoop(body: Node) -> void:
	var b := body as Holdable
	if b != null and not b.carried and b.model == "basketball" and b.linear_velocity.y < 0.0 and Game.active:
		Game.home.hoop()


func _stock_shelves() -> void:
	## Put today's goods on the shop shelves. Each one can be bought by looking at it.
	for w in wares:
		(w as Node).queue_free()
	wares.clear()
	if not Game.active:
		return
	for shop in Home.SHOPS:
		var slots: Array = apartment.parts.get("slots_" + str(shop), [])
		var stock := Game.home.shop_stock(str(shop))
		for i in mini(slots.size(), stock.size()):
			var what := str(stock[i])
			var slot: Dictionary = slots[i]
			var holder := Kit.node(self, slot.pos)
			holder.rotation_degrees.y = float(slot.yaw)
			var tint: Color = Db.foods[what].tint if Db.foods.has(what) else Color("5ad1c8")
			var model := str(Db.foods[what].model) if Db.foods.has(what) else what
			var built := FoodKit.build(model, holder, tint)
			var size: Vector3 = built.size
			var fit := clampf(0.34 / maxf(maxf(size.x, size.z), size.y), 0.9, 2.2)
			(built.root as Node3D).scale = Vector3.ONE * fit
			var tag := Label3D.new()
			tag.text = "$%d" % Game.home.price_of(what)
			tag.font_size = 48
			tag.pixel_size = 0.0026
			tag.outline_size = 10
			tag.modulate = Color("fff6e0")
			tag.outline_modulate = Color("2f2c3e")
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.no_depth_test = false
			tag.position = Vector3(0, size.y * fit + 0.09, 0)
			holder.add_child(tag)
			var area := Area3D.new()
			area.collision_layer = Interactable.PICK_LAYER
			area.collision_mask = 0
			area.monitoring = false
			area.set_meta("ware", {"shop": str(shop), "what": what, "node": holder, "stand": slot.stand})
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.5, 0.42, 0.5)
			cs.shape = shape
			cs.position = Vector3(0, 0.18, 0)
			area.add_child(cs)
			holder.add_child(area)
			wares.append(holder)


func talk_to(person: TownPerson) -> void:
	## E on somebody: give them what you are holding if they would want it, else chat.
	if person == null or not Game.active:
		return
	person.turn_to(player.global_position)
	if held != null and person.npc != "" and Game.social.is_colleague(person.npc):
		var it := Game.home.item(held.item_id)
		if not bool(it.get("trash", false)) and Game.social.give(person.npc, held.item_id):
			person.speak()
			Bus.toast.emit("%s: \"For me? You shouldn't have. You should do it again.\"" % Game.npcs.first_name(person.npc), "good")
			return
	var line := person.speak()
	var voice := Game.npcs.voice(person.npc) if person.npc != "" else ""
	if voice != "":
		Sfx.voice(voice)
	else:
		Bus.sfx.emit("talk")
	Bus.toast.emit("%s: \"%s\"" % [person.title.get_slice(" ", 0) if person.npc != "" else person.title, Game.comms.fmt(line)], "info")


func buy_ware(ware: Dictionary) -> bool:
	if ware.is_empty() or not Game.active:
		return false
	var shop := str(ware.shop)
	if not Game.home.shop_open(shop):
		Bus.toast.emit("%s is closed." % str(Home.SHOPS[shop].name), "warn")
		return false
	if not Game.economy.can_afford(Game.home.price_of(str(ware.what))):
		Bus.toast.emit("You can't afford that.", "warn")
		return false
	return not Game.home.buy(shop, str(ware.what)).is_empty()


func _drop_point() -> Dictionary:
	## Where the thing in your hand would be set down: {pos, on_surface}.
	var from := player.eye_position()
	var to := from + player.aim() * 1.5
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = SOLID
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {"pos": to, "on_surface": false}
	var n: Vector3 = hit.normal
	if n.y > 0.6:
		return {"pos": hit.position, "on_surface": true}
	return {"pos": (hit.position as Vector3) + n * 0.12, "on_surface": false}


func put_down() -> void:
	## Set the held item down where you are looking (or let it drop).
	if held == null:
		return
	var b := held
	var spot := _drop_point()
	Game.home.release()
	if held == b:
		_release_body(b, Vector3.ZERO)
	var pos: Vector3 = spot.pos
	b.global_position = pos + Vector3(0, 0.01 if bool(spot.on_surface) else 0.0, 0)
	b.rotation = Vector3(0, player.rotation.y + PI, 0)
	b.linear_velocity = Vector3.ZERO
	Bus.sfx.emit("putdown")


func throw_held() -> void:
	if held == null:
		return
	var b := held
	var dir := player.aim()
	Game.home.release()
	if held == b:
		_release_body(b, Vector3.ZERO)
	b.global_position = player.eye_position() + dir * 0.45 + Vector3(0, -0.12, 0)
	b.let_go(dir * THROW + Vector3(0, 1.6, 0) + player.velocity, Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5)))
	b.set_meta("thrown_from", player.global_position)
	player.bite()
	Bus.sfx.emit("whoosh")


func use_held() -> void:
	## The main thing you do with what is in your hand: eat it, squeeze it.
	if held == null or not Game.active or Game.paused:
		return
	var it := Game.home.item(held.item_id)
	if it.is_empty():
		return
	if Game.home.is_prop(it):
		if Game.home.fidget(held.item_id):
			player.bite()
		return
	if bool(it.trash):
		Bus.toast.emit("Rubbish. Throw it at a bin (Q), or carry it to the kitchen.", "info")
		return
	var drink: bool = str(Game.home.food(it).get("group", "")) == "drink"
	var res := Game.home.eat(held.item_id)
	if bool(res.ok):
		player.bite()
		Bus.sfx.emit("gulp" if drink else "bite")


func _on_bitten(_it: Dictionary, _left: int) -> void:
	pass          # the body is refreshed by items_changed; kept for views that animate bites


func _on_binned(body: Node) -> void:
	var b := body as Holdable
	if b == null or b.carried or not Game.active:
		return
	var from: Vector3 = b.get_meta("thrown_from", b.global_position)
	var far := from.distance_to(b.global_position) > 2.5
	var was_trash := bool(Game.home.item(b.item_id).get("trash", false))
	if Game.home.bin(b.item_id):
		if far and was_trash:
			Game.stats.add("health", 1.0, "Nothing but net")
			Bus.toast.emit("Nothing but net.", "good")
	else:
		# It bounces back out (you would miss it).
		b.linear_velocity = Vector3(randf_range(-1, 1), 3.0, randf_range(-1, 1))


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func _look_hits() -> Dictionary:
	## What the crosshair is on: {thing, item}. Loose items win over the
	## furniture they are lying on; nothing is reachable through a wall.
	var out := {"thing": null, "item": null, "person": null, "ware": {}}
	var from := player.eye_position()
	var to := from + player.aim() * REACH
	var space := get_world_3d().direct_space_state
	var wall := PhysicsRayQueryParameters3D.create(from, to)
	wall.collision_mask = SOLID
	var solid := space.intersect_ray(wall)
	var limit := REACH + 1.0
	if not solid.is_empty():
		limit = from.distance_to(solid.position) + 0.4
	var exclude: Array[RID] = []
	for hop in 5:
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collide_with_areas = true
		q.collide_with_bodies = false
		q.collision_mask = Interactable.PICK_LAYER
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty() or from.distance_to(hit.position) > limit:
			break
		var area: Area3D = hit.collider
		exclude.append(area.get_rid())
		if area.has_meta("item"):
			var b: Holdable = area.get_meta("item")
			if is_instance_valid(b) and not b.carried:
				out.item = b
				break
		elif area.has_meta("person") and out.person == null and out.thing == null:
			var who: TownPerson = area.get_meta("person")
			if who.visible:
				out.person = who
				break
		elif area.has_meta("ware") and out.thing == null:
			out.ware = area.get_meta("ware")
			break
		elif area.has_meta("thing") and out.thing == null:
			out.thing = area.get_meta("thing")
	return out


func nearest_thing() -> Interactable:
	## The object you are standing closest to (used by the scripted captures).
	var best: Interactable = null
	var best_d := 1.25
	var pp := player.global_position
	for id in apartment.things:
		var t: Interactable = apartment.things[id]
		var d := pp.distance_to(t.use_point())
		if d < best_d:
			best_d = d
			best = t
	return best


func press_use() -> void:
	## E / F: do the obvious thing with whatever the crosshair is on.
	if not Game.active:
		return
	if Game.activities.busy():
		Game.activities.stop()
	elif focused_item != null:
		pick_up(focused_item)
	elif focused_person != null:
		talk_to(focused_person)
	elif not focused_ware.is_empty():
		buy_ware(focused_ware)
	elif focused != null:
		use_thing(focused)


func interact(t: Interactable) -> void:
	## Walk to an object and use it. Autopilot: tests and scripted captures.
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
	player.face(t.focus_point(), true)
	use_thing(t)


func use_thing(t: Interactable) -> void:
	if t == null or not Game.active or Game.activities.busy():
		return
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
	if not Game.active:
		return
	player.body.set_outfit(str(Game.home.outfit))
	player.dress(Game.player, str(Game.home.outfit))
	if not Game.activities.busy() and not _at_desktop:
		player.bite()
	if t == focused:
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
		return
	_using = t
	_seat_player(t, str(a.get("anim", "idle")))
	Game.presence.set_at_desk(t != null and t.thing_id == "chair")


func _on_activity_ended(a: Dictionary, _completed: bool) -> void:
	if _at_desktop:
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
	player.pitch = deg_to_rad(4.0)
	player.head.rotation.x = player.pitch


func _on_desktop_closed() -> void:
	_at_desktop = false
	if Game.active and Game.activities.busy():
		return
	if player.seated:
		player.stand_up(apartment.things["workstation"].use_point())
	player.pose("idle")


func sit_at(thing_id: String, anim: String) -> void:
	## Sit somewhere without an activity (the shop, the menus).
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

func playing() -> bool:
	return view == "play" and not demo and interactive and Game.active and not Game.paused


func _unhandled_input(e: InputEvent) -> void:
	if not playing():
		return
	if e is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _at_desktop:
			player.look((e as InputEventMouseMotion).relative)
		return
	if e.is_action_pressed("interact"):
		press_use()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("throw"):
		throw_held()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("stow"):
		stow_held()
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo and int(e.physical_keycode) >= KEY_1 and int(e.physical_keycode) <= KEY_8:
		if Game.home.draw_slot(int(e.physical_keycode) - KEY_1):
			get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return                      # the click that takes the mouse back does nothing else
		if e.button_index == MOUSE_BUTTON_LEFT:
			# With something in your hand, a click is for it. Empty-handed, a
			# click does what E does.
			if held != null:
				use_held()
			elif not Game.activities.busy():
				press_use()
			get_viewport().set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			put_down()
			get_viewport().set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN or e.button_index == MOUSE_BUTTON_WHEEL_UP:
			Game.home.cycle(1 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	var live := Game.active and not demo and view == "play"
	player.controllable = live and interactive and not Game.paused and not Game.activities.busy() and not _at_desktop
	_update_focus(live)
	_update_sky(delta)
	_update_props(delta, live)
	_update_town(delta, live)
	if view != "play":
		# The menu camera drifts a little, so the room feels lived in.
		var drift := Vector3(sin(_t * 0.23) * 0.12, sin(_t * 0.31) * 0.04, cos(_t * 0.19) * 0.1) if view == "menu" else Vector3.ZERO
		stage.global_position = _stage_from + drift
		stage.look_at(_stage_at, Vector3.UP)
	elif live and Game.stats.has_buff("wired") and not _at_desktop and bool(Prefs.get_v("shake")):
		player.nudge(0.5)


func _update_focus(live: bool) -> void:
	var want: Interactable = null
	var want_item: Holdable = null
	if live and interactive and not Game.paused and not Game.activities.busy() and not _at_desktop and not player.seated:
		if _pending_thing != null and player.walking_to_target():
			want = _pending_thing
		else:
			var hits := _look_hits()
			want_item = hits.item
			want = hits.thing if want_item == null else null
	var hits_now: Dictionary = _look_hits() if (want != null or want_item != null or (live and interactive and not Game.paused and not Game.activities.busy() and not _at_desktop and not player.seated)) else {}
	focused_person = hits_now.get("person") if want_item == null else null
	focused_ware = hits_now.get("ware", {}) if want_item == null and focused_person == null else {}
	if focused_person != null or not focused_ware.is_empty():
		want = null
	if want_item != focused_item:
		if focused_item != null and is_instance_valid(focused_item):
			focused_item.set_highlight(false)
		focused_item = want_item
		if focused_item != null:
			focused_item.set_highlight(true)
	if want != focused:
		if focused != null:
			focused.set_highlight(false)
		focused = want
		focus_changed.emit(focused)
		if focused != null:
			focused.set_highlight(true)


func _update_town(delta: float, live: bool) -> void:
	## The front door, who is about, and who has seen you.
	var p := player.global_position
	var near_door := absf(p.x - Apartment.DOOR_X) < 1.3 and absf(p.z - Apartment.Z1) < 2.0 and view == "play"
	_door = move_toward(_door, 1.0 if near_door else 0.0, delta * 3.0)
	(apartment.parts["front_door"] as Node3D).rotation.y = -_door * 1.75
	(apartment.parts["front_door_shape"] as CollisionShape3D).disabled = _door > 0.25
	var minute := Game.time.clock() if live else demo_minute
	for person in people:
		var who: TownPerson = person
		var here := who.at_this_hour(minute) and (who.shop == "" or Game.home.shop_open(who.shop) or not Game.active)
		who.around = here
		who.visible = here
	_tick += delta
	if not live or _tick < 0.5:
		return
	_tick = 0.0
	var outside := apartment.in_town(p)
	Game.home.outside = outside
	# Ornaments standing on the desk make you look employed on camera.
	var desk: Vector3 = apartment.spots["desk"]
	var n := 0
	for id in bodies:
		var b: Holdable = bodies[id]
		if not b.carried and bool(Game.home.prop(Game.home.item(str(id))).get("decor", false)) and absf(b.global_position.z - desk.z) < 0.6 and absf(b.global_position.x - desk.x) < 2.2 and b.global_position.y > 0.6:
			n += 1
	Game.home.decor = n
	if not outside or Game.paused:
		return
	for person in people:
		var who: TownPerson = person
		if who.npc == "" or not who.sees(p):
			continue
		# Sitting with a friend is a meeting, as far as anyone can prove.
		if Game.social.is_colleague(who.npc) and Game.social.tier(who.npc) >= Social.Tier.FRIENDLY:
			if who.sit and p.distance_to(who.global_position) < 4.0 and Game.time.in_work_hours():
				Game.presence.grant_cover(3, "colleague")
			continue
		if Game.social.spotted(who.npc):
			who.turn_to(p)
			who.body.anim = "wave"


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
			var out: Array = []
			for j in range(1, a.size()):
				if a[j] is Color:
					out.append((a[j] as Color).lerp(b[j], f))
				else:
					out.append(lerpf(a[j], b[j], f))
			return out
	return SKY[0].slice(1)


func _update_sky(delta: float) -> void:
	var minute := demo_minute
	if Game.active and not demo:
		minute = Game.time.clock()
	var k: Array = _sky_at(minute)
	# Indoors the sun is soft fill with no shadows. Out in the street it is the sun.
	var outdoors := view == "play" and apartment.in_town(player.global_position)
	sun.light_color = k[0]
	sun.shadow_enabled = outdoors
	sun.light_energy = float(k[1]) * (1.0 if outdoors else 0.42)
	env.ambient_light_color = k[2]
	env.ambient_light_energy = float(k[3]) * (1.05 if outdoors else 0.95)
	var top: Color = k[4]
	var low: Color = k[5]
	env.background_color = low
	_sky_mat.set_shader_parameter("top", top)
	_sky_mat.set_shader_parameter("low", low)
	_sky_mat.set_shader_parameter("band", BAND)
	_sky_mat.set_shader_parameter("band_amount", float(k[6]))
	sky.global_position = cam().global_position
	# Haze: the colour of the horizon in the street, the colour of a dim room indoors.
	var roofed := outdoors and player.global_position.z > Town.SHOP_Z and player.global_position.x < 10.5
	_outside = move_toward(_outside, 1.0 if outdoors and not roofed else 0.0, delta * 1.6)
	env.fog_light_color = ((k[2] as Color) * 0.62).lerp(low, _outside)
	env.fog_density = lerpf(HAZE_IN, HAZE_OUT, _outside)
	var day_f := clampf((fposmod(minute, 1440.0) - 360.0) / 840.0, 0.0, 1.0)
	var azimuth := lerpf(deg_to_rad(-70.0), deg_to_rad(110.0), day_f)
	var elevation := deg_to_rad(28.0 + 30.0 * sin(day_f * PI))
	sun.rotation = Vector3(-elevation, azimuth, 0)
	for m in apartment.window_mats:
		var wm: StandardMaterial3D = m
		wm.albedo_color = k[7]
		wm.emission = k[7]
		wm.emission_energy_multiplier = 0.22 + 0.3 * float(k[1])
	var lamp_level := float(k[8])
	for i in apartment.lamps.size():
		var l: OmniLight3D = apartment.lamps[i]
		l.light_energy = lerpf(l.light_energy, float(_lamp_base[i]) * lamp_level, minf(1.0, delta * 3.0))
		l.visible = l.light_energy > 0.02
	# Ceiling lights are on all day: dim against daylight, full in the evening.
	for i in apartment.ceiling_lights.size():
		var c: OmniLight3D = apartment.ceiling_lights[i]
		c.light_energy = lerpf(c.light_energy, float(_ceiling_base[i]) * lerpf(0.5, 1.0, lamp_level), minf(1.0, delta * 3.0))


func _update_props(delta: float, live: bool) -> void:
	var p: Dictionary = apartment.parts
	var act := str(Game.activities.current.get("id", "")) if live and Game.activities.busy() else ""
	var router_on := true
	var jiggler := false
	var bird := false
	var docked := false
	var updating := false
	var ringing := false
	if live:
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
	var nuking := act == "burrito" or act == "heat"
	md.emission = Color("ffd166") if nuking else Color("2f2c3e")
	md.albedo_color = md.emission
	md.emission_energy_multiplier = 2.4 if nuking else 0.05
	var steam: Node3D = p.steam
	steam.visible = act == "brew"
	if steam.visible:
		steam.position.y = 0.3 + fmod(_t * 0.25, 0.14)
	(p.coffee_led as StandardMaterial3D).emission_energy_multiplier = (2.0 + sin(_t * 9.0) * 2.0) if act == "brew" else 1.2
	# Printer
	var paper: Node3D = p.printer_paper
	paper.position.z = 0.3 + (fmod(_t * 0.5, 0.12) if act == "forge" else 0.0)
	var pl: StandardMaterial3D = p.printer_led
	var jam := live and bool(Game.home.things.get("jam", false))
	pl.emission = Color("ff5d73") if jam else Color("5ad17a")
	pl.albedo_color = pl.emission
	pl.emission_energy_multiplier = (2.0 + sin(_t * 10.0) * 2.0) if jam else 2.0
	# Exercise bike
	if act == "workout":
		(p.bike_wheel as Node3D).rotate_object_local(Vector3.UP, delta * 14.0)
