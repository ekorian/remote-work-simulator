class_name Holdable
extends RigidBody3D
## A loose item you can pick up, carry, put down and throw: junk food, what
## is left of it, and the toys on the desk. What it is and what it does is
## decided in Game.home (the item dictionary); this is only its body.

const LAYER := 8                 ## physics layer for loose items
const PICK_PAD := 0.05           ## the pick volume is this much bigger than the model

var item_id := ""
var title := ""
var model := ""
var size := Vector3(0.1, 0.1, 0.1)
var carried := false
var _built: Dictionary = {}
var _holder: Node3D
var _meshes: Array = []
var _lit := false
var _steam: Node3D
var _t := 0.0


func setup(it: Dictionary) -> void:
	item_id = str(it.id)
	name = "Item_" + item_id
	collision_layer = LAYER
	collision_mask = 1 | LAYER
	continuous_cd = true
	can_sleep = true
	linear_damp = 0.15
	angular_damp = 1.2
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.12
	physics_material_override = pm
	_holder = Kit.node(self)
	refresh(it)


func refresh(it: Dictionary) -> void:
	## Bring the body in line with the item: a new model once it is rubbish,
	## less of it after every bite, steam while it is hot.
	title = Game.home.item_name(it)
	var want := Game.home.item_model(it)
	if want != model:
		model = want
		_rebuild(it)
	var total := int(Game.home.food(it).get("bites", 0))
	if total > 0 and not bool(it.get("trash", false)):
		var left := clampf(float(int(it.bites)) / float(total), 0.0, 1.0)
		var pieces: Array = _built.get("pieces", [])
		var show := int(ceil(float(pieces.size()) * left))
		for i in pieces.size():
			(pieces[i] as Node3D).visible = i < show
		var body: Node3D = _built.get("body")
		if body != null and pieces.size() < 2:
			body.scale = Vector3.ONE * lerpf(0.5, 1.0, left)
	if _steam != null:
		_steam.visible = bool(it.get("hot", false)) and not bool(it.get("trash", false))


func _rebuild(it: Dictionary) -> void:
	for c in _holder.get_children():
		_holder.remove_child(c)
		c.queue_free()
	for c in get_children():
		if c is CollisionShape3D or c is Area3D:
			remove_child(c)
			c.queue_free()
	var tint: Color = Game.home.food(it).get("tint", Color("5ad1c8"))
	_built = FoodKit.build(model, _holder, tint)
	size = _built.size
	mass = clampf(size.x * size.y * size.z * 900.0, 0.08, 1.2)
	# Collider: the model's bounding box, never thinner than a finger.
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(size.x, 0.04), maxf(size.y, 0.025), maxf(size.z, 0.04))
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, shape.size.y / 2.0, 0)
	add_child(cs)
	# A slightly generous volume for the crosshair to find.
	var area := Area3D.new()
	area.collision_layer = Interactable.PICK_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.input_ray_pickable = false
	area.set_meta("item", self)
	var ps := BoxShape3D.new()
	ps.size = Vector3(maxf(size.x, 0.07), maxf(size.y, 0.06), maxf(size.z, 0.07)) + Vector3.ONE * PICK_PAD
	var pcs := CollisionShape3D.new()
	pcs.shape = ps
	pcs.position = Vector3(0, maxf(size.y, 0.06) / 2.0, 0)
	area.add_child(pcs)
	add_child(area)
	_steam = Kit.node(_holder, Vector3(0, size.y + 0.02, 0))
	for i in 3:
		Kit.ball(_steam, 0.014, Vector3(0.02 * (i - 1), 0.03 * i, 0), Color(1, 1, 1, 0.55), 6)
	_steam.visible = false
	_meshes = Kit.meshes_in(_holder)
	if _lit:
		_lit = false
		set_highlight(true)


func set_highlight(on: bool) -> void:
	if on == _lit:
		return
	_lit = on
	var m: Material = Interactable.overlay() if on else null
	for mi in _meshes:
		if is_instance_valid(mi):
			(mi as MeshInstance3D).material_overlay = m


func pick_up() -> void:
	carried = true
	freeze = true
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	set_highlight(false)


func let_go(velocity: Vector3 = Vector3.ZERO, spin: Vector3 = Vector3.ZERO) -> void:
	carried = false
	collision_layer = LAYER
	collision_mask = 1 | LAYER
	freeze = false
	sleeping = false
	linear_velocity = velocity
	angular_velocity = spin


func _process(delta: float) -> void:
	if _steam != null and _steam.visible:
		_t += delta
		_steam.position.y = size.y + 0.02 + fmod(_t * 0.08, 0.05)
