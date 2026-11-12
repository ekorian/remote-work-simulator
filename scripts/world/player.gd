class_name Player
extends CharacterBody3D
## The player's body in the apartment: WASD + click-to-move, path following,
## sitting/lying on furniture, and the energy cost of walking.

signal arrived()
signal blocked()

const SPEED := 3.7
const ACCEL := 22.0
const TURN := 14.0

var body: Character
var apartment: Apartment
var cam_yaw := 0.0                     ## set by the camera rig every frame
var controllable := true
var seated := false
var _path := PackedVector3Array()
var _path_i := 0
var _on_arrive: Callable
var _shape: CollisionShape3D
var _walked := 0.0
var _face_target := Vector3.INF
var _stuck := 0.0
var _walk_time := 0.0
var _walk_limit := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.22
	cap.height = 1.4
	_shape.shape = cap
	_shape.position.y = 0.7
	add_child(_shape)
	body = Character.new()
	add_child(body)
	floor_snap_length = 0.3


func walking_to_target() -> bool:
	return _path_i < _path.size()


func go_to(target: Vector3, on_arrive: Callable = Callable()) -> bool:
	## Walk to a point using the nav grid. Returns false if unreachable.
	if seated:
		stand_up()
	var p := apartment.find_path(global_position, target)
	if p.is_empty():
		return false
	_path = p
	_path_i = 0
	_on_arrive = on_arrive
	_stuck = 0.0
	# Generous budget: if a walk takes far longer than it should, abandon it.
	var length := global_position.distance_to(p[0])
	for i in range(1, p.size()):
		length += p[i - 1].distance_to(p[i])
	_walk_time = 0.0
	_walk_limit = 3.0 + length / (SPEED * 0.4)
	return true


func stop() -> void:
	_path = PackedVector3Array()
	_path_i = 0
	_on_arrive = Callable()


func face(point: Vector3) -> void:
	_face_target = point


func sit(xf: Transform3D, lie: bool, anim: String) -> void:
	stop()
	seated = true
	velocity = Vector3.ZERO
	_shape.disabled = true
	global_transform = xf
	body.rotation = Vector3(PI / 2.0, 0, 0) if lie else Vector3.ZERO
	body.anim = anim
	_face_target = Vector3.INF


func stand_up(at: Vector3 = Vector3.INF) -> void:
	if not seated:
		return
	seated = false
	body.rotation = Vector3.ZERO
	body.anim = "idle"
	var yaw := rotation.y
	rotation = Vector3(0, yaw, 0)
	if at != Vector3.INF:
		global_position = Vector3(at.x, 0, at.z)
	else:
		global_position.y = 0.0
	_shape.disabled = false


func pose(anim: String) -> void:
	## Standing animation (eating at the fridge, using the printer...).
	body.anim = anim


func _physics_process(delta: float) -> void:
	if seated:
		return
	var dir := Vector3.ZERO
	var manual := false
	if controllable:
		var iv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if iv.length() > 0.15:
			manual = true
			dir = (Vector3(iv.x, 0, iv.y)).rotated(Vector3.UP, cam_yaw).normalized()
			if walking_to_target():
				stop()
	if not manual and walking_to_target():
		var target := _path[_path_i]
		var to := target - global_position
		to.y = 0.0
		# Reached (or would overshoot this step): take the waypoint.
		if to.length() < maxf(0.14, SPEED * 1.3 * delta):
			if _path_i == _path.size() - 1:
				global_position = Vector3(target.x, 0, target.z)
			_path_i += 1
			if not walking_to_target():
				var cb := _on_arrive
				stop()
				arrived.emit()
				if cb.is_valid():
					cb.call()
		else:
			dir = to.normalized()
	var mult := 1.0
	if Game.active:
		if Game.has_buff("wired"):
			mult = 1.3
		elif Game.has_buff("jitter"):
			mult = 1.15
		if Game.get_stat("energy") < 12.0:
			mult *= 0.62
	var want := dir * SPEED * mult
	velocity.x = move_toward(velocity.x, want.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, want.z, ACCEL * delta)
	velocity.y = 0.0
	var before := global_position
	move_and_slide()
	global_position.y = 0.0
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	var hs := Vector2(velocity.x, velocity.z).length()
	# Path following: give up if something is in the way.
	if walking_to_target() and not manual:
		_stuck = _stuck + delta if moved < 0.004 else 0.0
		_walk_time += delta
		if _stuck > 0.5 or _walk_time > _walk_limit:
			# Wedged on something. Close enough counts; otherwise give up cleanly.
			var goal := _path[_path.size() - 1]
			var cb := _on_arrive
			var near := Vector2(goal.x - global_position.x, goal.z - global_position.z).length() < 0.75
			stop()
			if near:
				arrived.emit()
				if cb.is_valid():
					cb.call()
			else:
				blocked.emit()
	if hs > 0.25:
		body.anim = "walk"
		body.speed_ratio = hs / SPEED
		body.walk_phase += delta * 11.0 * (hs / SPEED)
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), minf(1.0, TURN * delta))
		_face_target = Vector3.INF
		_walked += moved
		Tutor.walked(moved)
		if _walked >= 1.0 and Game.active and not Game.paused and not bool(Game.s.get("hold", false)):
			Game.add("energy", -Cfg.MOVE_EN_PER_M * _walked, "")
			_walked = 0.0
	else:
		if body.anim == "walk":
			body.anim = "idle"
		if _face_target != Vector3.INF:
			var d := _face_target - global_position
			if Vector2(d.x, d.z).length() > 0.05:
				rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(1.0, TURN * delta))
