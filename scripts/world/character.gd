class_name Character
extends Node3D
## Character — a chunky low-poly person built from primitives and animated
## procedurally (no skeleton, no imported clips). Faces -Z.

const SKINS := [Color("ffdcc2"), Color("f3c19c"), Color("d9a074"), Color("b87a4f"), Color("8d5a36"), Color("5e3a22")]
const HAIR_COLORS := [Color("2b2018"), Color("5a3a22"), Color("a86a32"), Color("e6c15a"), Color("c8472f"), Color("d9d9e0"), Color("ff6fae"), Color("4fb3ff")]
const HAIR_STYLES := ["Short", "Bun", "Long", "Mohawk", "Bald", "Cap", "Curly"]
const SHIRTS := [Color("4fb3ff"), Color("ff8c5a"), Color("5ad17a"), Color("b48cff"), Color("ffd166"), Color("ff5d73"), Color("5ad1c8"), Color("8a86a8")]
const PANTS := [Color("3a4a78"), Color("2f2f3a"), Color("6b5a44"), Color("4a6b52"), Color("7a3d4f"), Color("c9c4e6")]

const DEFAULT_LOOK := {"name": "Alex", "skin": 1, "hair": 0, "hair_color": 1, "shirt": 0, "pants": 0, "glasses": false}

## Fixed looks for the cast (used for call portraits).
const CAST := {
	"todd": {"skin": 0, "hair": 4, "hair_color": 5, "shirt": 1, "pants": 1, "glasses": true, "tie": true, "stache": true},
	"priya": {"skin": 3, "hair": 2, "hair_color": 0, "shirt": 6, "pants": 1, "glasses": true},
	"kevin": {"skin": 1, "hair": 3, "hair_color": 3, "shirt": 0, "pants": 0, "glasses": false},
	"dave": {"skin": 2, "hair": 6, "hair_color": 1, "shirt": 4, "pants": 2, "glasses": false, "stache": true},
	"linda": {"skin": 0, "hair": 1, "hair_color": 4, "shirt": 5, "pants": 1, "glasses": true},
	"it": {"skin": 4, "hair": 5, "hair_color": 7, "shirt": 3, "pants": 1, "glasses": false},
}

var look: Dictionary = DEFAULT_LOOK.duplicate()
var outfit := "casual"
var anim := "idle"
var talking := false
var walk_phase := 0.0
var speed_ratio := 0.0        ## 0..1, set by whoever moves the character

var _body: Node3D
var _head: Node3D
var _mouth: MeshInstance3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _shin_l: Node3D
var _shin_r: Node3D
var _t := 0.0
var _zzz: Label3D
var _blink := 0.0
var _eyes: Array = []


func _ready() -> void:
	rebuild()


func set_look(l: Dictionary, new_outfit: String = "") -> void:
	look = DEFAULT_LOOK.duplicate()
	for k in l:
		look[k] = l[k]
	if new_outfit != "":
		outfit = new_outfit
	if is_inside_tree():
		rebuild()


func set_outfit(o: String) -> void:
	if o != outfit:
		outfit = o
		if is_inside_tree():
			rebuild()


