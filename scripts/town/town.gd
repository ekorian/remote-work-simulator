class_name Town
extends RefCounted
## Town — the street outside the front door: three shops, a coffee cart, a
## vending machine, a park. It is built into the Apartment node, so the flat
## and the street share one set of objects, item spots and navigation.

const PAVE_Z := 8.2              ## where the near pavement starts
const ROAD_Z0 := 10.0
const ROAD_Z1 := 15.0
const SHOP_Z := 17.0             ## shop fronts
const BACK_Z := 24.8
const SHOP_H := 3.0
const GRASS := Color("8fd18a")
const PAVE := Color("d9d4cc")
const TAR := Color("5b5a66")

## Shop id -> [x0, x1, wall colour, awning colour]
const SHOPS := {
	"mart": [-15.5, -7.5, Color("f2e3c4"), Color("e63946")],
	"diner": [-6.5, 1.5, Color("ffe0a8"), Color("ffb000")],
	"odds": [2.5, 10.5, Color("d9c7f2"), Color("7a3df0")],
}

## Who is about. `npc`: a SynerCorp person (they recognise you). `hours`:
## [[from, to]] in minutes of the day. `path`: walked back and forth.
const PEOPLE := [
	{"id": "clerk_mart", "name": "Shopkeeper", "at": Vector3(-9.1, 0, 23.6), "yaw": 180.0, "lines": "clerk_mart", "shop": "mart"},
	{"id": "clerk_diner", "name": "Patty", "at": Vector3(-0.1, 0, 23.6), "yaw": 180.0, "lines": "clerk_diner", "shop": "diner"},
	{"id": "clerk_odds", "name": "Shopkeeper", "at": Vector3(8.9, 0, 23.6), "yaw": 180.0, "lines": "clerk_odds", "shop": "odds"},
	{"id": "barista", "name": "Barista", "at": Vector3(15.0, 0, 8.55), "yaw": 0.0, "lines": "clerk_cart", "shop": "cart"},
	{"id": "walker_1", "name": "Neighbour", "path": [Vector3(-15, 0, 9.1), Vector3(21, 0, 9.1)], "lines": "town_lines"},
	{"id": "walker_2", "name": "Dog Walker", "path": [Vector3(21, 0, 16.0), Vector3(-15, 0, 16.0)], "lines": "town_lines"},
	{"id": "walker_3", "name": "Pensioner", "path": [Vector3(-4.5, 0, 9.0), Vector3(-4.5, 0, 16.0), Vector3(-11.5, 0, 16.2), Vector3(-11.5, 0, 19.5)], "lines": "town_lines", "speed": 0.8},
	{"id": "walker_4", "name": "Jogger", "path": [Vector3(20, 0, 9.4), Vector3(-14, 0, 9.4), Vector3(-14, 0, 15.6), Vector3(20, 0, 15.6)], "lines": "town_lines", "speed": 2.4, "loop": true},
	{"id": "walker_5", "name": "Student", "path": [Vector3(6.5, 0, 16.2), Vector3(6.5, 0, 19.5)], "lines": "town_lines", "speed": 0.9},
	{"id": "dave", "npc": "dave", "at": Vector3(18.6, 0.02, 21.35), "yaw": 180.0, "sit": true, "hours": [[600, 960]]},
	{"id": "kevin", "npc": "kevin", "path": [Vector3(-13, 0, 8.8), Vector3(19, 0, 8.8)], "speed": 1.9, "hours": [[640, 675], [900, 935]]},
	{"id": "brenda", "npc": "brenda", "at": Vector3(13.6, 0, 9.3), "yaw": 90.0, "hours": [[550, 590], [840, 870]]},
	{"id": "martin", "npc": "martin", "at": Vector3(16.3, 0, 9.3), "yaw": -90.0, "hours": [[630, 648]]},
	{"id": "priya", "npc": "priya", "at": Vector3(-12.6, 0, 20.4), "yaw": -90.0, "hours": [[1085, 1130]]},
]


static func build(apt: Apartment) -> void:
	_ground(apt)
	_house_front(apt)
	_edges(apt)
	for id in SHOPS:
		_shop(apt, str(id))
	_street(apt)
	_park(apt)


