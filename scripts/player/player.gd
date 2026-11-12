class_name Player
extends CharacterBody3D
## The player, in first person: mouse look, WASD, sitting and lying on
## furniture (the camera goes where your head would be), and a hand that
## carries one thing at a time.
##
## An autopilot (`go_to`, `face`) walks the same body along the apartment's
## navigation grid. Nothing in normal play uses it; the tests and the
## scripted screenshots do.

signal arrived()
signal blocked()

const SPEED := 3.5
const SPRINT := 5.3
const ACCEL := 26.0
const TURN := 9.0
const EYE := 1.62                ## standing eye height
const SIT_EYE := 1.14
const LIE_EYE := 0.34
const PITCH_MAX := deg_to_rad(86.0)
const HAND := Vector3(0.27, -0.23, -0.54)      ## where a carried item sits, relative to the eyes
const MOUTH := Vector3(0.0, -0.13, -0.2)

var apartment: Apartment
@onready var body: Character = $Body
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var hand: Node3D = $Head/Camera/Hand
@onready var _shape: CollisionShape3D = $Shape
var controllable := true           ## walking and looking are yours
var look_only := false             ## seated: you can look around, not walk
var seated := false
var lying := false
var bob := true
var sensitivity := 0.0023
var pitch := 0.0
var carried_size := Vector3.ZERO   ## size of what is in the hand (pulls it in near walls)
var _eye := EYE
var _eye_want := EYE
var _seat_yaw := 0.0
var _path := PackedVector3Array()
var _path_i := 0
var _on_arrive: Callable
var _walked := 0.0
var _face_target := Vector3.INF
var _stuck := 0.0
var _walk_time := 0.0
var _walk_limit := 0.0
var _phase := 0.0
var _step_side := 0
var _bite := 0.0
var _sway := Vector2.ZERO
var _shake := 0.0
var _t := 0.0


var _arm: Node3D


func _ready() -> void:
	collision_mask = 1
	head.position.y = EYE
	dress(Character.DEFAULT_LOOK, "casual")


func dress(look: Dictionary, outfit: String) -> void:
	## Your hand and sleeve, in the skin and shirt you chose.
	if _arm != null:
		_arm.queue_free()
	var skin: Color = Character.SKINS[int(look.get("skin", 1)) % Character.SKINS.size()]
	var sleeve: Color = Character.SHIRTS[int(look.get("shirt", 0)) % Character.SHIRTS.size()]
	if outfit == "shirt":
		sleeve = Color("f4f6fb")
	elif outfit == "pajamas":
		sleeve = Color("9fb6e8")
	_arm = Kit.node(hand, Vector3.ZERO, "Arm")
	# A mitten under whatever is held, a forearm running back out of view.
	var palm := Kit.ball(_arm, 0.047, Vector3(0.012, -0.04, 0.03), skin, 10)
	palm.scale = Vector3(1.1, 0.8, 1.25)
	Kit.ball(_arm, 0.02, Vector3(-0.036, -0.022, 0.0), skin, 8)                 # thumb
	# The forearm runs from the wrist back towards your right hip.
	var wrist := Vector3(0.03, -0.075, 0.09)
	var along := Vector3(0.22, -0.5, 0.62).normalized()
	var turn := Basis(Quaternion(Vector3.UP, along))
	var fore := Kit.capsule(_arm, 0.044, 0.62, wrist + along * 0.3, sleeve, 10)
	fore.basis = turn
	var cuff := Kit.cyl(_arm, 0.052, 0.05, wrist + along * 0.03, sleeve.lightened(0.28), 12)
	cuff.basis = turn
	for mi in Kit.meshes_in(_arm):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arm.visible = false


func show_arm(on: bool) -> void:
	if _arm != null:
		_arm.visible = on


func walking_to_target() -> bool:
	return _path_i < _path.size()


func yaw() -> float:
	return rotation.y


func set_view(new_yaw: float, new_pitch: float = 0.0) -> void:
	rotation = Vector3(0, new_yaw, 0)
	pitch = clampf(new_pitch, -PITCH_MAX, PITCH_MAX)
	head.rotation = Vector3(pitch, 0, 0)


func look(relative: Vector2) -> void:
	## Mouse look, in pixels.
	if seated:
		# Sitting: your head turns, your body does not. Within reason.
		head.rotation.y = clampf(head.rotation.y - relative.x * sensitivity, -1.9, 1.9)
	else:
		rotation.y -= relative.x * sensitivity
	pitch = clampf(pitch - relative.y * sensitivity, -PITCH_MAX, PITCH_MAX)
	head.rotation.x = pitch
	_sway += relative * 0.0004
	_face_target = Vector3.INF


func eye_position() -> Vector3:
	return camera.global_position


func aim() -> Vector3:
	return -camera.global_transform.basis.z


# --- Autopilot (tests and scripted captures) ---------------------------------

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


func face(point: Vector3, instant: bool = false) -> void:
	## Turn the view towards a point in the world.
	_face_target = point
	if instant:
		var d := point - eye_position()
		set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
		_face_target = Vector3.INF


# --- Sitting and lying ---------------------------------------------------------