func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_eyes.clear()
	var skin: Color = SKINS[int(look.skin) % SKINS.size()]
	var hair_c: Color = HAIR_COLORS[int(look.hair_color) % HAIR_COLORS.size()]
	var shirt: Color = SHIRTS[int(look.shirt) % SHIRTS.size()]
	var pants: Color = PANTS[int(look.pants) % PANTS.size()]
	var sleeve := shirt
	var tie := bool(look.get("tie", false))
	match outfit:
		"shirt":
			shirt = Color("f4f6fb")
			sleeve = shirt
			pants = Color("9fb6e8")
			tie = true
		"pajamas":
			shirt = Color("9fb6e8")
			sleeve = shirt
			pants = Color("9fb6e8")

	_body = Kit.node(self, Vector3(0, 0.56, 0), "Body")
	# Torso
	Kit.cyl(_body, 0.25, 0.5, Vector3(0, 0.25, 0), shirt, 8, 0.2)
	if outfit == "casual":
		Kit.box(_body, Vector3(0.2, 0.1, 0.05), Vector3(0, 0.16, -0.22), shirt.darkened(0.18))   # hoodie pocket
	if outfit == "pajamas":
		for i in 3:
			Kit.ball(_body, 0.025, Vector3(0, 0.12 + 0.13 * i, -0.215 + 0.012 * i), Color("f4f6fb"), 6)
	if tie:
		Kit.box(_body, Vector3(0.07, 0.3, 0.03), Vector3(0, 0.27, -0.2), Color("d6455b"))
		Kit.box(_body, Vector3(0.1, 0.07, 0.035), Vector3(0, 0.45, -0.19), Color("d6455b"))
	# Neck + head
	Kit.cyl(_body, 0.08, 0.1, Vector3(0, 0.53, 0), skin.darkened(0.08), 8)
	_head = Kit.node(_body, Vector3(0, 0.56, 0), "Head")
	Kit.ball(_head, 0.29, Vector3(0, 0.24, 0), skin, 12)
	for sx in [-1.0, 1.0]:
		var eye := Kit.ball(_head, 0.038, Vector3(0.105 * sx, 0.26, -0.262), Color("1b182a"), 8)
		_eyes.append(eye)
		Kit.ball(_head, 0.06, Vector3(0.29 * sx, 0.22, 0.0), skin.darkened(0.06), 8)   # ears
	_mouth = Kit.box(_head, Vector3(0.1, 0.022, 0.02), Vector3(0, 0.13, -0.272), Color("7a3d4f"))
	if bool(look.get("stache", false)):
		Kit.box(_head, Vector3(0.17, 0.045, 0.03), Vector3(0, 0.17, -0.275), hair_c.darkened(0.1))
	if bool(look.get("glasses", false)):
		for sx in [-1.0, 1.0]:
			Kit.box(_head, Vector3(0.12, 0.09, 0.02), Vector3(0.105 * sx, 0.26, -0.285), Color(0.75, 0.9, 1.0, 0.45), 0.2)
			Kit.box(_head, Vector3(0.14, 0.018, 0.022), Vector3(0.105 * sx, 0.31, -0.286), Color("2b2542"))
		Kit.box(_head, Vector3(0.07, 0.016, 0.02), Vector3(0, 0.275, -0.286), Color("2b2542"))
	_build_hair(hair_c)
	# Arms
	_arm_l = _limb(_body, Vector3(-0.27, 0.42, 0), 0.34, 0.075, sleeve, skin)
	_arm_r = _limb(_body, Vector3(0.27, 0.42, 0), 0.34, 0.075, sleeve, skin)
	# Legs (thigh + shin so the character can sit)
	_leg_l = Kit.node(self, Vector3(-0.115, 0.56, 0), "LegL")
	_leg_r = Kit.node(self, Vector3(0.115, 0.56, 0), "LegR")
	_shin_l = _leg(_leg_l, pants)
	_shin_r = _leg(_leg_r, pants)

	_zzz = Label3D.new()
	_zzz.text = "z Z z"
	_zzz.font_size = 64
	_zzz.pixel_size = 0.004
	_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_zzz.no_depth_test = true
	_zzz.modulate = Color(1, 1, 1, 0.9)
	_zzz.outline_size = 12
	_zzz.position = Vector3(0, 1.9, 0)
	_zzz.visible = false
	add_child(_zzz)


func _limb(parent: Node3D, pos: Vector3, length: float, radius: float, color: Color, hand: Color) -> Node3D:
	var pivot := Kit.node(parent, pos)
	Kit.cyl(pivot, radius, length, Vector3(0, -length / 2.0, 0), color, 6)
	Kit.ball(pivot, radius * 1.15, Vector3(0, -length - 0.02, 0), hand, 8)
	return pivot


func _leg(pivot: Node3D, color: Color) -> Node3D:
	Kit.cyl(pivot, 0.095, 0.28, Vector3(0, -0.14, 0), color, 6)
	var knee := Kit.node(pivot, Vector3(0, -0.28, 0))
	Kit.cyl(knee, 0.085, 0.24, Vector3(0, -0.12, 0), color, 6)
	var shoe := Color("f4f6fb") if outfit != "pajamas" else Color("ff9ecb")
	Kit.box(knee, Vector3(0.14, 0.08, 0.24), Vector3(0, -0.24, -0.04), shoe)
	return knee


