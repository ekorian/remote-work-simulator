class_name TownPerson
extends Node3D
## Somebody in the street: a shopkeeper behind a counter, a neighbour walking
## past, or a colleague who is not at their desk either. They can be looked
## at and spoken to; colleagues can also see you.

const SIGHT := 8.5               ## how far a colleague recognises you from
const LOOKS := 9

var id := ""
var npc := ""                    ## SynerCorp id, or "" for a stranger
var title := ""
var lines := ""
var shop := ""
var body: Character
var hours: Array = []
var path: Array = []
var speed := 1.2
var loop := false
var sit := false
var around := true               ## here at this time of day
var _i := 0
var _step := 1
var _pause := 0.0
var _busy := 0.0
var _home := Vector3.ZERO
var _yaw := 0.0


func setup(def: Dictionary, index: int) -> void:
	id = str(def.id)
	name = "Person_" + id
	npc = str(def.get("npc", ""))
	title = Game.npcs.display_name(npc) if npc != "" else str(def.get("name", "Somebody"))
	lines = str(def.get("lines", ""))
	shop = str(def.get("shop", ""))
	hours = def.get("hours", [])
	path = def.get("path", [])
	speed = float(def.get("speed", 1.2))
	loop = bool(def.get("loop", false))
	sit = bool(def.get("sit", false))
	_home = def.get("at", path[0] if not path.is_empty() else Vector3.ZERO)
	_yaw = deg_to_rad(float(def.get("yaw", 0.0)))
	position = _home
	rotation.y = _yaw
	body = Character.new()
	add_child(body)
	var look: Dictionary = Game.npcs.def(npc).get("look", {}) if npc != "" else {}
	if look.is_empty():
		var k := index * 7 + 3
		look = {"skin": k % 6, "hair": (k * 3) % 7, "hair_color": (k * 5) % 8, "shirt": (k * 2 + 1) % 8, "pants": k % 6, "accessory": (k % 5) if k % 3 == 0 else 0}
	body.set_look(look, "casual")
	body.anim = "sit" if sit else "idle"
	# Somewhere for the crosshair to land.
	var area := Area3D.new()
	area.collision_layer = Interactable.PICK_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.input_ray_pickable = false
	area.set_meta("person", self)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.62, 1.3 if sit else 1.8, 0.62)
	cs.shape = shape
	cs.position = Vector3(0, shape.size.y / 2.0, 0)
	area.add_child(cs)
	add_child(area)


func at_this_hour(minute: float) -> bool:
	if hours.is_empty():
		return true
	var m := fposmod(minute, 1440.0)
	for span in hours:
		if m >= float(span[0]) and m < float(span[1]):
			return true
	return false


func sees(point: Vector3) -> bool:
	## Is that point in front of them and close enough to recognise a face?
	if not around or not visible:
		return false
	var d := point - global_position
	d.y = 0.0
	if d.length() > SIGHT or d.length() < 0.01:
		return false
	return (-global_transform.basis.z).dot(d.normalized()) > 0.15


func speak() -> String:
	## What they say when you talk to them. They stop for a moment to say it.
	_busy = 2.6
	body.talking = true
	if npc != "" and Game.social.is_colleague(npc):
		return Game.social.meet(npc)
	if npc != "":
		var said := Db.lines("town_" + npc)
		return str(said[randi() % said.size()]) if not said.is_empty() else "..."
	var options := Db.lines(lines)
	return str(options[randi() % options.size()]) if not options.is_empty() else "..."


func turn_to(point: Vector3) -> void:
	if sit:
		return
	var d := point - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		rotation.y = atan2(-d.x, -d.z)


func _process(delta: float) -> void:
	if not visible:
		return
	if _busy > 0.0:
		_busy -= delta
		if _busy <= 0.0:
			body.talking = false
			if path.is_empty() and not sit:
				rotation.y = _yaw
		if body.anim == "walk":
			body.anim = "idle"
		return
	if path.size() < 2:
		return
	if _pause > 0.0:
		_pause -= delta
		body.anim = "idle"
		return
	var target: Vector3 = path[_i]
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.15:
		if loop:
			_i = (_i + 1) % path.size()
		else:
			if _i + _step < 0 or _i + _step >= path.size():
				_step = -_step
				_pause = 1.5 + randf() * 2.5
			_i += _step
		return
	var dir := to.normalized()
	global_position += dir * speed * delta
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 8.0))
	body.anim = "walk"
	body.speed_ratio = clampf(speed / 3.5, 0.3, 1.0)
	body.walk_phase += delta * 4.0 * speed
