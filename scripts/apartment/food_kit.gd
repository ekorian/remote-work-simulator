class_name FoodKit
extends RefCounted
## FoodKit — every junk food, drink, wrapper and desk toy in the flat, built
## from Kit primitives. No imported models.
##
## `build(model, parent, tint)` returns {root, pieces, body, size}:
##   root    the model, origin at the centre of its base, front towards +Z
##   pieces  parts that vanish one by one as it is eaten (fries, slices...)
##   body    the edible lump that shrinks with each bite, for one-piece foods
##   size    bounding box, used for its collider and for how it is held

const BUN := Color("e2a55a")
const BUN_DARK := Color("c98a45")
const DOUGH := Color("f1d09c")
const CRUST := Color("d99a52")
const PATTY := Color("5c3a28")
const CHEESE := Color("ffc533")
const LETTUCE := Color("73d05c")
const TOMATO := Color("e23b3b")
const MUSTARD := Color("f6d23c")
const CHOC := Color("5b3823")
const CHOC_DARK := Color("3f2616")
const CREAM := Color("fff3de")
const FOIL := Color("cfd6de")
const PAPER := Color("fbf8f1")
const CARTON := Color("e63946")
const FRY := Color("ffd24a")
const GOLD := Color("d8943a")
const WAFER := Color("e0b070")
const STRAW := Color("ff5d73")
const SPRINKLES := [Color("ff5d73"), Color("4fb3ff"), Color("ffd166"), Color("5ad17a"), Color("fff3de"), Color("b48cff")]

## Every model id `build` knows, in menu order.
const MODELS := [
	"donut", "cookie", "choc_bar", "candy_bar", "lollipop", "gummies", "cupcake", "cake_slice", "pretzel", "pop_tart",
	"cone", "ice_tub", "popsicle", "pudding",
	"chips", "popcorn", "nachos", "cereal", "onion_rings",
	"pizza_slice", "pizza_box", "burger", "hot_dog", "fries", "nuggets", "taco", "burrito", "toastie", "drumsticks", "corn_dog", "noodles", "pancakes", "waffle",
	"soda_can", "energy_can", "soda_cup", "milkshake", "choc_milk",
]
const TRASH := ["trash_wrapper", "trash_can", "trash_cup", "trash_box", "trash_bag", "trash_stick", "trash_pizza_box"]
const TOYS := ["stress_ball", "rubber_duck", "paper_ball"]


static func has(model: String) -> bool:
	return model in MODELS or model in TRASH or model in TOYS


static func build(model: String, parent: Node3D, tint: Color = Color.WHITE) -> Dictionary:
	var n := Kit.node(parent, Vector3.ZERO, "Model")
	var out := {"root": n, "pieces": [], "body": null, "size": Vector3(0.1, 0.1, 0.1)}
	match model:
		"donut": _donut(n, tint, out)
		"cookie": _cookie(n, out)
		"choc_bar": _choc_bar(n, tint, out)
		"candy_bar": _candy_bar(n, tint, out)
		"lollipop": _lollipop(n, tint, out)
		"gummies": _gummies(n, tint, out)
		"cupcake": _cupcake(n, tint, out)
		"cake_slice": _cake_slice(n, tint, out)
		"pretzel": _pretzel(n, out)
		"pop_tart": _pop_tart(n, tint, out)
		"cone": _cone(n, tint, out)
		"ice_tub": _ice_tub(n, tint, out)
		"popsicle": _popsicle(n, tint, out)
		"pudding": _pudding(n, tint, out)
		"chips": _chips(n, tint, out)
		"popcorn": _popcorn(n, out)
		"nachos": _nachos(n, out)
		"cereal": _cereal(n, tint, out)
		"onion_rings": _onion_rings(n, out)
		"pizza_slice": _pizza_slice(n, out)
		"pizza_box": _pizza_box(n, out, true)
		"burger": _burger(n, out)
		"hot_dog": _hot_dog(n, out)
		"fries": _fries(n, out)
		"nuggets": _nuggets(n, out)
		"taco": _taco(n, out)
		"burrito": _burrito(n, out)
		"toastie": _toastie(n, out)
		"drumsticks": _drumsticks(n, out)
		"corn_dog": _corn_dog(n, out)
		"noodles": _noodles(n, tint, out)
		"pancakes": _pancakes(n, out)
		"waffle": _waffle(n, out)
		"soda_can": _can(n, tint, out, 0.033, 0.122)
		"energy_can": _can(n, tint, out, 0.027, 0.16)
		"soda_cup": _soda_cup(n, tint, out)
		"milkshake": _milkshake(n, tint, out)
		"choc_milk": _carton(n, tint, out)
		"trash_wrapper": _crumple(n, tint, out, 0.035)
		"trash_can": _crushed_can(n, tint, out)
		"trash_cup": _empty_cup(n, tint, out)
		"trash_box": _greasy_box(n, out)
		"trash_bag": _empty_bag(n, tint, out)
		"trash_stick": _stick(n, out)
		"trash_pizza_box": _pizza_box(n, out, false)
		"stress_ball": _stress_ball(n, tint, out)
		"rubber_duck": _rubber_duck(n, out)
		"paper_ball": _crumple(n, PAPER, out, 0.045)
		_:
			Kit.box(n, Vector3(0.08, 0.08, 0.08), Vector3(0, 0.04, 0), Color("ff00ff"))
	return out


# --- helpers -----------------------------------------------------------------

static func _ring(count: int, radius: float, i: int, phase: float = 0.0) -> Vector3:
	var a := TAU * float(i) / float(count) + phase
	return Vector3(cos(a) * radius, 0.0, sin(a) * radius)


static func _jit(i: int, k: float) -> float:
	## Small repeatable offset, so piles look hand-made but never change.
	return (fposmod(sin(float(i) * 12.9898 + k * 78.233) * 43758.5453, 1.0) - 0.5) * 2.0