func _build_hair(c: Color) -> void:
	var top := Vector3(0, 0.27, 0.015)
	match int(look.hair) % HAIR_STYLES.size():
		0:  # short
			var d := Kit.dome(_head, 0.305, top, c, 12)
			d.rotation_degrees.x = 12
		1:  # bun
			var d := Kit.dome(_head, 0.305, top, c, 12)
			d.rotation_degrees.x = 12
			Kit.ball(_head, 0.13, Vector3(0, 0.6, 0.06), c, 8)
		2:  # long
			var d := Kit.dome(_head, 0.31, top, c, 12)
			d.rotation_degrees.x = 10
			Kit.box(_head, Vector3(0.56, 0.5, 0.16), Vector3(0, 0.06, 0.2), c)
			Kit.box(_head, Vector3(0.08, 0.42, 0.3), Vector3(-0.28, 0.08, 0.06), c)
			Kit.box(_head, Vector3(0.08, 0.42, 0.3), Vector3(0.28, 0.08, 0.06), c)
		3:  # mohawk
			Kit.box(_head, Vector3(0.09, 0.2, 0.5), Vector3(0, 0.56, 0.02), c)
		4:  # bald, with a little fringe round the back
			Kit.box(_head, Vector3(0.6, 0.12, 0.2), Vector3(0, 0.22, 0.2), c)
		5:  # cap
			var d := Kit.dome(_head, 0.31, top, c, 12)
			d.rotation_degrees.x = 4
			Kit.box(_head, Vector3(0.36, 0.035, 0.24), Vector3(0, 0.33, -0.36), c.darkened(0.15))
		6:  # curly
			for p in [Vector3(0, 0.5, 0.0), Vector3(-0.17, 0.44, 0.02), Vector3(0.17, 0.44, 0.02), Vector3(0, 0.42, 0.18), Vector3(-0.14, 0.4, -0.12), Vector3(0.14, 0.4, -0.12), Vector3(0, 0.46, -0.12)]:
				Kit.ball(_head, 0.15, p, c, 8)


