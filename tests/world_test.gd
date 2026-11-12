extends Node
## Scene-level checks that need the real 3D world: every object can be reached
## on foot from every other one, with physics and collisions running.
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
		"coffee", "gaming_pc", "sofa", "printer", "microwave", "laptop", "console", "mug", "chair", "keyboard", "bed"]
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
	print("== sitting and standing")
	for id in ["workstation", "sofa", "bed", "table", "exercise", "gaming_pc"]:
		var t: Interactable = apt.things[id]
		check(not t.seat.is_empty(), "'%s' has a seat" % id)
		world.sit_at(id, "sit")
		check(world.player.seated, "can sit at '%s'" % id)
		world.leave_seat()
		check(not world.player.seated and absf(world.player.global_position.y) < 0.01, "can stand up from '%s'" % id)
		check(apt.walkable(world.player.global_position) or world.player.global_position.distance_to(apt.point_of(apt.nearest_free(apt.cell_of(world.player.global_position)))) < 0.5, "standing spot after '%s' is free" % id)
	Engine.time_scale = 1.0
	Game.clear_run()
	print("")
	print("%d checks, %d failed" % [checks, fails])
	print("RESULT: %s" % ("FAIL" if fails > 0 else "PASS"))
	get_tree().quit(1 if fails > 0 else 0)