static func _sprinkle(n: Node3D, count: int, radius: float, y: float, colors: Array = SPRINKLES) -> void:
	for i in count:
		var p := _ring(count, radius * (0.75 + 0.25 * _jit(i, 1.0)), i, 0.3)
		var s := Kit.box(n, Vector3(0.012, 0.004, 0.004), Vector3(p.x, y, p.z), colors[i % colors.size()])
		s.rotation.y = _jit(i, 2.0) * PI


# --- sweet -------------------------------------------------------------------

static func _donut(n: Node3D, icing: Color, out: Dictionary) -> void:
	var b := Kit.node(n, Vector3(0, 0.022, 0))
	Kit.torus(b, 0.036, 0.022, Vector3.ZERO, DOUGH)
	var top := Kit.torus(b, 0.036, 0.0205, Vector3(0, 0.008, 0), icing)
	top.scale.y = 0.72
	_sprinkle(b, 11, 0.036, 0.024)
	out.body = b
	out.size = Vector3(0.12, 0.05, 0.12)


static func _cookie(n: Node3D, out: Dictionary) -> void:
	var b := Kit.node(n, Vector3(0, 0.009, 0))
	Kit.cyl(b, 0.05, 0.018, Vector3.ZERO, Color("d6a15a"), 12, 0.046)
	for i in 7:
		var p := _ring(7, 0.03 * (0.5 + 0.5 * absf(_jit(i, 3.0))), i)
		Kit.ball(b, 0.008, Vector3(p.x, 0.008, p.z), CHOC_DARK, 6)
	out.body = b
	out.size = Vector3(0.1, 0.02, 0.1)


static func _choc_bar(n: Node3D, wrap: Color, out: Dictionary) -> void:
	# Half unwrapped: four rows of squares, the rest still in foil and paper.
	for r in 4:
		var row := Kit.node(n, Vector3(0, 0.008, -0.062 + r * 0.026))
		Kit.box(row, Vector3(0.062, 0.012, 0.024), Vector3.ZERO, CHOC)
		for c in 2:
			Kit.box(row, Vector3(0.024, 0.006, 0.018), Vector3(-0.015 + c * 0.03, 0.008, 0), CHOC.lightened(0.08))
		out.pieces.append(row)
	Kit.box(n, Vector3(0.07, 0.016, 0.07), Vector3(0, 0.008, 0.062), wrap)
	Kit.box(n, Vector3(0.071, 0.017, 0.016), Vector3(0, 0.008, 0.07), CREAM)
	Kit.box(n, Vector3(0.066, 0.004, 0.012), Vector3(0, 0.013, 0.024), FOIL)
	out.size = Vector3(0.07, 0.02, 0.18)


static func _candy_bar(n: Node3D, wrap: Color, out: Dictionary) -> void:
	var b := Kit.node(n, Vector3(0, 0.011, 0))
	Kit.box(b, Vector3(0.04, 0.02, 0.12), Vector3.ZERO, wrap)
	Kit.box(b, Vector3(0.041, 0.021, 0.03), Vector3(0, 0, 0.012), wrap.lightened(0.45))
	for s in [-1.0, 1.0]:
		Kit.box(b, Vector3(0.044, 0.004, 0.014), Vector3(0, 0, 0.066 * s), wrap.darkened(0.15))
	out.body = b
	out.size = Vector3(0.045, 0.022, 0.15)


static func _lollipop(n: Node3D, color: Color, out: Dictionary) -> void:
	Kit.cyl(n, 0.004, 0.13, Vector3(0, 0.065, 0), PAPER, 6)
	var b := Kit.node(n, Vector3(0, 0.15, 0))
	var disc := Kit.cyl(b, 0.035, 0.014, Vector3.ZERO, color, 14)
	disc.rotation.x = PI / 2.0
	var swirl := Kit.torus(b, 0.019, 0.005, Vector3(0, 0, 0.006), CREAM, 12, 6)
	swirl.rotation.x = PI / 2.0
	Kit.ball(b, 0.007, Vector3(0, 0, 0.008), CREAM, 6)
	out.body = b
	out.size = Vector3(0.07, 0.19, 0.03)


static func _gummies(n: Node3D, color: Color, out: Dictionary) -> void:
	Kit.box(n, Vector3(0.1, 0.13, 0.03), Vector3(0, 0.065, 0), Color(color, 0.42))
	Kit.box(n, Vector3(0.104, 0.03, 0.012), Vector3(0, 0.138, 0), color)
	Kit.box(n, Vector3(0.07, 0.03, 0.032), Vector3(0, 0.1, 0), CREAM)
	for i in 8:
		var bear := Kit.node(n, Vector3(-0.03 + (i % 4) * 0.02, 0.022 + int(i / 4.0) * 0.03, _jit(i, 4.0) * 0.004))
		Kit.capsule(bear, 0.009, 0.026, Vector3.ZERO, SPRINKLES[i % 4], 6)
		out.pieces.append(bear)
	out.size = Vector3(0.11, 0.16, 0.04)


static func _cupcake(n: Node3D, frosting: Color, out: Dictionary) -> void:
	Kit.cyl(n, 0.026, 0.036, Vector3(0, 0.018, 0), Color("ff9ecb"), 10, 0.036)
	var b := Kit.node(n, Vector3(0, 0.036, 0))
	Kit.dome(b, 0.038, Vector3(0, 0, 0), Color("c98a4b"), 10)
	Kit.cyl(b, 0.034, 0.016, Vector3(0, 0.022, 0), frosting, 10, 0.026)
	Kit.cyl(b, 0.025, 0.016, Vector3(0, 0.036, 0), frosting, 10, 0.016)
	Kit.cone(b, 0.016, 0.02, Vector3(0, 0.052, 0), frosting, 8)
	Kit.ball(b, 0.01, Vector3(0, 0.066, 0), TOMATO, 8)
	out.body = b
	out.size = Vector3(0.08, 0.11, 0.08)