func _process(delta: float) -> void:
	if _body == null:
		return
	_t += delta
	var k := minf(1.0, delta * 12.0)
	# Targets (radians). Positive X rotation swings a limb backwards.
	var body_y := 0.56
	var lean := 0.0
	var head_x := 0.0
	var al := 0.0
	var ar := 0.0
	var ll := 0.0
	var lr := 0.0
	var sl := 0.0
	var sr := 0.0
	var arm_spread := 0.06
	var sleeping := false
	var s := sin(_t * 2.0)
	match anim:
		"walk":
			var sw := sin(walk_phase) * 0.75 * clampf(speed_ratio, 0.3, 1.0)
			ll = sw
			lr = -sw
			sl = maxf(0.0, -sw) * 0.9
			sr = maxf(0.0, sw) * 0.9
			al = -sw * 0.8
			ar = sw * 0.8
			body_y += absf(cos(walk_phase)) * 0.035
			lean = -0.06
		"sit":
			body_y = 0.5
			ll = -1.5
			lr = -1.5
			sl = 1.5
			sr = 1.5
			al = -0.25
			ar = -0.25
		"type":
			body_y = 0.5
			ll = -1.5
			lr = -1.5
			sl = 1.5
			sr = 1.5
			al = -1.15 + sin(_t * 17.0) * 0.07
			ar = -1.15 + sin(_t * 19.0 + 1.3) * 0.07
			lean = -0.1
			head_x = -0.08 + sin(_t * 0.9) * 0.03
		"sit_sleep":
			body_y = 0.5
			ll = -1.5
			lr = -1.5
			sl = 1.5
			sr = 1.5
			lean = 0.12
			head_x = 0.5 + s * 0.04
			sleeping = true
		"lounge":
			body_y = 0.48
			ll = -1.35
			lr = -1.25
			sl = 0.5
			sr = 0.35
			lean = 0.38
			al = 0.25
			ar = 0.2
			head_x = -0.15
			arm_spread = 0.35
		"game":
			body_y = 0.5
			ll = -1.5
			lr = -1.5
			sl = 1.5
			sr = 1.5
			lean = -0.2 + sin(_t * 3.1) * 0.04
			al = -0.95 + sin(_t * 9.0) * 0.06
			ar = -0.95 + sin(_t * 11.0) * 0.06
			arm_spread = -0.16
		"sit_eat":
			body_y = 0.5
			ll = -1.5
			lr = -1.5
			sl = 1.5
			sr = 1.5
			al = -0.6
			ar = -1.5 - maxf(0.0, sin(_t * 3.4)) * 0.9
			head_x = -0.1
		"eat", "drink":
			ar = -1.3 - maxf(0.0, sin(_t * 3.4)) * 1.0
			al = -0.1
		"read":
			al = -1.2
			ar = -1.2
			head_x = 0.32 + sin(_t * 0.7) * 0.03
			arm_spread = -0.2
		"use":
			al = -1.0 + sin(_t * 6.0) * 0.18
			ar = -1.0 + sin(_t * 7.0 + 1.0) * 0.18
			lean = -0.12
			head_x = 0.12
		"workout":
			body_y = 0.62
			var cy := _t * 9.0
			ll = -1.0 + sin(cy) * 0.5
			lr = -1.0 - sin(cy) * 0.5
			sl = 1.1 + cos(cy) * 0.4
			sr = 1.1 - cos(cy) * 0.4
			al = -1.2
			ar = -1.2
			lean = -0.38 + sin(cy * 2.0) * 0.02
		"sleep":
			sleeping = true
			al = 0.0
			ar = 0.0
			arm_spread = 0.2
		"wave":
			ar = -2.6 + sin(_t * 9.0) * 0.3
			arm_spread = 0.3
		_:  # idle
			body_y += s * 0.008
			al = s * 0.04
			ar = -s * 0.04
			head_x = sin(_t * 0.6) * 0.03
	if talking:
		head_x += sin(_t * 7.0) * 0.035
	_body.position.y = lerpf(_body.position.y, body_y, k)
	_leg_l.position.y = _body.position.y
	_leg_r.position.y = _body.position.y
	_body.rotation.x = lerp_angle(_body.rotation.x, lean, k)
	_head.rotation.x = lerp_angle(_head.rotation.x, head_x, k)
	_arm_l.rotation.x = lerp_angle(_arm_l.rotation.x, al, k)
	_arm_r.rotation.x = lerp_angle(_arm_r.rotation.x, ar, k)
	_arm_l.rotation.z = lerp_angle(_arm_l.rotation.z, -arm_spread, k)
	_arm_r.rotation.z = lerp_angle(_arm_r.rotation.z, arm_spread, k)
	_leg_l.rotation.x = lerp_angle(_leg_l.rotation.x, ll, k)
	_leg_r.rotation.x = lerp_angle(_leg_r.rotation.x, lr, k)
	_shin_l.rotation.x = lerp_angle(_shin_l.rotation.x, sl, k)
	_shin_r.rotation.x = lerp_angle(_shin_r.rotation.x, sr, k)
	# Mouth and eyes
	var open := 0.022
	if talking:
		open = 0.03 + absf(sin(_t * 13.0)) * 0.07
	_mouth.scale.y = lerpf(_mouth.scale.y, open / 0.022, minf(1.0, delta * 25.0))
	_blink -= delta
	var closed := sleeping or _blink < 0.12
	if _blink < 0.0:
		_blink = randf_range(2.0, 5.0)
	for e in _eyes:
		e.scale.y = lerpf(e.scale.y, 0.15 if closed else 1.0, minf(1.0, delta * 30.0))
	_zzz.visible = sleeping
	if sleeping:
		_zzz.position.y = 1.75 + fmod(_t * 0.35, 0.5)
		_zzz.modulate.a = 1.0 - fmod(_t * 0.35, 0.5) * 1.6
