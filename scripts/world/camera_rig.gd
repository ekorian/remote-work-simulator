class_name CameraRig
extends Node3D
## Isometric (orthographic) camera: smooth follow, 90-degree rotation steps
## with Q/E, wheel zoom, and an optional close-up mode for the desk.

const PITCH := deg_to_rad(-36.0)
const DIST := 40.0
const ZOOM_MIN := 7.5
const ZOOM_MAX := 19.0

var cam: Camera3D
var target: Node3D
var yaw_step := 0                 ## 0..3, each step is 90 degrees
var yaw := deg_to_rad(45.0)
var zoom := 12.5
var _zoom_now := 12.5
var _focus := Vector3.ZERO
var close_up := false             ## pushed in while at the computer
var orbit := 0.0                  ## >0: slow auto-rotation (menus)
var shake := 0.0
var pan := 0.0                    ## screen-space sideways shift in metres (menus)
var input_enabled := true
var _t := 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = zoom
	cam.near = 0.5
	cam.far = 120.0
	add_child(cam)
	cam.current = true
	_apply(1.0)


func target_yaw() -> float:
	return deg_to_rad(45.0 + 90.0 * yaw_step)


func rotate_step(dir: int) -> void:
	yaw_step += dir
	Bus.sfx.emit("whoosh")


func snap_to(p: Vector3) -> void:
	_focus = p
	yaw = target_yaw()
	_zoom_now = zoom
	_apply(1.0)


func _unhandled_input(e: InputEvent) -> void:
	if not input_enabled:
		return
	if e.is_action_pressed("cam_left"):
		rotate_step(-1)
	elif e.is_action_pressed("cam_right"):
		rotate_step(1)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom - 0.9, ZOOM_MIN, ZOOM_MAX)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom + 0.9, ZOOM_MIN, ZOOM_MAX)


func _process(delta: float) -> void:
	_t += delta
	if orbit > 0.0:
		yaw += orbit * delta
	else:
		yaw = lerp_angle(yaw, target_yaw(), minf(1.0, delta * 7.0))
	if target != null and is_instance_valid(target):
		var want := target.global_position + Vector3(0, 0.9, 0)
		_focus = _focus.lerp(want, minf(1.0, delta * 5.5))
	var z := zoom * (0.62 if close_up else 1.0)
	_zoom_now = lerpf(_zoom_now, z, minf(1.0, delta * 5.0))
	_apply(delta)


func _apply(_delta: float) -> void:
	var basis_yaw := Basis(Vector3.UP, yaw)
	var dir := basis_yaw * (Basis(Vector3.RIGHT, PITCH) * Vector3(0, 0, 1))
	var off := Vector3.ZERO
	if shake > 0.0:
		off = Vector3(sin(_t * 41.0), cos(_t * 37.0), sin(_t * 29.0)) * 0.012 * shake * _zoom_now
	cam.global_position = _focus + dir * DIST + off
	cam.look_at(_focus + off, Vector3.UP)
	cam.size = _zoom_now
	cam.h_offset = lerpf(cam.h_offset, pan, 1.0 if _delta >= 1.0 else minf(1.0, _delta * 4.0))


func to_camera_dir() -> Vector3:
	## Horizontal direction from the scene towards the camera.
	var d := Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
	return Vector3(d.x, 0, d.z).normalized()