static func _cake_slice(n: Node3D, icing: Color, out: Dictionary) -> void:
	Kit.cyl(n, 0.07, 0.006, Vector3(0, 0.003, 0), PAPER, 14)
	var b := Kit.node(n, Vector3(0, 0.006, 0))
	for layer in 2:
		Kit.wedge(b, Vector3(0.075, 0.024, 0.1), Vector3(0, 0.012 + layer * 0.032, 0), CHOC)
		Kit.wedge(b, Vector3(0.077, 0.008, 0.102), Vector3(0, 0.028 + layer * 0.032, 0), icing)
	Kit.box(b, Vector3(0.079, 0.066, 0.008), Vector3(0, 0.033, -0.052), icing)
	Kit.ball(b, 0.011, Vector3(0, 0.074, -0.03), TOMATO, 8)
	out.body = b
	out.size = Vector3(0.14, 0.09, 0.14)


static func _pretzel(n: Node3D, out: Dictionary) -> void:
	var b := Kit.node(n, Vector3(0, 0.011, 0))
	for s in [-1.0, 1.0]:
		Kit.torus(b, 0.026, 0.011, Vector3(0.022 * s, 0, -0.012), BUN_DARK, 12, 6)
	var knot := Kit.capsule(b, 0.011, 0.07, Vector3(0, 0.002, 0.03), BUN_DARK, 8)
	knot.rotation.z = PI / 2.0
	for i in 9:
		Kit.box(b, Vector3(0.005, 0.004, 0.005), Vector3(_jit(i, 5.0) * 0.045, 0.012, _jit(i, 6.0) * 0.035), PAPER)
	out.body = b
	out.size = Vector3(0.12, 0.03, 0.1)


static func _pop_tart(n: Node3D, icing: Color, out: Dictionary) -> void:
	var b := Kit.node(n, Vector3(0, 0.007, 0))
	Kit.box(b, Vector3(0.075, 0.012, 0.105), Vector3.ZERO, Color("e8c07e"))
	Kit.box(b, Vector3(0.06, 0.004, 0.09), Vector3(0, 0.008, 0), icing)
	_sprinkle(b, 9, 0.028, 0.012)
	out.body = b
	out.size = Vector3(0.08, 0.02, 0.11)


# --- frozen ------------------------------------------------------------------

static func _cone(n: Node3D, flavour: Color, out: Dictionary) -> void:
	var wafer := Kit.cone(n, 0.032, 0.11, Vector3(0, 0.055, 0), WAFER, 10)
	wafer.rotation.x = PI
	Kit.torus(n, 0.031, 0.004, Vector3(0, 0.11, 0), WAFER.darkened(0.1), 10, 5)
	var b := Kit.node(n, Vector3(0, 0.118, 0))
	Kit.ball(b, 0.036, Vector3(0, 0.014, 0), flavour, 10)
	var second := Kit.ball(b, 0.03, Vector3(0.004, 0.058, 0), CREAM, 10)
	Kit.ball(b, 0.009, Vector3(0.004, 0.09, 0), TOMATO, 6)
	out.pieces.append(second)
	out.body = b
	out.size = Vector3(0.08, 0.22, 0.08)


static func _ice_tub(n: Node3D, flavour: Color, out: Dictionary) -> void:
	Kit.cyl(n, 0.042, 0.085, Vector3(0, 0.0425, 0), flavour.lightened(0.25), 14, 0.05)
	Kit.cyl(n, 0.051, 0.006, Vector3(0, 0.083, 0), PAPER, 14)
	Kit.box(n, Vector3(0.06, 0.03, 0.004), Vector3(0, 0.045, 0.047), PAPER)
	var b := Kit.node(n, Vector3(0, 0.086, 0))
	for i in 3:
		var p := _ring(3, 0.018, i)
		Kit.ball(b, 0.024, Vector3(p.x, 0.004, p.z), flavour, 8)
	out.body = b
	var spoon := Kit.box(n, Vector3(0.012, 0.09, 0.004), Vector3(0.02, 0.12, -0.01), FOIL)
	spoon.rotation.z = -0.3
	out.size = Vector3(0.11, 0.16, 0.11)


static func _popsicle(n: Node3D, flavour: Color, out: Dictionary) -> void:
	Kit.box(n, Vector3(0.012, 0.07, 0.004), Vector3(0, 0.035, 0), WAFER)
	var b := Kit.node(n, Vector3(0, 0.062, 0))
	var bar := Kit.capsule(b, 0.022, 0.1, Vector3(0, 0.05, 0), flavour, 10)
	bar.scale.z = 0.55
	var tip := Kit.capsule(b, 0.0225, 0.05, Vector3(0, 0.076, 0), flavour.lightened(0.3), 10)
	tip.scale.z = 0.56
	out.body = b
	out.size = Vector3(0.05, 0.17, 0.03)


static func _pudding(n: Node3D, flavour: Color, out: Dictionary) -> void:
	Kit.cyl(n, 0.03, 0.05, Vector3(0, 0.025, 0), Color(1, 1, 1, 0.5), 12, 0.04)
	var b := Kit.node(n, Vector3(0, 0.004, 0))
	Kit.cyl(b, 0.027, 0.04, Vector3(0, 0.022, 0), flavour, 12, 0.037)
	Kit.dome(b, 0.02, Vector3(0, 0.042, 0), CREAM, 8)
	out.body = b
	var lid := Kit.cyl(n, 0.042, 0.003, Vector3(0.02, 0.058, 0), FOIL, 12)
	lid.rotation.z = 0.7
	out.size = Vector3(0.09, 0.08, 0.09)


