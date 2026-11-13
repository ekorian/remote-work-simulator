extends Node
## Scene-level checks that need the real 3D world: every object can be reached
## on foot from every other one, with physics and collisions running, found
## by the crosshair, and sat on; loose items can be picked up, eaten, put
## down, thrown and binned.
##
##   godot --headless --path . res://tests/world_test.tscn

var fails := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("  FAIL: ", what)


func _ready() -> void:
	Game.saves.enabled = false
	Prefs.persist = false
	var world: World = (load("res://scenes/apartment/world.tscn") as PackedScene).instantiate()
	add_child(world)
	await get_tree().process_frame
	Game.new_run("survivor", {"name": "Walker"}, false, 5)
	Game.paused = true
	world.interactive = false
	var apt := world.apartment
	var ids: Array = apt.things.keys()
	var home_ids: Array = ids.filter(func(i): return str(Home.THINGS[i].room) != "Town")
	check(ids.size() == Home.THINGS.size(), "every object in Home.THINGS exists in the apartment (%d/%d)" % [ids.size(), Home.THINGS.size()])
	for id in Home.THINGS:
		check(apt.things.has(id), "'%s' is placed in the apartment" % id)
	print("== use points")
	for id in ids:
		var t: Interactable = apt.things[id]
		var up := t.use_point()
		var near := apt.point_of(apt.nearest_free(apt.cell_of(up)))
		check(up.distance_to(near) < 0.5, "'%s' has a reachable standing spot (%.2f m off)" % [id, up.distance_to(near)])
		check(apt.room_at(up) == str(Home.THINGS[id].room), "'%s' is in the %s" % [id, str(Home.THINGS[id].room)])
	print("== paths between all objects")
	var missing := 0
	for a in ids:
		for b in ids:
			if a == b:
				continue
			var p := apt.find_path((apt.things[a] as Interactable).use_point(), (apt.things[b] as Interactable).use_point())
			if p.is_empty():
				missing += 1
				print("  no path: %s -> %s" % [a, b])
	check(missing == 0, "a path exists between every pair of objects")
	print("== walking the whole flat with physics")
	Engine.time_scale = 6.0
	Engine.max_physics_steps_per_frame = 24
	var order: Array = ["bed", "workstation", "fridge", "tv", "charger", "router", "exercise", "wardrobe", "table", "bookshelf",
		"coffee", "gaming_pc", "sofa", "printer", "microwave", "bin", "laptop", "console", "mug", "chair", "keyboard", "bed"]
	world.place_player((apt.things["bed"] as Interactable).use_point(), 0.0)
	var total := 0.0
	for id in order:
		var t: Interactable = apt.things[id]
		var goal := t.use_point()
		var state := {"done": false}
		var ok := world.player.go_to(goal, func(): state.done = true)
		if world.player.global_position.distance_to(goal) < 0.2:
			state.done = true
		var from := world.player.global_position
		var frames := 0
		while ok and not state.done and frames < 1500 and world.player.walking_to_target():
			frames += 1
			await get_tree().physics_frame
		var dist := world.player.global_position.distance_to(goal)
		total += from.distance_to(goal)
		check(dist < 0.6, "walked to '%s' (ended %.2f m away after %d physics frames)" % [id, dist, frames])
		var p := world.player.global_position
		check(p.x > Apartment.X0 and p.x < Apartment.X1 and p.z > Apartment.Z0 and p.z < Apartment.Z1, "player stays inside the flat at '%s'" % id)
	print("  walked ~%.0f m" % total)
	Engine.time_scale = 1.0
	print("== the crosshair finds every object")
	for id in ids:
		var t: Interactable = apt.things[id]
		world.place_player(t.use_point(), 0.0)
		world.player.face((t.get_child(0) as Node3D).global_position, true)
		for person in world.people:
			(person as TownPerson).visible = false          # nobody standing in the way
		await get_tree().physics_frame
		await get_tree().physics_frame
		var hits := world._look_hits()
		check(hits.thing == t or hits.item != null, "'%s' is under the crosshair from where you stand to use it" % id)
	print("== the flat is closed")
	check(not apt.ceiling_lights.is_empty(), "there are ceiling lights")
	var space := world.get_world_3d().direct_space_state
	for from in [Vector3(-4.0, 1.5, -3.0), Vector3(3.5, 1.5, -3.0), Vector3(0.5, 1.5, 3.0), Vector3(4.0, 1.5, 3.0)]:
		for dir in [Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var q := PhysicsRayQueryParameters3D.create(from, from + dir * 30.0)
			q.collision_mask = 1
			check(not space.intersect_ray(q).is_empty(), "something solid %s of %s" % [str(dir), str(from)])
	# You can walk through every doorway but not through the walls beside it.
	for door in [[Vector3(-3.3, 0, -0.8), Vector3(-3.3, 0, 0.8)], [Vector3(-0.8, 0, -1.55), Vector3(0.8, 0, -1.55)], [Vector3(5.95, 0, -0.8), Vector3(5.95, 0, 0.8)], [Vector3(0.2, 0, 3.0), Vector3(1.8, 0, 3.0)]]:
		var q := PhysicsRayQueryParameters3D.create((door[0] as Vector3) + Vector3(0, 1.0, 0), (door[1] as Vector3) + Vector3(0, 1.0, 0))
		q.collision_mask = 1
		check(space.intersect_ray(q).is_empty(), "the doorway at %s is open at chest height" % str(door[0]))
		var top := PhysicsRayQueryParameters3D.create((door[0] as Vector3) + Vector3(0, 2.4, 0), (door[1] as Vector3) + Vector3(0, 2.4, 0))
		top.collision_mask = 1
		check(not space.intersect_ray(top).is_empty(), "and closed above head height")
	print("== the town")
	check(apt.room_at(Vector3(0, 0, 12)) == "Town" and apt.room_at(Vector3(-3, 0, 3)) == "Living room", "the street is the town; the flat is the flat")
	# Out of the front door on foot, across the road, into each shop, and home again.
	Engine.time_scale = 6.0
	world.place_player(Vector3(-4.5, 0, 3.5), 0.0)
	for goal_id in ["vending", "cart", "bench", "odds", "diner", "mart", "news_box", "workstation"]:
		var goal: Vector3 = (apt.things[goal_id] as Interactable).use_point()
		var st := {"done": false}
		var okp := world.player.go_to(goal, func(): st.done = true)
		var fr := 0
		while okp and not st.done and fr < 4000 and world.player.walking_to_target():
			fr += 1
			await get_tree().physics_frame
		check(world.player.global_position.distance_to(goal) < 0.7, "walked to '%s' (ended %.2f m away)" % [goal_id, world.player.global_position.distance_to(goal)])
	Engine.time_scale = 1.0
	# The map is closed: nothing to walk off.
	for from in [Vector3(-10, 1.2, 12.5), Vector3(5, 1.2, 12.5), Vector3(18, 1.2, 12.5), Vector3(16, 1.2, 21)]:
		for dir in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var q := PhysicsRayQueryParameters3D.create(from, from + dir * 60.0)
			q.collision_mask = 1
			var hit := space.intersect_ray(q)
			check(not hit.is_empty() and (hit.position as Vector3).x > Apartment.TX0 - 1.0 and (hit.position as Vector3).x < Apartment.TX1 + 1.0 and (hit.position as Vector3).z < Apartment.TZ1 + 1.0, "the street ends %s of %s" % [str(dir), str(from)])
	# The front door opens when you walk up to it.
	world.place_player(Vector3(-4.5, 0, 4.6), 0.0)
	Game.paused = false
	for f in 50:
		await get_tree().process_frame
	check(bool((apt.parts["front_door_shape"] as CollisionShape3D).disabled), "the front door opens as you reach it")
	world.place_player(Vector3(3.0, 0, -3.0), 0.0)
	for f in 60:
		await get_tree().process_frame
	check(not bool((apt.parts["front_door_shape"] as CollisionShape3D).disabled), "and closes behind you")
	# Shelves: everything on them can be found and bought.
	check(world.wares.size() >= 20, "the shops have goods on their shelves (%d)" % world.wares.size())
	Game.economy.money = 500
	Game.time.minute = 700.0
	var found := 0
	var first_meta: Dictionary = {}
	for ware in world.wares:
		var area := (ware as Node3D).get_child((ware as Node3D).get_child_count() - 1) as Area3D
		var meta: Dictionary = area.get_meta("ware")
		world.place_player(meta.stand, 0.0)
		world.player.face(area.global_position + Vector3(0, 0.18, 0), true)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var seen_w: Dictionary = world._look_hits().ware
		if not seen_w.is_empty() and str(seen_w.what) == str(meta.what):
			found += 1
		else:
			print("  not under the crosshair: %s in %s" % [str(meta.what), str(meta.shop)])
		if first_meta.is_empty():
			first_meta = meta
	check(found == world.wares.size(), "every item on a shelf is under the crosshair from in front of it (%d/%d)" % [found, world.wares.size()])
	var money := Game.economy.money
	check(world.buy_ware(first_meta) and Game.economy.money < money and Game.home.held != "", "buying off the shelf puts it in your hand")
	await get_tree().process_frame
	check(world.held != null and world.held.item_id == Game.home.held, "and there it is")
	world.stow_held()
	await get_tree().process_frame
	check(world.held == null and Game.home.pockets.size() == 1 and not world.bodies.has(str(Game.home.pockets[0])), "R pockets it: nothing in your hand, nothing in the world")
	Game.home.draw_slot(0)
	await get_tree().process_frame
	check(world.held != null, "and a number key brings it back")
	world.put_down()
	await get_tree().process_frame
	# People.
	check(world.people.size() == Town.PEOPLE.size(), "everybody is in the street (%d)" % world.people.size())
	var walker: TownPerson = null
	var dave: TownPerson = null
	for person in world.people:
		if (person as TownPerson).id == "walker_1":
			walker = person
		if (person as TownPerson).id == "dave":
			dave = person
	var was := walker.global_position
	for f in 120:
		await get_tree().process_frame
	check(walker.global_position.distance_to(was) > 0.3, "the neighbours walk about")
	Game.time.minute = 700.0
	await get_tree().process_frame
	check(dave.visible and dave.around, "Dave is on the park bench during work hours")
	world.place_player(dave.global_position + Vector3(0, 0, -1.4), 0.0)
	world.player.face(dave.global_position + Vector3(0, 0.8, 0), true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(world._look_hits().person == dave, "you can look at him")
	var rel_d := Game.npcs.relationship("dave")
	world.talk_to(dave)
	check(Game.npcs.relationship("dave") > rel_d, "and stop for a chat")
	Game.time.minute = 1200.0
	await get_tree().process_frame
	await get_tree().process_frame
	check(not dave.visible, "he goes home in the evening")
	Game.time.minute = 600.0
	Game.paused = true
	world.place_player(Vector3(3.0, 0, -3.0), 0.0)
	await get_tree().process_frame
	print("== loose items")
	Game.paused = false
	world.interactive = true
	Game.time.hold = true
	for spot in Home.MORNING_SPOTS + ["desk_left", "desk_right", "doormat"] + Home.TOWN_SPOTS.keys():
		check(apt.spots.has(spot), "there is a place called '%s'" % spot)
		if apt.spots.has(spot):
			var p: Vector3 = apt.spots[spot]
			check(p.x > Apartment.TX0 and p.x < Apartment.TX1 and p.z > Apartment.Z0 and p.z < Apartment.TZ1 and p.y >= 0.0 and p.y < 1.2, "'%s' is on the map, at a reachable height" % spot)
	check(world.bodies.size() == Game.home.items.size() and world.bodies.size() >= Home.MORNING_ITEMS, "every item has a body in the flat (%d)" % world.bodies.size())
	check(apt.bins.size() >= 2, "there are bins to throw things at (%d)" % apt.bins.size())
	var duck: Holdable = null
	for id in world.bodies:
		var b: Holdable = world.bodies[id]
		check(b.size.x > 0.01 and b.size.y > 0.005 and b.size.z > 0.01 and not Kit.meshes_in(b).is_empty(), "'%s' has a model and a size" % b.title)
		if b.model == "rubber_duck":
			duck = b
	# The crosshair finds an item where it lies; E picks it up.
	check(duck != null, "the rubber duck is on the desk")
	world.place_player(Vector3(duck.global_position.x, 0, duck.global_position.z + 1.0), 0.0)
	world.player.face(duck.global_position + Vector3(0, 0.04, 0), true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	check(world._look_hits().item == duck, "the crosshair finds an item on the desk, not the desk")
	world.press_use()
	await get_tree().process_frame
	check(world.held == duck and Game.home.held == duck.item_id and duck.carried, "E picks it up")
	check(duck.get_parent() == world.player.hand, "and it rides in your hand")
	world.use_held()
	check(world.held == duck, "squeezing a toy does not use it up")
	# Put it down, then throw it.
	world.player.face(world.player.global_position + Vector3(0, 0.2, -1.0), true)
	world.put_down()
	await get_tree().physics_frame
	check(world.held == null and Game.home.held == "" and not duck.carried and duck.get_parent() == world, "right click puts it down")
	world.pick_up(duck)
	await get_tree().process_frame
	world.place_player(Vector3(-3.5, 0, 3.0), 0.0)
	var before := world.player.eye_position()
	world.throw_held()
	check(world.held == null and duck.linear_velocity.length() > 3.0, "Q throws it")
	for f in 90:
		await get_tree().physics_frame
	check(duck.global_position.distance_to(before) > 1.0 and duck.global_position.y > -0.2 and duck.global_position.y < 2.8, "it lands somewhere in the room (%.1f m away)" % duck.global_position.distance_to(before))
	var p_d := duck.global_position
	check(p_d.x > Apartment.X0 and p_d.x < Apartment.X1 and p_d.z > Apartment.Z0 and p_d.z < Apartment.Z1, "inside the flat")
	# Eating: a bite at a time, and what is left.
	var soda := Game.home.add_item("soda_can", "")
	await get_tree().process_frame
	var can: Holdable = world.bodies[str(soda.id)]
	world.pick_up(can)
	await get_tree().process_frame
	check(world.held == can, "you can hold a can of cola")
	var energy := Game.stats.get_value("energy")
	Game.stats.values.energy = 40.0
	world.use_held()
	check(int(soda.bites) == 2 and Game.stats.get_value("energy") > 40.0, "left click drinks from it")
	world.use_held()
	world.use_held()
	await get_tree().process_frame
	check(bool(soda.trash) and world.held == can and can.model == "trash_can", "an empty can is a crushed can, still in your hand")
	Game.stats.values.energy = energy
	# The bin.
	var bin_at: Vector3 = (apt.bins[0] as Area3D).global_position
	world.put_down()
	can.global_position = bin_at + Vector3(0, 0.5, 0)
	can.let_go(Vector3(0, -1.0, 0))
	for f in 60:
		await get_tree().physics_frame
	check(Game.home.item(str(soda.id)).is_empty() and not world.bodies.has(str(soda.id)), "rubbish dropped into a bin is gone")
	check(int(Game.week.binned) == 1, "and counted")
	# A new item appears where the rules put it.
	var pizza := Game.home.add_item("pizza_box", "doormat")
	await get_tree().process_frame
	var box: Holdable = world.bodies[str(pizza.id)]
	check(box.global_position.distance_to(apt.spots["doormat"]) < 0.05, "a delivered pizza is on the doormat")
	Game.home.remove_item(str(pizza.id))
	await get_tree().process_frame
	check(not world.bodies.has(str(pizza.id)), "an item removed by the rules leaves the flat")
	Game.time.hold = false
	Game.paused = true
	world.interactive = false
	print("== every junk food has a model")
	var holder := Node3D.new()
	add_child(holder)
	var seen := {}
	for model in FoodKit.MODELS + FoodKit.TRASH + FoodKit.TOYS:
		var built := FoodKit.build(str(model), holder)
		var meshes := Kit.meshes_in(built.root)
		var bsize: Vector3 = built.size
		check(meshes.size() >= 1 and bsize.x > 0.01 and bsize.y > 0.004 and bsize.z > 0.01, "model '%s' is built (%d meshes)" % [str(model), meshes.size()])
		check(meshes.size() >= 3 or str(model).begins_with("trash_") or str(model) == "paper_ball", "model '%s' is made of several parts (%d)" % [str(model), meshes.size()])
		var sig := "%d|%s" % [meshes.size(), str(bsize.snapped(Vector3(0.001, 0.001, 0.001)))]
		check(not seen.has(sig), "model '%s' is not a copy of '%s'" % [str(model), str(seen.get(sig, ""))])
		seen[sig] = model
	for fid in Db.foods:
		var built := FoodKit.build(str(Db.foods[fid].model), holder)
		check(not (built.pieces as Array).is_empty() or built.body != null or str(Db.foods[fid].group) == "drink", "'%s' visibly gets smaller as you eat it" % fid)
	holder.queue_free()
	print("== the look")
	for c in [Color("ff0000"), Color("5ad1c8"), Color("ffd166"), Color("f7f5f0"), Color("2f2c3e"), Color(0.2, 0.6, 1.0, 0.4)]:
		var shown := Kit.tone(c)
		check(shown.s < c.s or c.s < 0.02, "%s loses colour on the way to a surface (%.2f -> %.2f)" % [c.to_html(), c.s, shown.s])
		check(shown.v <= c.v + 0.08 and is_equal_approx(shown.a, c.a), "%s does not get brighter, and keeps its alpha" % c.to_html())
		check(c.s < 0.15 or absf(angle_difference(shown.h * TAU, c.h * TAU)) < 0.5, "%s is still the same sort of colour" % c.to_html())
	check(Kit.mat(Color("ff5d73")).albedo_color.is_equal_approx(Kit.tone(Color("ff5d73"))), "every material is made in the toned colour")
	for kind in ["wood_x", "wood_z", "tiles", "slabs", "carpet", "grit"]:
		var tex := Kit.texture(kind)
		var img := tex.get_image()
		check(tex.get_width() == tex.get_height() and tex.get_width() >= 32 and img.has_mipmaps(), "texture '%s' is square, small and mip-mapped" % kind)
		var lo := 1.0
		var hi := 0.0
		for y in range(0, img.get_height(), 3):
			for x in range(0, img.get_width(), 3):
				lo = minf(lo, img.get_pixel(x, y).r)
				hi = maxf(hi, img.get_pixel(x, y).r)
		check(hi - lo > 0.06 and hi > 0.85, "texture '%s' has something drawn on it (%.2f..%.2f)" % [kind, lo, hi])
	check(Kit.texture("wood_x") == Kit.texture("wood_x") and Kit.texture("wood_x") != Kit.texture("wood_z"), "textures are made once and shared")
	var textured := 0
	for m in Kit.meshes_in(apt):
		var sm := (m as MeshInstance3D).material_override as StandardMaterial3D
		if sm != null and sm.albedo_texture != null:
			textured += 1
			check(sm.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC and sm.uv1_world_triplanar, "a textured surface shows square texels, laid out in world space")
	check(textured >= 10, "the floors, the pavements and the lawn are textured (%d surfaces)" % textured)
	var width := (World.SKY[0] as Array).size()
	for row in World.SKY:
		check((row as Array).size() == width, "the sky table has %d columns at minute %d" % [width, int(row[0])])
	for minute in range(0, 1440, 45):
		var k: Array = world._sky_at(float(minute))
		check(k.size() == width - 1 and k[4] is Color and k[5] is Color and float(k[8]) >= 0.0 and float(k[8]) <= 1.0, "there is a sky at %02d:%02d" % [int(minute / 60.0), minute % 60])
	check(world.env.fog_enabled and world.env.fog_density > 0.0 and not world.env.glow_enabled and not world.env.ssao_enabled, "haze, and no bloom or contact shadows")
	check(world.sky != null and world.sky.global_position.distance_to(world.cam().global_position) < 0.5, "the sky goes where the camera goes")
	check(World.block_for(1.0, 1080) == 1 and World.block_for(1.0, 2160) == 2, "pixel size 1 is a sharp picture on an ordinary screen")
	check(World.block_for(3.0, 1080) == 3 and World.block_for(3.0, 900) == 3 and World.block_for(3.0, 1440) == 4 and World.block_for(3.0, 2160) == 6, "the picture has about the same number of lines on any screen")
	check(World.block_for(4.0, 1080) == 4 and World.block_for(4.0, 200) == 1 and World.block_for(0.0, 1080) == 1, "and a square is never smaller than a pixel")
	check(World.block_for(float(Prefs.DEFAULTS.pixel), 1080) > 1, "the default is low resolution")
	var port := get_viewport()
	for px in [1.0, 2.0, 3.0, 4.0]:
		Prefs.set_v("pixel", px)
		var block := World.block_for(px, port.size.y)
		check(is_equal_approx(port.scaling_3d_scale, 1.0 / float(block)), "pixel size %d draws the 3D view at 1/%d here" % [int(px), block])
		check((port.scaling_3d_mode == Viewport.SCALING_3D_MODE_NEAREST and port.msaa_3d == Viewport.MSAA_DISABLED) == (block > 1), "and blows it up unsmoothed when it is small")
	Prefs.set_v("pixel", float(Prefs.DEFAULTS.pixel))
	print("== sitting and standing")
	Engine.time_scale = 6.0
	for id in ["workstation", "sofa", "bed", "table", "exercise", "gaming_pc"]:
		var t: Interactable = apt.things[id]
		check(not t.seat.is_empty(), "'%s' has a seat" % id)
		world.sit_at(id, "sit")
		check(world.player.seated, "can sit at '%s'" % id)
		var eye := world.player.head.global_position
		await get_tree().physics_frame
		await get_tree().physics_frame
		eye = world.player.camera.global_position
		check(eye.y > 0.2 and eye.y < 2.2 and eye.x > Apartment.X0 and eye.x < Apartment.X1 and eye.z > Apartment.Z0 and eye.z < Apartment.Z1, "your eyes are somewhere sensible at '%s' (%.2f m up)" % [id, eye.y])
		world.leave_seat()
		check(not world.player.seated and absf(world.player.global_position.y) < 0.01, "can stand up from '%s'" % id)
		check(apt.walkable(world.player.global_position) or world.player.global_position.distance_to(apt.point_of(apt.nearest_free(apt.cell_of(world.player.global_position)))) < 0.5, "standing spot after '%s' is free" % id)
	Engine.time_scale = 1.0
	Game.clear_run()
	print("")
	print("%d checks, %d failed" % [checks, fails])
	print("RESULT: %s" % ("FAIL" if fails > 0 else "PASS"))
	get_tree().quit(1 if fails > 0 else 0)