static func _wall(apt: Apartment, x0: float, x1: float, z0: float, z1: float, h: float, color: Color, y0: float = 0.0, see_through: bool = false) -> void:
	## A solid block that also blocks the navigation grid (when it reaches the ground).
	var size := Vector3(x1 - x0, h, z1 - z0)
	var mid := Vector3((x0 + x1) / 2.0, y0 + h / 2.0, (z0 + z1) / 2.0)
	var m := Kit.box(apt, size, mid, Color(color, 0.28) if see_through else color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.solid(apt, size, mid)
	if y0 < 1.0:
		apt._block(Rect2(x0, z0, x1 - x0, z1 - z0))


static func _ground(apt: Apartment) -> void:
	Kit.box(apt, Vector3(70, 0.1, 50), Vector3(3, -0.07, 14), GRASS, 1.0)
	Kit.box(apt, Vector3(46, 0.06, ROAD_Z0 - PAVE_Z), Vector3(3, 0.0, (PAVE_Z + ROAD_Z0) / 2.0), PAVE, 0.9)
	Kit.box(apt, Vector3(46, 0.06, SHOP_Z - ROAD_Z1), Vector3(3, 0.0, (ROAD_Z1 + SHOP_Z) / 2.0), PAVE, 0.9)
	Kit.box(apt, Vector3(46, 0.04, ROAD_Z1 - ROAD_Z0), Vector3(3, -0.012, (ROAD_Z0 + ROAD_Z1) / 2.0), TAR, 0.95)
	for i in 15:
		Kit.box(apt, Vector3(1.4, 0.005, 0.14), Vector3(-18.0 + i * 3.0, 0.012, 12.5), Color("f4f0e6"))
	# Zebra crossings in front of the house and by the park.
	for cx in [Apartment.DOOR_X, 13.0]:
		for i in 6:
			Kit.box(apt, Vector3(1.8, 0.006, 0.42), Vector3(cx, 0.013, ROAD_Z0 + 0.45 + i * 0.82), Color("f4f0e6"))
	# The path from the front door to the pavement.
	Kit.box(apt, Vector3(1.3, 0.05, PAVE_Z - Apartment.Z1 - 0.2), Vector3(Apartment.DOOR_X, 0.0, (PAVE_Z + Apartment.Z1 + 0.2) / 2.0), Color("c9b79c"), 0.9)


static func _house_front(apt: Apartment) -> void:
	# A roof, a step, a porch light, a number, and somebody's idea of a garden.
	var roof := Kit.box(apt, Vector3(15.2, 0.22, 12.2), Vector3(0, Apartment.WALL_H + 0.3, 0), Color("b5543c"))
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.box(apt, Vector3(0.7, 0.9, 0.7), Vector3(4.6, Apartment.WALL_H + 0.8, -2.0), Color("9c4631"))
	Kit.box(apt, Vector3(1.5, 0.08, 0.5), Vector3(Apartment.DOOR_X, 0.03, Apartment.Z1 + 0.5), Color("b8ad9c"))
	Kit.box(apt, Vector3(1.9, 0.08, 0.9), Vector3(Apartment.DOOR_X, 2.3, Apartment.Z1 + 0.6), Color("b5543c"))
	apt.lamps.append(Kit.lamp(apt, Vector3(Apartment.DOOR_X, 2.1, Apartment.Z1 + 0.7), Color("ffd9a0"), 1.6, 5.0))
	Kit.box(apt, Vector3(0.28, 0.2, 0.02), Vector3(Apartment.DOOR_X + 0.95, 1.6, Apartment.Z1 + 0.21), Color("2f2c3e"))
	var num := Label3D.new()
	num.text = "14"
	num.font_size = 64
	num.pixel_size = 0.0022
	num.position = Vector3(Apartment.DOOR_X + 0.95, 1.6, Apartment.Z1 + 0.225)
	apt.add_child(num)
	for i in 5:
		var fx := -2.8 + i * 1.9
		Kit.ball(apt, 0.3, Vector3(fx, 0.25, 6.3), Color("5aa55f"), 7).scale = Vector3(1.3, 0.9, 1.0)
		Kit.ball(apt, 0.07, Vector3(fx + 0.15, 0.5, 6.45), [Color("ff7eb6"), Color("ffd166"), Color("ff5d73")][i % 3], 5)
		apt._block(Rect2(fx - 0.4, 6.0, 0.8, 0.6))
	Kit.solid(apt, Vector3(8.6, 0.6, 0.5), Vector3(1.0, 0.3, 6.3))
	apt.spots["garden"] = Vector3(-3.2, 0.03, 7.2)
	# Windows on the front of your own house, and a few clouds over the street.
	for wx in [-1.4, 2.4, 5.4]:
		Kit.box(apt, Vector3(1.5, 1.2, 0.05), Vector3(wx, 1.75, Apartment.Z1 + Apartment.WALL_T + 0.02), Color("cdeaff"), 0.3, 0.3)
		Kit.box(apt, Vector3(1.66, 0.08, 0.12), Vector3(wx, 1.1, Apartment.Z1 + Apartment.WALL_T + 0.05), Apartment.C_TRIM)
		Kit.box(apt, Vector3(0.06, 1.2, 0.07), Vector3(wx, 1.75, Apartment.Z1 + Apartment.WALL_T + 0.03), Apartment.C_TRIM)
	for i in 7:
		var cloud := Kit.ball(apt, 3.0, Vector3(-30.0 + i * 11.0, 26.0 + (i % 3) * 3.0, 34.0 - (i % 2) * 22.0), Color("ffffff"), 8)
		cloud.scale = Vector3(1.8, 0.45, 1.0)
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A letterbox on a post.
	Kit.box(apt, Vector3(0.08, 1.0, 0.08), Vector3(-6.2, 0.5, 7.9), Color("8a5a36"))
	Kit.box(apt, Vector3(0.3, 0.22, 0.42), Vector3(-6.2, 1.1, 7.9), Color("e63946"))
	apt._block(Rect2(-6.4, 7.7, 0.4, 0.4))


static func _edges(apt: Apartment) -> void:
	## Everything that stops you walking off the map: the neighbours' houses
	## either side of yours, and the ends of the street.
	var x0 := Apartment.TX0
	var x1 := Apartment.TX1
	for side in [[x0 - 0.5, Apartment.X0 - 0.4, Color("e8d4bd"), Color("7a8fb5")], [Apartment.X1 + 0.4, x1 + 0.5, Color("d9e3c8"), Color("6b8f6a")]]:
		_wall(apt, float(side[0]), float(side[1]), 2.0, Apartment.TZ0, 3.2, side[2])
		Kit.box(apt, Vector3(float(side[1]) - float(side[0]) + 0.4, 0.22, 4.2), Vector3((float(side[0]) + float(side[1])) / 2.0, 3.3, 3.8), side[3])
		for i in 3:
			var wx := float(side[0]) + 1.6 + i * ((float(side[1]) - float(side[0]) - 3.2) / 2.0)
			Kit.box(apt, Vector3(1.2, 1.1, 0.06), Vector3(wx, 1.75, Apartment.TZ0 + 0.03), Color("cdeaff"), 0.3, 0.25)
			Kit.box(apt, Vector3(1.36, 0.08, 0.1), Vector3(wx, 1.16, Apartment.TZ0 + 0.05), Apartment.C_TRIM)
	# Street ends: a hoarding at one, a bus that never leaves at the other.
	_wall(apt, x0 - 0.6, x0, Apartment.TZ0, BACK_Z + 0.2, 2.4, Color("f2c230"))
	_wall(apt, x1, x1 + 0.6, Apartment.TZ0, SHOP_Z, 2.4, Color("7a8fb5"))
	for i in 9:
		Kit.box(apt, Vector3(0.05, 2.4, 0.9), Vector3(x0 + 0.03, 1.2, 6.6 + i * 2.1), Color("2f2c3e"))
	_wall(apt, x0, x1, BACK_Z, BACK_Z + 0.4, SHOP_H, Color("cbbfae"))
	_wall(apt, x1, x1 + 0.4, SHOP_Z, BACK_Z + 0.2, 1.3, Color("5aa55f"))
	# Roadworks, with one cone nobody would miss.
	Kit.box(apt, Vector3(1.6, 0.9, 0.08), Vector3(-12.4, 0.5, 9.75), Color("f2c230"))
	Kit.box(apt, Vector3(1.6, 0.2, 0.09), Vector3(-12.4, 0.62, 9.75), Color("2f2c3e"))
	Kit.solid(apt, Vector3(1.6, 0.9, 0.1), Vector3(-12.4, 0.45, 9.75))
	apt._block(Rect2(-13.2, 9.65, 1.6, 0.2))
	apt.spots["roadworks"] = Vector3(-11.2, 0.03, 9.45)


static func _shop(apt: Apartment, id: String) -> void:
	var d: Array = SHOPS[id]
	var x0 := float(d[0])
	var x1 := float(d[1])
	var wall: Color = d[2]
	var awning: Color = d[3]
	var cx := (x0 + x1) / 2.0
	var t := 0.2
	# Floor, back and sides.
	# A chequered floor in the shop's own colours.
	for ix in 8:
		for iz in 8:
			Kit.box(apt, Vector3((x1 - x0) / 8.0, 0.05, (BACK_Z - SHOP_Z) / 8.0), Vector3(x0 + (ix + 0.5) * (x1 - x0) / 8.0, 0.0, SHOP_Z + (iz + 0.5) * (BACK_Z - SHOP_Z) / 8.0), awning.lerp(Color("f4f0e6"), 0.55) if (ix + iz) % 2 == 0 else Color("efe9dc"), 0.8)
	_wall(apt, x0 - 0.5, x0 + t, SHOP_Z, BACK_Z, SHOP_H, wall)
	_wall(apt, x1 - t, x1 + 0.5, SHOP_Z, BACK_Z, SHOP_H, wall)
	# Front: a doorway in the middle, a shop window either side.
	for part in [[x0 + t, cx - 0.85], [cx + 0.85, x1 - t]]:
		_wall(apt, float(part[0]), float(part[1]), SHOP_Z, SHOP_Z + t, 0.7, wall.darkened(0.12))
		_wall(apt, float(part[0]), float(part[1]), SHOP_Z + 0.06, SHOP_Z + 0.12, 1.55, Color("bfe6ff"), 0.7, true)
	_wall(apt, x0 + t, x1 - t, SHOP_Z, SHOP_Z + t, SHOP_H - 2.25, wall.darkened(0.12), 2.25)
	var top := Kit.box(apt, Vector3(x1 - x0 + 1.0, 0.2, BACK_Z - SHOP_Z + 0.4), Vector3(cx, SHOP_H + 0.1, (SHOP_Z + BACK_Z) / 2.0), wall.darkened(0.2))
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.solid(apt, Vector3(x1 - x0 + 1.0, 0.2, BACK_Z - SHOP_Z + 0.4), Vector3(cx, SHOP_H + 0.1, (SHOP_Z + BACK_Z) / 2.0))
	var shade := Kit.box(apt, Vector3(x1 - x0 - 0.2, 0.1, 1.1), Vector3(cx, 2.42, SHOP_Z - 0.5), awning)
	shade.rotation.x = -0.22
	var sign := Label3D.new()
	sign.text = str(Home.SHOPS[id].name).to_upper()
	sign.font = UI.font_title if UI.font_title != null else null
	sign.font_size = 96
	sign.pixel_size = 0.0045
	sign.outline_size = 14
	sign.outline_modulate = Color("2f2c3e")
	sign.modulate = Color("fff6e0")
	sign.position = Vector3(cx, 2.72, SHOP_Z - 0.03)
	sign.rotation.y = PI
	apt.add_child(sign)
	apt.ceiling_lights.append(Kit.lamp(apt, Vector3(cx, 2.6, 21.0), Color("fff1cf"), 1.1, 8.5))
	Kit.box(apt, Vector3(1.6, 0.06, 0.3), Vector3(cx, SHOP_H - 0.05, 21.0), Color("fffaf0"), 0.5, 1.2)
	# A stand in the middle of the floor, piled with things that are not for sale today.
	var stand := apt._prop(Vector3(cx + 0.2, 0, 20.4), 0.0, Vector2(1.8, 0.9), 1.0, "Stand_" + id)
	Kit.box(stand, Vector3(1.8, 0.7, 0.9), Vector3(0, 0.35, 0), wall.darkened(0.3))
	Kit.box(stand, Vector3(1.9, 0.05, 1.0), Vector3(0, 0.72, 0), Apartment.C_WOOD_LIGHT)
	for i in 7:
		var lump := Kit.box(stand, Vector3(0.24, 0.16 + 0.07 * (i % 3), 0.2), Vector3(-0.72 + i * 0.24, 0.83 + 0.035 * (i % 3), 0.12 * ((i % 2) * 2 - 1)), [awning, Color("f4f0e6"), wall.darkened(0.15), Color("ffd166")][i % 4])
		lump.rotation.y = 0.25 * (i - 3)
	# A board behind the till.
	Kit.box(apt, Vector3(2.2, 0.9, 0.05), Vector3(x1 - 1.6, 2.1, BACK_Z - 0.04), Apartment.C_DARK)
	for i in 4:
		Kit.box(apt, Vector3(1.6 - 0.25 * (i % 2), 0.07, 0.06), Vector3(x1 - 1.7, 2.38 - i * 0.18, BACK_Z - 0.045), [Color("ffd166"), Color("f4f0e6")][i % 2])
	# The counter and the till: this is the shop, as far as the rules go.
	var counter := apt._prop(Vector3(x1 - 1.6, 0, 22.6), 0.0, Vector2(2.4, 0.7), 0.95, "Counter_" + id)
	Kit.box(counter, Vector3(2.4, 0.9, 0.7), Vector3(0, 0.45, 0), awning.darkened(0.15))
	Kit.box(counter, Vector3(2.5, 0.06, 0.8), Vector3(0, 0.93, 0), Apartment.C_WHITE, 0.3)
	var till := apt._thing(id, counter, Vector3(0.5, 0.96, 0), Vector3(0.6, 0.5, 0.6), Vector3(0, 0.2, 0), Vector3(-0.5, -0.96, -1.1))
	Kit.box(till, Vector3(0.36, 0.16, 0.34), Vector3(0, 0.08, 0), Apartment.C_DARK)
	Kit.box(till, Vector3(0.3, 0.2, 0.04), Vector3(0, 0.26, 0.1), Apartment.C_DARK).rotation.x = -0.4
	Kit.box(till, Vector3(0.24, 0.14, 0.01), Vector3(0, 0.27, 0.075), Color("5ad17a"), 0.4, 1.6).rotation.x = -0.4
	# Shelves along the left wall: what is on them is today's stock.
	var slots: Array = []
	var unit := apt._prop(Vector3(x0 + t + 0.28, 0, 20.9), 90.0, Vector2(4.6, 0.5), 1.9, "Shelves_" + id)
	Kit.box(unit, Vector3(4.6, 1.9, 0.06), Vector3(0, 0.95, -0.22), Apartment.C_WOOD_DARK)
	for row in 3:
		Kit.box(unit, Vector3(4.6, 0.05, 0.46), Vector3(0, 0.38 + row * 0.5, 0), Apartment.C_WOOD_LIGHT)
	for sx in [-1.0, 1.0]:
		Kit.box(unit, Vector3(0.06, 1.9, 0.46), Vector3(2.27 * sx, 0.95, 0), Apartment.C_WOOD)
	for i in 10:
		slots.append({"pos": Vector3(x0 + t + 0.3, 0.41 + (0.5 if i < 5 else 1.0), 19.1 + (i % 5) * 0.9), "yaw": 90.0, "stand": Vector3(x0 + t + 1.35, 0, 19.1 + (i % 5) * 0.9)})
	apt.parts["slots_" + id] = slots
	# Things at the back that are only for show.
	for i in 5:
		var crate := Kit.box(apt, Vector3(0.7, 0.5, 0.5), Vector3(x0 + 2.3 + i * 0.85, 0.25 + (0.5 if i % 2 else 0.0), BACK_Z - 0.4), [awning, wall.darkened(0.25), Color("f4f0e6")][i % 3])
		crate.rotation.y = 0.1 * (i - 2)
	apt._block(Rect2(x0 + 1.9, BACK_Z - 0.75, 4.2, 0.7))
	Kit.solid(apt, Vector3(4.2, 1.0, 0.6), Vector3(x0 + 4.0, 0.5, BACK_Z - 0.4))


static func _street(apt: Apartment) -> void:
	# Lamp posts, lit at night.
	for i in 5:
		for z in [PAVE_Z + 0.25, SHOP_Z - 0.3]:
			var lx := -13.0 + i * 8.0 + (4.0 if z > 12.0 else 0.0)
			Kit.cyl(apt, 0.06, 3.6, Vector3(lx, 1.8, z), Apartment.C_DARK, 8)
			Kit.ball(apt, 0.16, Vector3(lx, 3.65, z), Color("fff1cf"), 8, 1.2)
			apt.lamps.append(Kit.lamp(apt, Vector3(lx, 3.4, z), Color("ffd9a0"), 2.0, 9.0))
			apt._block(Rect2(lx - 0.1, z - 0.1, 0.2, 0.2))
	# Parked cars: boxes with opinions about colour.
	for car in [[-9.0, 10.7, Color("4fb3ff")], [3.5, 10.7, Color("ff8c5a")], [8.5, 14.3, Color("5ad17a")], [-1.5, 14.3, Color("e9edf5")]]:
		var c := Kit.node(apt, Vector3(float(car[0]), 0, float(car[1])))
		Kit.box(c, Vector3(3.6, 0.6, 1.5), Vector3(0, 0.5, 0), car[2])
		Kit.box(c, Vector3(2.0, 0.55, 1.36), Vector3(-0.1, 1.05, 0), (car[2] as Color).lightened(0.15))
		Kit.box(c, Vector3(1.9, 0.4, 1.38), Vector3(-0.1, 1.05, 0), Color("bfe6ff"), 0.3)
		for wx in [-1.15, 1.15]:
			for wz in [-0.72, 0.72]:
				Kit.cyl(c, 0.3, 0.2, Vector3(wx, 0.3, wz), Apartment.C_DARK, 10).rotation.x = PI / 2.0
		Kit.solid(apt, Vector3(3.6, 1.3, 1.5), Vector3(float(car[0]), 0.65, float(car[1])))
		apt._block(Rect2(float(car[0]) - 1.8, float(car[1]) - 0.75, 3.6, 1.5))
	# Vending machine, against the neighbour's wall.
	var vend_root := apt._prop(Vector3(9.2, 0, 6.2), 0.0, Vector2(1.0, 0.8), 1.9, "Vending")
	var vend := apt._thing("vending", vend_root, Vector3.ZERO, Vector3(1.0, 1.9, 0.8), Vector3(0, 0.95, 0), Vector3(0, 0, 1.15))
	Kit.box(vend, Vector3(1.0, 1.9, 0.75), Vector3(0, 0.95, 0), Color("e63946"))
	Kit.box(vend, Vector3(0.62, 1.2, 0.02), Vector3(-0.12, 1.2, 0.38), Color("bfe6ff"), 0.3, 0.7)
	for i in 8:
		Kit.cyl(vend, 0.04, 0.12, Vector3(-0.34 + (i % 4) * 0.15, 1.5 - int(i / 4.0) * 0.4, 0.33), [Color("e63946"), Color("3ddc84"), Color("ffb000"), Color("4fb3ff")][i % 4], 8)
	Kit.box(vend, Vector3(0.6, 0.2, 0.03), Vector3(-0.12, 0.35, 0.38), Apartment.C_DARK)
	Kit.box(vend, Vector3(0.16, 0.5, 0.02), Vector3(0.34, 1.2, 0.38), Apartment.C_DARK)
	apt.lamps.append(Kit.lamp(vend, Vector3(0, 1.3, 0.9), Color("ffb3b3"), 0.9, 3.0))
	# Newspaper box.
	var nb_root := apt._prop(Vector3(11.0, 0, 8.55), 0.0, Vector2(0.5, 0.45), 1.0, "NewsBox")
	var nb := apt._thing("news_box", nb_root, Vector3.ZERO, Vector3(0.55, 1.1, 0.5), Vector3(0, 0.55, 0), Vector3(0, 0, 0.9))
	Kit.box(nb, Vector3(0.5, 0.75, 0.42), Vector3(0, 0.62, 0), Color("4fb3ff"))
	Kit.box(nb, Vector3(0.1, 0.3, 0.1), Vector3(0, 0.15, 0), Apartment.C_DARK)
	Kit.box(nb, Vector3(0.4, 0.3, 0.02), Vector3(0, 0.7, 0.215), Color("ece6d6"))
	# Coffee cart.
	var cart_root := apt._prop(Vector3(15.0, 0, 9.3), 0.0, Vector2(2.0, 0.8), 1.0, "CoffeeCart")
	Kit.box(cart_root, Vector3(2.0, 0.9, 0.8), Vector3(0, 0.5, 0), Color("6b4a2f"))
	Kit.box(cart_root, Vector3(2.1, 0.06, 0.9), Vector3(0, 0.98, 0), Apartment.C_WOOD_LIGHT)
	for sx in [-1.0, 1.0]:
		Kit.cyl(cart_root, 0.03, 1.3, Vector3(0.95 * sx, 1.65, -0.35), Apartment.C_DARK, 6)
		Kit.cyl(cart_root, 0.32, 0.1, Vector3(0.7 * sx, 0.3, 0.46), Apartment.C_DARK, 12).rotation.x = PI / 2.0
	var canopy := Kit.box(cart_root, Vector3(2.4, 0.08, 1.5), Vector3(0, 2.3, -0.1), Color("ff8c5a"))
	canopy.rotation.x = 0.12
	var cart := apt._thing("cart", cart_root, Vector3(-0.6, 1.01, -0.1), Vector3(0.6, 0.6, 0.6), Vector3(0, 0.25, 0), Vector3(0.3, -1.01, 1.25))
	Kit.box(cart, Vector3(0.4, 0.42, 0.34), Vector3(0, 0.21, 0), Apartment.C_METAL, 0.3)
	Kit.cyl(cart, 0.05, 0.1, Vector3(0, 0.47, 0), Apartment.C_DARK, 8)
	var cart_slots: Array = []
	for i in 3:
		cart_slots.append({"pos": Vector3(15.15 + i * 0.32, 1.02, 9.5), "yaw": 0.0, "stand": Vector3(15.3 + i * 0.3, 0, 10.55)})
	apt.parts["slots_cart"] = cart_slots
	# Bus stop and a bin.
	Kit.box(apt, Vector3(2.6, 0.08, 1.0), Vector3(19.4, 2.3, 8.7), Color("4fb3ff"))
	for sx in [-1.2, 1.2]:
		Kit.cyl(apt, 0.04, 2.3, Vector3(19.4 + sx, 1.15, 8.3), Apartment.C_DARK, 6)
	Kit.box(apt, Vector3(2.4, 1.4, 0.04), Vector3(19.4, 1.2, 8.28), Color("bfe6ff"), 0.3)
	Kit.box(apt, Vector3(2.0, 0.08, 0.4), Vector3(19.4, 0.45, 8.5), Apartment.C_WOOD)
	apt._block(Rect2(18.2, 8.2, 2.4, 0.5))
	Kit.cyl(apt, 0.22, 0.8, Vector3(-6.9, 0.4, 16.6), Color("3b7a57"), 10)
	Kit.solid(apt, Vector3(0.44, 0.2, 0.44), Vector3(-6.9, 0.1, 16.6))
	apt._bin_trigger(Vector3(-6.9, 0.72, 16.6), 0.24)
	apt._block(Rect2(-7.15, 16.35, 0.5, 0.5))


static func _tree(apt: Apartment, pos: Vector3, s: float = 1.0) -> void:
	Kit.cyl(apt, 0.16 * s, 1.6 * s, pos + Vector3(0, 0.8 * s, 0), Color("8a5a36"), 7)
	Kit.ball(apt, 1.0 * s, pos + Vector3(0, 2.3 * s, 0), Color("5aa55f"), 7)
	Kit.ball(apt, 0.7 * s, pos + Vector3(0.5 * s, 3.0 * s, 0.2 * s), Color("6fc070"), 6)
	Kit.solid(apt, Vector3(0.4 * s, 2.0, 0.4 * s), pos + Vector3(0, 1.0, 0))
	apt._block(Rect2(pos.x - 0.25, pos.z - 0.25, 0.5, 0.5))


static func _bench(apt: Apartment, pos: Vector3, thing: bool) -> void:
	var root := apt._prop(pos, 180.0, Vector2(1.7, 0.6), 0.5, "Bench")
	var parent: Node3D = root
	if thing:
		var b := apt._thing("bench", root, Vector3.ZERO, Vector3(1.7, 0.95, 0.65), Vector3(0, 0.47, 0), Vector3(0, 0, 0.95))
		b.seat = {"pos": Vector3(0.3, 0.0, 0.12), "yaw": PI, "lie": false}
		parent = b
		apt.spots["bench"] = root.to_global(Vector3(-0.5, 0.5, 0.05))
	Kit.box(parent, Vector3(1.7, 0.07, 0.5), Vector3(0, 0.46, 0), Apartment.C_WOOD)
	Kit.box(parent, Vector3(1.7, 0.4, 0.07), Vector3(0, 0.75, -0.24), Apartment.C_WOOD)
	for sx in [-0.75, 0.75]:
		Kit.box(parent, Vector3(0.08, 0.46, 0.5), Vector3(sx, 0.23, 0), Apartment.C_DARK)


static func _park(apt: Apartment) -> void:
	var x0 := 11.4
	var x1 := Apartment.TX1
	# A low fence along the pavement, with a gap to walk through.
	_wall(apt, 10.5, 11.4, SHOP_Z, BACK_Z, SHOP_H, Color("d9c7f2").darkened(0.1))
	for part in [[x0, 13.4], [15.4, x1]]:
		_wall(apt, float(part[0]), float(part[1]), SHOP_Z, SHOP_Z + 0.1, 0.7, Color("f4f0e6"))
	for pos in [Vector3(12.4, 0, 18.6), Vector3(21.0, 0, 18.4), Vector3(12.3, 0, 23.6), Vector3(16.6, 0, 23.9)]:
		_tree(apt, pos, 1.0 if pos.x < 20.0 else 1.2)
	Kit.box(apt, Vector3(2.0, 0.03, 6.6), Vector3(14.4, 0.0, 20.4), Color("c9b79c"), 0.9)             # a path in
	_bench(apt, Vector3(14.4, 0, 21.9), true)
	_bench(apt, Vector3(18.6, 0, 21.9), false)
	# A basketball hoop, and somewhere for the ball to live.
	var pole := apt._prop(Vector3(21.2, 0, 21.4), -90.0, Vector2(0.3, 0.3), 3.2, "Hoop")
	var hoop := apt._thing("hoop", pole, Vector3.ZERO, Vector3(1.3, 1.1, 1.0), Vector3(0, 2.75, 0.45), Vector3(0, 0, 2.4))
	Kit.cyl(hoop, 0.06, 3.3, Vector3(0, 1.65, 0), Apartment.C_DARK, 8)
	Kit.box(hoop, Vector3(1.2, 0.8, 0.05), Vector3(0, 3.0, 0.12), Apartment.C_WHITE)
	Kit.box(hoop, Vector3(0.45, 0.32, 0.055), Vector3(0, 2.85, 0.123), Color("e63946"))
	Kit.box(hoop, Vector3(0.38, 0.25, 0.058), Vector3(0, 2.85, 0.125), Apartment.C_WHITE)
	Kit.torus(hoop, 0.23, 0.02, Vector3(0, 2.65, 0.4), Color("ff7a1a"), 16, 6)
	Kit.cyl(hoop, 0.22, 0.3, Vector3(0, 2.48, 0.4), Color(1, 1, 1, 0.35), 10, 0.14)
	var ring := Area3D.new()
	ring.collision_layer = 0
	ring.collision_mask = Holdable.LAYER
	ring.monitorable = false
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.2
	shape.height = 0.12
	cs.shape = shape
	ring.add_child(cs)
	hoop.add_child(ring)
	ring.position = Vector3(0, 2.52, 0.4)
	apt.parts["hoop_ring"] = ring
	Kit.box(apt, Vector3(4.0, 0.012, 3.4), Vector3(19.3, 0.012, 21.4), Color("d98a5f"), 0.9)          # the court
	apt.spots["park"] = Vector3(19.0, 0.03, 22.4)