# --- crunchy -----------------------------------------------------------------

static func _chips(n: Node3D, color: Color, out: Dictionary) -> void:
	# A puffed foil bag, torn open at the top.
	var bag := Kit.ball(n, 0.075, Vector3(0, 0.1, 0), color, 10)
	bag.scale = Vector3(1.0, 1.25, 0.42)
	Kit.box(n, Vector3(0.15, 0.022, 0.012), Vector3(0, 0.012, 0), color.darkened(0.2))
	Kit.box(n, Vector3(0.15, 0.018, 0.02), Vector3(0, 0.196, 0), color.darkened(0.2))
	var logo := Kit.cyl(n, 0.04, 0.004, Vector3(0, 0.1, 0.032), MUSTARD, 14)
	logo.rotation.x = PI / 2.0
	Kit.box(n, Vector3(0.05, 0.014, 0.005), Vector3(0, 0.1, 0.035), TOMATO)
	for i in 5:
		var chip := Kit.cyl(n, 0.022, 0.003, Vector3(-0.04 + i * 0.02, 0.2 + absf(_jit(i, 7.0)) * 0.012, _jit(i, 8.0) * 0.008), FRY.darkened(0.05), 8)
		chip.rotation = Vector3(0.5 + _jit(i, 9.0) * 0.5, _jit(i, 10.0), 0.3)
		out.pieces.append(chip)
	out.size = Vector3(0.16, 0.23, 0.07)


static func _popcorn(n: Node3D, out: Dictionary) -> void:
	Kit.cyl(n, 0.05, 0.13, Vector3(0, 0.065, 0), PAPER, 12, 0.068)
	for i in 6:
		var p := _ring(6, 0.06, i)
		var stripe := Kit.box(n, Vector3(0.022, 0.126, 0.006), Vector3(p.x, 0.065, p.z), CARTON)
		stripe.rotation.y = -atan2(p.z, p.x) + PI / 2.0
		stripe.rotation.x = 0.0
	for i in 16:
		var p := _ring(8, 0.05 if i < 8 else 0.024, i, 0.4 * float(i))
		var kernel := Kit.ball(n, 0.019, Vector3(p.x, 0.132 + (0.0 if i < 8 else 0.02) + absf(_jit(i, 11.0)) * 0.008, p.z), Color("fff6d6") if i % 3 else FRY, 6)
		out.pieces.append(kernel)
	out.size = Vector3(0.15, 0.17, 0.15)


static func _nachos(n: Node3D, out: Dictionary) -> void:
	Kit.box(n, Vector3(0.16, 0.012, 0.11), Vector3(0, 0.006, 0), Color("2f2c3e"))
	for s in [-1.0, 1.0]:
		Kit.box(n, Vector3(0.16, 0.03, 0.006), Vector3(0, 0.02, 0.055 * s), Color("2f2c3e"))
	Kit.cyl(n, 0.026, 0.03, Vector3(0.05, 0.027, 0), PAPER, 10)
	Kit.cyl(n, 0.022, 0.006, Vector3(0.05, 0.042, 0), CHEESE, 10)
	for i in 9:
		var chip := Kit.wedge(n, Vector3(0.04, 0.004, 0.04), Vector3(-0.05 + (i % 3) * 0.025, 0.022 + int(i / 3.0) * 0.008, -0.03 + int(i / 3.0) * 0.03), FRY.darkened(0.08))
		chip.rotation = Vector3(PI / 2.0 + _jit(i, 12.0) * 0.5, _jit(i, 13.0) * 2.0, _jit(i, 14.0) * 0.4)
		out.pieces.append(chip)
	out.size = Vector3(0.17, 0.06, 0.12)


static func _cereal(n: Node3D, color: Color, out: Dictionary) -> void:
	Kit.box(n, Vector3(0.14, 0.2, 0.05), Vector3(0, 0.1, 0), color)
	Kit.box(n, Vector3(0.1, 0.06, 0.052), Vector3(0, 0.15, 0), MUSTARD)
	var bowl := Kit.cyl(n, 0.04, 0.006, Vector3(0, 0.07, 0.026), PAPER, 12)
	bowl.rotation.x = PI / 2.0
	for i in 6:
		var loop := Kit.torus(n, 0.009, 0.004, Vector3(_jit(i, 15.0) * 0.045, 0.205 + absf(_jit(i, 16.0)) * 0.01, _jit(i, 17.0) * 0.012), SPRINKLES[i % 4], 8, 5)
		loop.rotation.x = _jit(i, 18.0)
		out.pieces.append(loop)
	out.size = Vector3(0.145, 0.22, 0.055)


static func _onion_rings(n: Node3D, out: Dictionary) -> void:
	Kit.box(n, Vector3(0.11, 0.008, 0.11), Vector3(0, 0.004, 0), PAPER)
	for i in 5:
		var ring := Kit.torus(n, 0.028, 0.009, Vector3(_jit(i, 19.0) * 0.012, 0.018 + i * 0.016, _jit(i, 20.0) * 0.012), GOLD, 12, 6)
		ring.rotation = Vector3(_jit(i, 21.0) * 0.12, 0, _jit(i, 22.0) * 0.12)
		out.pieces.append(ring)
	out.size = Vector3(0.11, 0.1, 0.11)


# --- hot ---------------------------------------------------------------------