func sit(xf: Transform3D, lie: bool, _anim: String = "") -> void:
	## Take a seat: the body goes to the seat, the eyes to where a head would be.
	stop()
	seated = true
	lying = lie
	velocity = Vector3.ZERO
	_shape.disabled = true
	_seat_yaw = xf.basis.get_euler().y
	global_position = xf.origin
	rotation = Vector3(0, _seat_yaw, 0)
	head.rotation.y = 0.0
	_eye_want = LIE_EYE if lie else SIT_EYE
	pitch = deg_to_rad(38.0) if lie else deg_to_rad(-6.0)
	head.rotation.x = pitch
	_face_target = Vector3.INF
	# The body you only see in the menus sits or lies the same way.
	body.rotation = Vector3(PI / 2.0, 0, 0) if lie else Vector3.ZERO
	body.anim = _anim if _anim != "" else "sit"


func stand_up(at: Vector3 = Vector3.INF) -> void:
	if not seated:
		return
	seated = false
	lying = false
	body.rotation = Vector3.ZERO
	body.anim = "idle"
	# Keep looking where you were looking.
	rotation = Vector3(0, rotation.y + head.rotation.y, 0)
	head.rotation.y = 0.0
	pitch = clampf(pitch, -0.5, 0.5)
	head.rotation.x = pitch
	if at != Vector3.INF:
		global_position = Vector3(at.x, 0, at.z)
	else:
		global_position.y = 0.0
	_eye_want = EYE
	_shape.disabled = false


func pose(anim: String) -> void:
	body.anim = anim


func bite() -> void:
	## The hand comes up to the mouth and goes back.
	_bite = 1.0


func nudge(amount: float = 1.0) -> void:
	_shake = maxf(_shake, amount)


# --- Per frame -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	_update_head(delta)
	if seated:
		return
	var dir := Vector3.ZERO
	var manual := false
	var sprinting := false
	if controllable:
		var iv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if iv.length() > 0.15:
			manual = true
			dir = (global_transform.basis * Vector3(iv.x, 0, iv.y)).normalized()
			sprinting = Input.is_action_pressed("sprint") and iv.y < -0.3
			if walking_to_target():
				stop()
	if not manual and walking_to_target():
		var target := _path[_path_i]
		var to := target - global_position
		to.y = 0.0
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
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, TURN * delta))
			pitch = lerpf(pitch, 0.0, minf(1.0, 4.0 * delta))
			head.rotation.x = pitch
	var mult := 1.0
	if Game.active:
		if Game.stats.has_buff("wired"):
			mult = 1.3
		elif Game.stats.has_buff("jitter"):
			mult = 1.15
		if Game.stats.has_buff("stuffed"):
			mult *= 0.78
		if Game.stats.get_value("energy") < 12.0:
			mult *= 0.62
			sprinting = false
	var want := dir * (SPRINT if sprinting else SPEED) * mult
	velocity.x = move_toward(velocity.x, want.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, want.z, ACCEL * delta)
	velocity.y = 0.0
	var before := global_position
	move_and_slide()
	global_position.y = 0.0
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	var hs := Vector2(velocity.x, velocity.z).length()
	if walking_to_target() and not manual:
		_stuck = _stuck + delta if moved < 0.004 else 0.0
		_walk_time += delta
		if _stuck > 0.5 or _walk_time > _walk_limit:
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
		var before_phase := _phase
		_phase += delta * (9.5 if sprinting else 7.6) * (hs / SPEED)
		if int(_phase / PI) != int(before_phase / PI):
			_step_side = 1 - _step_side
			Sfx.play("step", -19.0 if sprinting else -23.0, 0.14)
		_walked += moved * (1.6 if sprinting else 1.0)
		Game.tutor.walked(moved)
		if _walked >= 1.0 and Game.active and not Game.paused and not bool(Game.time.hold):
			Game.stats.add("energy", -Cfg.MOVE_EN_PER_M * _walked, "")
			_walked = 0.0
	elif _face_target != Vector3.INF:
		var d := _face_target - eye_position()
		if d.length() > 0.05:
			rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(1.0, TURN * delta))
			pitch = lerpf(pitch, clampf(atan2(d.y, Vector2(d.x, d.z).length()), -PITCH_MAX, PITCH_MAX), minf(1.0, TURN * delta))
			head.rotation.x = pitch


func _update_head(delta: float) -> void:
	_eye = lerpf(_eye, _eye_want, minf(1.0, delta * 7.0))
	var hs := Vector2(velocity.x, velocity.z).length()
	var amount := clampf(hs / SPEED, 0.0, 1.4) if bob and not seated else 0.0
	var y := _eye + sin(_phase * 2.0) * 0.022 * amount
	var x := cos(_phase) * 0.014 * amount
	var jitter := Vector3.ZERO
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		jitter = Vector3(sin(_t * 47.0), cos(_t * 41.0), 0) * 0.004 * _shake
	head.position = Vector3(x, y, 0) + jitter
	camera.rotation.z = lerpf(camera.rotation.z, -0.35 if lying else 0.0, minf(1.0, delta * 5.0))
	# The hand: lags a little behind the view, dips with each step, comes up to bite.
	_sway = _sway.lerp(Vector2.ZERO, minf(1.0, delta * 9.0))
	_bite = maxf(0.0, _bite - delta * 3.4)
	var k := sin(clampf(_bite, 0.0, 1.0) * PI)
	var rest := HAND + Vector3(carried_size.x * 0.25, -carried_size.y * 0.45, -carried_size.z * 0.4)
	rest += Vector3(-_sway.x, _sway.y, 0) + Vector3(0, -absf(sin(_phase)) * 0.012 * amount, 0)
	hand.position = hand.position.lerp(rest.lerp(MOUTH + Vector3(0, -carried_size.y * 0.5, 0), k), minf(1.0, delta * 16.0))
	hand.rotation = Vector3(0.12 + k * 0.5, -0.35, 0.06 - k * 0.2)
