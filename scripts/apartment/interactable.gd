class_name Interactable
extends Node3D
## One usable object in the apartment. Holds where to stand, where to sit,
## a pick volume for the mouse, and the highlight overlay.

const PICK_LAYER := 2

static var _overlay: ShaderMaterial

var thing_id := ""
var title := ""
var use_local := Vector3(0, 0, 0.9)     ## where the player stands, in local space
var focus_local := Vector3(0, 0.8, 0)   ## where prompts and the camera aim
var seat := {}                          ## {pos: Vector3(local), yaw: float(local), lie: bool, root: Node3D}
var _meshes: Array = []
var _lit := false


static func overlay() -> ShaderMaterial:
	if _overlay == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.84, 0.42, 1.0);
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.6);
	float pulse = 0.5 + 0.5 * sin(TIME * 5.5);
	ALBEDO = tint.rgb;
	ALPHA = clamp(0.10 + 0.12 * pulse + fres * 0.45, 0.0, 1.0);
}
"""
		_overlay = ShaderMaterial.new()
		_overlay.shader = sh
	return _overlay


func setup(id: String, pick_size: Vector3, pick_center: Vector3) -> void:
	thing_id = id
	title = str(Home.THINGS.get(id, {"name": id}).name)
	name = "Thing_" + id
	focus_local = pick_center + Vector3(0, pick_size.y * 0.5 + 0.25, 0)
	var area := Area3D.new()
	area.collision_layer = PICK_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.input_ray_pickable = false
	area.position = pick_center
	area.set_meta("thing", self)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = pick_size
	cs.shape = box
	area.add_child(cs)
	add_child(area)


func collect_meshes() -> void:
	_meshes = Kit.meshes_in(self)


func use_point() -> Vector3:
	var p := to_global(use_local)
	p.y = 0.0
	return p


func focus_point() -> Vector3:
	return to_global(focus_local)


func seat_transform() -> Transform3D:
	## Global transform for a seated/lying character (origin at their feet).
	var root: Node3D = seat.get("root", self)
	var local := Transform3D(Basis(Vector3.UP, float(seat.get("yaw", 0.0))), seat.get("pos", Vector3.ZERO))
	return root.global_transform * local


func set_highlight(on: bool) -> void:
	if on == _lit:
		return
	_lit = on
	var m: Material = overlay() if on else null
	for mi in _meshes:
		if is_instance_valid(mi):
			(mi as MeshInstance3D).material_overlay = m