static func _slice(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var s := Kit.node(parent, pos)
	s.rotation.y = yaw
	Kit.wedge(s, Vector3(0.1, 0.01, 0.15), Vector3(0, 0.005, 0.075), DOUGH)
	Kit.wedge(s, Vector3(0.088, 0.004, 0.128), Vector3(0, 0.012, 0.074), CHEESE)
	var crust := Kit.capsule(s, 0.012, 0.11, Vector3(0, 0.01, 0.004), CRUST, 8)
	crust.rotation.z = PI / 2.0
	for p in [Vector3(-0.018, 0.016, 0.04), Vector3(0.02, 0.016, 0.05), Vector3(0, 0.016, 0.092)]:
		Kit.cyl(s, 0.013, 0.004, p, TOMATO.darkened(0.12), 8)
	return s


static func _pizza_slice(n: Node3D, out: Dictionary) -> void:
	out.body = _slice(n, Vector3(0, 0, -0.075), 0.0)
	out.size = Vector3(0.11, 0.03, 0.16)


static func _pizza_box(n: Node3D, out: Dictionary, full: bool) -> void:
	var card := Color("c9a06b")
	Kit.box(n, Vector3(0.34, 0.012, 0.34), Vector3(0, 0.006, 0), card)
	for s in [-1.0, 1.0]:
		Kit.box(n, Vector3(0.34, 0.036, 0.008), Vector3(0, 0.024, 0.166 * s), card)
		Kit.box(n, Vector3(0.008, 0.036, 0.34), Vector3(0.166 * s, 0.024, 0), card)
	if full:
		# Lid propped open at the back, eight slices inside.
		var lid := Kit.node(n, Vector3(0, 0.042, -0.166))
		lid.rotation.x = -1.9
		Kit.box(lid, Vector3(0.34, 0.008, 0.34), Vector3(0, 0, 0.17), card)
		Kit.cyl(lid, 0.09, 0.002, Vector3(0, -0.006, 0.17), TOMATO, 14)
		for i in 8:
			out.pieces.append(_slice(n, Vector3(0, 0.012, 0), TAU * float(i) / 8.0 + 0.2))
		out.size = Vector3(0.35, 0.2, 0.35)
	else:
		Kit.box(n, Vector3(0.345, 0.01, 0.345), Vector3(0, 0.047, 0), card.darkened(0.06))
		Kit.cyl(n, 0.09, 0.003, Vector3(0, 0.053, 0), TOMATO, 14)
		for i in 3:
			Kit.cyl(n, 0.03, 0.002, Vector3(-0.09 + i * 0.07, 0.0535, 0.1), card.darkened(0.3), 8)   # grease
		out.size = Vector3(0.35, 0.055, 0.35)


static func _burger(n: Node3D, out: Dictionary) -> void:
	var b := Kit.node(n)
	Kit.cyl(b, 0.056, 0.02, Vector3(0, 0.01, 0), BUN, 12, 0.06)
	Kit.cyl(b, 0.062, 0.018, Vector3(0, 0.029, 0), PATTY, 12)
	var cheese := Kit.box(b, Vector3(0.11, 0.005, 0.11), Vector3(0, 0.041, 0), CHEESE)
	cheese.rotation.y = PI / 4.0
	Kit.cyl(b, 0.058, 0.006, Vector3(0, 0.047, 0), TOMATO, 12)
	var leaf := Kit.cyl(b, 0.068, 0.006, Vector3(0, 0.054, 0), LETTUCE, 9)
	leaf.rotation.y = 0.3
	var top := Kit.dome(b, 0.06, Vector3(0, 0.057, 0), BUN, 12)
	top.scale.y = 1.0
	for i in 8:
		var p := _ring(8, 0.03 * (0.4 + 0.6 * absf(_jit(i, 23.0))), i)
		Kit.ball(b, 0.004, Vector3(p.x, 0.057 + sqrt(maxf(0.0, 0.0036 - p.x * p.x - p.z * p.z)), p.z), CREAM, 4)
	out.body = b
	out.size = Vector3(0.13, 0.12, 0.13)


static func _hot_dog(n: Node3D, out: Dictionary) -> void:
	var b := Kit.node(n, Vector3(0, 0.022, 0))
	for s in [-1.0, 1.0]:
		var half := Kit.capsule(b, 0.02, 0.15, Vector3(0.016 * s, 0, 0), BUN, 8)
		half.rotation.x = PI / 2.0
	var sausage := Kit.capsule(b, 0.016, 0.17, Vector3(0, 0.016, 0), Color("b5452e"), 8)
	sausage.rotation.x = PI / 2.0
	for i in 6:
		Kit.ball(b, 0.006, Vector3(0.008 * (1.0 if i % 2 else -1.0), 0.032, -0.055 + i * 0.022), MUSTARD, 5)
	out.body = b
	out.size = Vector3(0.08, 0.07, 0.18)


static func _fries(n: Node3D, out: Dictionary) -> void:
	Kit.box(n, Vector3(0.07, 0.085, 0.036), Vector3(0, 0.0425, 0), CARTON)
	Kit.box(n, Vector3(0.074, 0.03, 0.01), Vector3(0, 0.092, -0.016), CARTON)
	var logo := Kit.cyl(n, 0.016, 0.003, Vector3(0, 0.045, 0.019), MUSTARD, 10)
	logo.rotation.x = PI / 2.0
	for i in 12:
		var fry := Kit.box(n, Vector3(0.009, 0.075 + absf(_jit(i, 24.0)) * 0.03, 0.009), Vector3(-0.026 + (i % 6) * 0.0105, 0.105 + absf(_jit(i, 25.0)) * 0.008, -0.006 + int(i / 6.0) * 0.012), FRY)
		fry.rotation = Vector3(_jit(i, 26.0) * 0.14, 0, _jit(i, 27.0) * 0.2)
		out.pieces.append(fry)
	out.size = Vector3(0.09, 0.17, 0.05)


static func _nuggets(n: Node3D, out: Dictionary) -> void:
	Kit.box(n, Vector3(0.14, 0.03, 0.1), Vector3(0, 0.015, 0), CARTON)
	Kit.box(n, Vector3(0.13, 0.004, 0.09), Vector3(0, 0.03, 0), PAPER)
	var lid := Kit.box(n, Vector3(0.14, 0.006, 0.1), Vector3(0, 0.06, -0.075), CARTON)
	lid.rotation.x = -1.2
	Kit.cyl(n, 0.02, 0.02, Vector3(0.045, 0.042, 0.024), PAPER, 10)
	Kit.cyl(n, 0.017, 0.004, Vector3(0.045, 0.052, 0.024), Color("b5451f"), 10)
	for i in 6:
		var nug := Kit.ball(n, 0.019, Vector3(-0.045 + (i % 3) * 0.03, 0.045, -0.026 + int(i / 3.0) * 0.034), GOLD.darkened(_jit(i, 28.0) * 0.06), 7)
		nug.scale = Vector3(1.15, 0.7, 0.9)
		nug.rotation.y = _jit(i, 29.0)
		out.pieces.append(nug)
	out.size = Vector3(0.15, 0.1, 0.14)


static func _taco(n: Node3D, out: Dictionary) -> void:
	var b := Kit.node(n, Vector3(0, 0.035, 0))
	for s in [-1.0, 1.0]:
		var shell := Kit.cyl(b, 0.06, 0.006, Vector3(0.014 * s, 0.012, 0), FRY.darkened(0.1), 12)
		shell.rotation.z = PI / 2.0 - 0.32 * s
	var fold := Kit.capsule(b, 0.014, 0.11, Vector3(0, -0.026, 0), FRY.darkened(0.1), 8)
	fold.rotation.x = PI / 2.0
	for i in 5:
		Kit.ball(b, 0.014, Vector3(_jit(i, 30.0) * 0.004, 0.012, -0.04 + i * 0.02), PATTY, 6)
		Kit.box(b, Vector3(0.022, 0.012, 0.016), Vector3(_jit(i, 31.0) * 0.006, 0.03, -0.042 + i * 0.021), LETTUCE if i % 2 else TOMATO)
	Kit.box(b, Vector3(0.014, 0.008, 0.1), Vector3(0, 0.04, 0), CHEESE)
	out.body = b
	out.size = Vector3(0.07, 0.1, 0.13)


static func _burrito(n: Node3D, out: Dictionary) -> void:
	var b := Kit.node(n, Vector3(0, 0.03, 0))
	var wrap := Kit.capsule(b, 0.03, 0.17, Vector3.ZERO, Color("f0ddb0"), 10)
	wrap.rotation.x = PI / 2.0
	var foil := Kit.cyl(b, 0.032, 0.085, Vector3(0, 0, 0.045), FOIL, 10)
	foil.rotation.x = PI / 2.0
	Kit.cyl(b, 0.024, 0.004, Vector3(0, 0, -0.083), PATTY, 10).rotation.x = PI / 2.0
	Kit.ball(b, 0.008, Vector3(0.008, 0.004, -0.086), LETTUCE, 5)
	Kit.ball(b, 0.007, Vector3(-0.009, -0.004, -0.086), TOMATO, 5)
	out.body = b
	out.size = Vector3(0.07, 0.065, 0.18)


static func _toastie(n: Node3D, out: Dictionary) -> void:
	var b := Kit.node(n, Vector3(0, 0, -0.05))
	Kit.wedge(b, Vector3(0.11, 0.012, 0.1), Vector3(0, 0.006, 0.05), Color("d9a25a"))
	Kit.wedge(b, Vector3(0.118, 0.006, 0.108), Vector3(0, 0.015, 0.05), CHEESE)
	Kit.wedge(b, Vector3(0.1, 0.005, 0.09), Vector3(0, 0.02, 0.05), Color("f29b9b"))
	Kit.wedge(b, Vector3(0.11, 0.012, 0.1), Vector3(0, 0.029, 0.05), Color("d9a25a"))
	for i in 3:
		Kit.box(b, Vector3(0.07 - i * 0.02, 0.002, 0.006), Vector3(0, 0.036, 0.02 + i * 0.022), Color("9c6a33"))
	out.body = b
	out.size = Vector3(0.12, 0.04, 0.11)


static func _drumstick(parent: Node3D, pos: Vector3, rot: Vector3) -> Node3D:
	var d := Kit.node(parent, pos)
	d.rotation = rot
	var meat := Kit.ball(d, 0.03, Vector3(0, 0.03, 0), GOLD, 8)
	meat.scale = Vector3(1.0, 1.25, 1.0)
	Kit.cyl(d, 0.007, 0.05, Vector3(0, 0.085, 0), CREAM, 6)
	Kit.ball(d, 0.011, Vector3(0, 0.112, 0), CREAM, 6)
	return d


static func _drumsticks(n: Node3D, out: Dictionary) -> void:
	Kit.cyl(n, 0.06, 0.12, Vector3(0, 0.06, 0), PAPER, 14, 0.08)
	for i in 5:
		var p := _ring(5, 0.07, i)
		var stripe := Kit.box(n, Vector3(0.03, 0.116, 0.006), Vector3(p.x, 0.06, p.z), CARTON)
		stripe.rotation.y = -atan2(p.z, p.x) + PI / 2.0
	for i in 4:
		var p := _ring(4, 0.032, i, 0.5)
		out.pieces.append(_drumstick(n, Vector3(p.x, 0.085, p.z), Vector3(_jit(i, 32.0) * 0.4, float(i), 0.3 + _jit(i, 33.0) * 0.2)))
	out.size = Vector3(0.17, 0.24, 0.17)


static func _corn_dog(n: Node3D, out: Dictionary) -> void:
	Kit.cyl(n, 0.004, 0.09, Vector3(0, 0.045, 0), WAFER, 6)
	var b := Kit.node(n, Vector3(0, 0.08, 0))
	Kit.capsule(b, 0.026, 0.13, Vector3(0, 0.055, 0), GOLD, 10)
	for i in 5:
		Kit.ball(b, 0.006, Vector3(0.012 * (1.0 if i % 2 else -1.0), 0.02 + i * 0.02, 0.023), MUSTARD, 5)
	out.body = b
	out.size = Vector3(0.06, 0.2, 0.06)


static func _noodles(n: Node3D, color: Color, out: Dictionary) -> void:
	Kit.cyl(n, 0.038, 0.095, Vector3(0, 0.0475, 0), PAPER, 14, 0.05)
	Kit.cyl(n, 0.0405, 0.036, Vector3(0, 0.05, 0), color, 14, 0.0445)
	var lid := Kit.cyl(n, 0.052, 0.003, Vector3(-0.022, 0.108, 0), FOIL, 12)
	lid.rotation.z = -0.8
	var b := Kit.node(n, Vector3(0, 0.094, 0))
	for i in 5:
		var strand := Kit.torus(b, 0.012 + i * 0.006, 0.004, Vector3(_jit(i, 34.0) * 0.004, i * 0.002, _jit(i, 35.0) * 0.004), Color("f6e3a1"), 10, 5)
		strand.rotation.x = _jit(i, 36.0) * 0.2
	out.body = b
	var fork := Kit.box(n, Vector3(0.008, 0.11, 0.003), Vector3(0.02, 0.13, 0.01), FOIL)
	fork.rotation.z = -0.25
	out.size = Vector3(0.11, 0.19, 0.11)


static func _pancakes(n: Node3D, out: Dictionary) -> void:
	Kit.cyl(n, 0.085, 0.008, Vector3(0, 0.004, 0), PAPER, 16)
	for i in 4:
		var cake := Kit.cyl(n, 0.06 - i * 0.002, 0.014, Vector3(_jit(i, 37.0) * 0.004, 0.015 + i * 0.015, _jit(i, 38.0) * 0.004), Color("e9b96e"), 14)
		out.pieces.append(cake)
	var top := Kit.node(n, Vector3(0, 0.069, 0))
	Kit.cyl(top, 0.045, 0.004, Vector3.ZERO, Color("8a4a17"), 10)
	Kit.box(top, Vector3(0.024, 0.01, 0.024), Vector3(0, 0.007, 0), MUSTARD.lightened(0.3))
	out.pieces.append(top)
	out.size = Vector3(0.17, 0.09, 0.17)


static func _waffle(n: Node3D, out: Dictionary) -> void:
	var b := Kit.node(n, Vector3(0, 0.01, 0))
	Kit.box(b, Vector3(0.1, 0.016, 0.1), Vector3.ZERO, Color("e3a94e"))
	for i in 4:
		Kit.box(b, Vector3(0.1, 0.008, 0.008), Vector3(0, 0.011, -0.036 + i * 0.024), Color("c98a35"))
		Kit.box(b, Vector3(0.008, 0.008, 0.1), Vector3(-0.036 + i * 0.024, 0.011, 0), Color("c98a35"))
	Kit.dome(b, 0.022, Vector3(0, 0.014, 0), CREAM, 8)
	Kit.ball(b, 0.008, Vector3(0, 0.036, 0), TOMATO, 6)
	out.body = b
	out.size = Vector3(0.105, 0.05, 0.105)


# --- drinks ------------------------------------------------------------------

static func _can(n: Node3D, color: Color, out: Dictionary, r: float, h: float) -> void:
	Kit.cyl(n, r, h, Vector3(0, h / 2.0, 0), color, 14)
	Kit.cyl(n, r * 0.9, 0.006, Vector3(0, h + 0.002, 0), FOIL, 14)
	Kit.cyl(n, r * 0.9, 0.006, Vector3(0, 0.003, 0), FOIL, 14)
	Kit.cyl(n, r * 1.01, h * 0.3, Vector3(0, h * 0.5, 0), color.lightened(0.45), 14)
	Kit.box(n, Vector3(r * 0.5, 0.003, r * 0.9), Vector3(0, h + 0.006, r * 0.2), FOIL.darkened(0.2))
	out.size = Vector3(r * 2.0, h + 0.01, r * 2.0)


static func _soda_cup(n: Node3D, color: Color, out: Dictionary) -> void:
	Kit.cyl(n, 0.034, 0.13, Vector3(0, 0.065, 0), color, 14, 0.046)
	Kit.cyl(n, 0.0365, 0.04, Vector3(0, 0.075, 0), PAPER, 14, 0.0405)
	Kit.cyl(n, 0.048, 0.008, Vector3(0, 0.134, 0), Color(1, 1, 1, 0.75), 14)
	var straw := Kit.cyl(n, 0.005, 0.11, Vector3(0.012, 0.18, 0), STRAW, 6)
	straw.rotation.z = -0.14
	out.size = Vector3(0.095, 0.24, 0.095)


static func _milkshake(n: Node3D, flavour: Color, out: Dictionary) -> void:
	Kit.cyl(n, 0.03, 0.01, Vector3(0, 0.005, 0), Color(1, 1, 1, 0.6), 12)
	Kit.cyl(n, 0.026, 0.14, Vector3(0, 0.08, 0), Color(1, 1, 1, 0.38), 14, 0.042)
	var b := Kit.node(n, Vector3(0, 0.012, 0))
	Kit.cyl(b, 0.023, 0.128, Vector3(0, 0.066, 0), flavour, 14, 0.039)
	out.body = b
	Kit.dome(n, 0.04, Vector3(0, 0.15, 0), CREAM, 10)
	Kit.cone(n, 0.022, 0.03, Vector3(0, 0.196, 0), CREAM, 8)
	Kit.ball(n, 0.011, Vector3(0.006, 0.214, 0), TOMATO, 8)
	var straw := Kit.cyl(n, 0.005, 0.13, Vector3(-0.016, 0.19, 0), STRAW, 6)
	straw.rotation.z = 0.2
	out.size = Vector3(0.09, 0.26, 0.09)


static func _carton(n: Node3D, color: Color, out: Dictionary) -> void:
	Kit.box(n, Vector3(0.06, 0.1, 0.06), Vector3(0, 0.05, 0), color)
	var roof := Kit.wedge(n, Vector3(0.06, 0.06, 0.03), Vector3(0, 0.115, 0), color.lightened(0.15))
	roof.rotation.x = 0.0
	Kit.box(n, Vector3(0.062, 0.03, 0.004), Vector3(0, 0.06, 0.03), PAPER)
	var straw := Kit.cyl(n, 0.004, 0.07, Vector3(0.018, 0.14, 0.01), STRAW, 6)
	straw.rotation.z = -0.3
	out.size = Vector3(0.065, 0.17, 0.065)


# --- what is left afterwards ---------------------------------------------------

static func _crumple(n: Node3D, color: Color, out: Dictionary, r: float) -> void:
	var ball := Kit.ball(n, r, Vector3(0, r, 0), color, 5)
	ball.scale = Vector3(1.0, 0.82, 1.1)
	ball.rotation = Vector3(0.4, 0.9, 0.2)
	Kit.ball(n, r * 0.62, Vector3(r * 0.45, r * 1.2, r * 0.2), color.lightened(0.18), 4)
	out.size = Vector3(r * 2.2, r * 2.0, r * 2.2)


static func _crushed_can(n: Node3D, color: Color, out: Dictionary) -> void:
	var c := Kit.cyl(n, 0.034, 0.045, Vector3(0, 0.024, 0), color, 8, 0.03)
	c.rotation.z = 0.15
	Kit.cyl(n, 0.03, 0.006, Vector3(0.004, 0.05, 0), FOIL, 8).rotation.z = 0.3
	out.size = Vector3(0.07, 0.06, 0.07)


static func _empty_cup(n: Node3D, color: Color, out: Dictionary) -> void:
	var c := Kit.node(n, Vector3(0, 0.04, 0))
	c.rotation.z = PI / 2.0 - 0.1
	Kit.cyl(c, 0.034, 0.12, Vector3.ZERO, color, 12, 0.046)
	Kit.cyl(c, 0.005, 0.08, Vector3(0.01, 0.09, 0), STRAW, 6)
	out.size = Vector3(0.14, 0.09, 0.09)


static func _greasy_box(n: Node3D, out: Dictionary) -> void:
	var b := Kit.box(n, Vector3(0.13, 0.03, 0.1), Vector3(0, 0.015, 0), CARTON.darkened(0.08))
	b.rotation.y = 0.2
	var flap := Kit.box(n, Vector3(0.13, 0.005, 0.09), Vector3(0.01, 0.034, -0.02), CARTON)
	flap.rotation = Vector3(-0.35, 0.2, 0.08)
	Kit.cyl(n, 0.02, 0.002, Vector3(0.02, 0.031, 0.02), CARTON.darkened(0.35), 8)
	out.size = Vector3(0.14, 0.05, 0.11)


static func _empty_bag(n: Node3D, color: Color, out: Dictionary) -> void:
	var bag := Kit.box(n, Vector3(0.14, 0.012, 0.19), Vector3(0, 0.008, 0), color)
	bag.rotation.y = 0.3
	var fold := Kit.box(n, Vector3(0.13, 0.012, 0.07), Vector3(0.012, 0.02, 0.05), color.darkened(0.15))
	fold.rotation = Vector3(0.25, 0.3, 0.1)
	out.size = Vector3(0.16, 0.035, 0.2)


static func _stick(n: Node3D, out: Dictionary) -> void:
	var s := Kit.box(n, Vector3(0.012, 0.005, 0.11), Vector3(0, 0.003, 0), WAFER)
	s.rotation.y = 0.4
	out.size = Vector3(0.05, 0.01, 0.11)


# --- things on the desk ---------------------------------------------------------

static func _stress_ball(n: Node3D, color: Color, out: Dictionary) -> void:
	var b := Kit.node(n, Vector3(0, 0.034, 0))
	Kit.ball(b, 0.034, Vector3.ZERO, color, 12)
	for s in [-1.0, 1.0]:
		Kit.ball(b, 0.006, Vector3(0.012 * s, 0.01, 0.03), Color("2f2c3e"), 6)
	var smile := Kit.torus(b, 0.012, 0.003, Vector3(0, -0.006, 0.028), Color("2f2c3e"), 10, 4)
	smile.rotation.x = PI / 2.0 - 0.3
	smile.scale.y = 0.6
	out.body = b
	out.size = Vector3(0.07, 0.07, 0.07)


static func _rubber_duck(n: Node3D, out: Dictionary) -> void:
	var b := Kit.node(n, Vector3(0, 0.03, 0))
	var body := Kit.ball(b, 0.036, Vector3.ZERO, MUSTARD, 10)
	body.scale = Vector3(1.0, 0.82, 1.25)
	Kit.ball(b, 0.024, Vector3(0, 0.038, 0.022), MUSTARD, 10)
	var tail := Kit.cone(b, 0.014, 0.03, Vector3(0, 0.014, -0.044), MUSTARD, 6)
	tail.rotation.x = -0.9
	var beak := Kit.box(b, Vector3(0.02, 0.008, 0.018), Vector3(0, 0.034, 0.048), Color("ff8c5a"))
	beak.rotation.x = 0.1
	for s in [-1.0, 1.0]:
		Kit.ball(b, 0.0045, Vector3(0.011 * s, 0.046, 0.04), Color("2f2c3e"), 5)
	out.body = b
	out.size = Vector3(0.08, 0.1, 0.11)
