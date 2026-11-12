class_name Apartment
extends Node3D
## Apartment — builds the whole flat procedurally: four rooms, every prop,
## collision, the mouse-pick volumes and the navigation grid.
##
## Convention: props are modelled with their FRONT facing +Z, then rotated.
## The flat is seen from the inside at eye height: full-height walls with
## doorways between the rooms, a ceiling, and furniture against the walls.

const X0 := -7.0
const X1 := 7.0
const Z0 := -5.5
const Z1 := 5.5
const WALL_H := 2.7
const DOOR_H := 2.08
const WALL_T := 0.2
const CELL := 0.25

const C_WALL := Color("f3e7d6")
const C_WALL_ACCENT := Color("e8d4bd")
const C_TRIM := Color("fffaf2")
const C_WOOD := Color("b9834f")
const C_WOOD_DARK := Color("8a5a36")
const C_WOOD_LIGHT := Color("e2bd8c")
const C_METAL := Color("c8ccd8")
const C_DARK := Color("2f2c3e")
const C_WHITE := Color("f7f5f0")

var things: Dictionary = {}            ## id -> Interactable
var parts: Dictionary = {}             ## named nodes / materials for live visuals
var lamps: Array = []                  ## OmniLight3D switched on at night
var ceiling_lights: Array = []         ## OmniLight3D on all day, brighter in the evening
var spots: Dictionary = {}             ## name -> Vector3 where loose items are put down
var bins: Array = []                   ## Area3D: what falls in is thrown away
var window_mats: Array = []            ## emissive panes tinted by time of day
var outer: Dictionary = {}             ## side -> {tall: Node3D, low: Node3D, normal: Vector3}
var nav := AStarGrid2D.new()
var _blocked: Array = []               ## Rect2 footprints (x,z) for the nav grid


func _ready() -> void:
	_floors()
	_walls()
	_ceiling()
	_office()
	_bedroom()
	_living()
	_kitchen()
	for id in things:
		(things[id] as Interactable).collect_meshes()
	_build_nav()


# ---------------------------------------------------------------------------
# Shell
# ---------------------------------------------------------------------------

func _floors() -> void:
	# Slab under everything (gives the flat a visible edge from any angle).
	Kit.box(self, Vector3(X1 - X0 + 0.4, 0.3, Z1 - Z0 + 0.4), Vector3(0, -0.16, 0), Color("4a4270"))
	var floor_body := Kit.solid(self, Vector3(40, 1, 40), Vector3(0, -0.5, 0))
	floor_body.name = "Floor"
	# Office: warm planks
	_planks(Rect2(X0, Z0, 7.0, 5.5), Color("c79462"), Color("bd8a59"), true)
	# Bedroom: soft carpet
	Kit.box(self, Vector3(7.0, 0.02, 5.5), Vector3(3.5, 0.0, -2.75), Color("c9b8e6"), 1.0)
	# Living room: light planks
	_planks(Rect2(X0, 0.0, 8.0, 5.5), Color("e3bf90"), Color("dab583"), false)
	# Kitchen: checker tiles
	for ix in 12:
		for iz in 11:
			var col := Color("f6f1e7") if (ix + iz) % 2 == 0 else Color("9fd3cc")
			Kit.box(self, Vector3(0.5, 0.02, 0.5), Vector3(1.25 + ix * 0.5, 0.0, 0.25 + iz * 0.5), col, 0.5)
	# Rugs
	_rug(Vector3(-4.2, 0, -3.1), Vector2(2.6, 1.7), Color("6c5ce7"), Color("a29bfe"))
	_rug(Vector3(3.2, 0, -1.9), Vector2(2.4, 1.6), Color("ff9ecb"), Color("ffd3e6"))
	_rug(Vector3(-4.7, 0, 2.9), Vector2(2.9, 2.6), Color("5ad1c8"), Color("d6f5f2"))


func _planks(r: Rect2, a: Color, b: Color, along_x: bool) -> void:
	var w := 0.5
	var n := int((r.size.y if along_x else r.size.x) / w)
	for i in n:
		var col := a if i % 2 == 0 else b
		if along_x:
			Kit.box(self, Vector3(r.size.x, 0.02, w), Vector3(r.position.x + r.size.x / 2.0, 0.0, r.position.y + w * (i + 0.5)), col, 0.7)
		else:
			Kit.box(self, Vector3(w, 0.02, r.size.y), Vector3(r.position.x + w * (i + 0.5), 0.0, r.position.y + r.size.y / 2.0), col, 0.7)


func _rug(pos: Vector3, size: Vector2, color: Color, edge: Color) -> void:
	Kit.box(self, Vector3(size.x, 0.02, size.y), pos + Vector3(0, 0.015, 0), edge, 1.0)
	Kit.box(self, Vector3(size.x - 0.3, 0.02, size.y - 0.3), pos + Vector3(0, 0.022, 0), color, 1.0)


func _walls() -> void:
	# Exterior walls.
	var sides := {
		"n": {"a": Vector3(X0, 0, Z0), "b": Vector3(X1, 0, Z0), "normal": Vector3(0, 0, -1)},
		"s": {"a": Vector3(X0, 0, Z1), "b": Vector3(X1, 0, Z1), "normal": Vector3(0, 0, 1)},
		"w": {"a": Vector3(X0, 0, Z0), "b": Vector3(X0, 0, Z1), "normal": Vector3(-1, 0, 0)},
		"e": {"a": Vector3(X1, 0, Z0), "b": Vector3(X1, 0, Z1), "normal": Vector3(1, 0, 0)},
	}
	for side in sides:
		var d: Dictionary = sides[side]
		var a: Vector3 = d.a
		var b: Vector3 = d.b
		var normal: Vector3 = d.normal
		var mid: Vector3 = (a + b) / 2.0 + normal * (WALL_T / 2.0)
		var along_x := absf(b.x - a.x) > 0.1
		var length := (b - a).length() + WALL_T * 2.0
		var size_tall := Vector3(length, WALL_H, WALL_T) if along_x else Vector3(WALL_T, WALL_H, length)
		var tall := Kit.node(self, Vector3.ZERO, "Wall_%s_tall" % side)
		var wall := Kit.box(tall, size_tall, mid + Vector3(0, WALL_H / 2.0, 0), C_WALL)
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var trim_size := Vector3(length, 0.12, 0.04) if along_x else Vector3(0.04, 0.12, length)
		var trim := Kit.box(tall, trim_size, (a + b) / 2.0 - normal * 0.02 + Vector3(0, 0.06, 0), C_TRIM)
		trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Kit.solid(self, size_tall, mid + Vector3(0, WALL_H / 2.0, 0))
		outer[side] = {"tall": tall, "normal": normal}
	# Windows and wall decor live on the tall walls so they hide with them.
	_window(outer.w.tall, Vector3(X0, 1.75, -3.9), true, 1.3)
	_window(outer.n.tall, Vector3(4.4, 1.85, Z0), false, 1.5)
	_window(outer.w.tall, Vector3(X0, 1.7, 4.6), true, 1.2)
	_window(outer.n.tall, Vector3(-6.2, 1.8, Z0), false, 0.9)
	_whiteboard(outer.n.tall, Vector3(-1.4, 1.7, Z0 + 0.03))
	_poster(outer.n.tall, Vector3(2.6, 1.75, Z0 + 0.03), Color("ff8c5a"), Color("ffd166"))
	_poster(outer.w.tall, Vector3(X0 + 0.03, 1.8, -1.5), Color("6c5ce7"), Color("5ad1c8"), true)
	_door(outer.s.tall, Vector3(-4.5, 0, Z1 - 0.02))
	_window(outer.e.tall, Vector3(X1, 1.7, 2.6), true, 1.6)
	_window(outer.s.tall, Vector3(4.2, 1.7, Z1), false, 1.6)
	_window(outer.e.tall, Vector3(X1, 1.75, -2.8), true, 1.4)
	# Things on the walls.
	_picture(Vector3(-0.9, 1.6, 0.115), 0.0, Vector2(0.7, 0.5), Color("9fd0f0"), Color("73d05c"))
	_picture(Vector3(0.05, 1.7, 0.115), 0.0, Vector2(0.4, 0.5), Color("ffb38a"), Color("8a5a36"))
	_picture(Vector3(-5.6, 1.62, 0.115), 0.0, Vector2(0.5, 0.4), Color("b48cff"), Color("5ad1c8"))
	_picture(Vector3(0.115, 1.6, -3.9), 90.0, Vector2(0.8, 0.55), Color("ffd6ae"), Color("ff9ecb"))
	_picture(Vector3(3.0, 1.65, -0.115), 180.0, Vector2(0.55, 0.42), Color("9fd0f0"), Color("ffd166"))
	_picture(Vector3(-0.115, 1.62, -4.4), -90.0, Vector2(0.5, 0.4), Color("ffd166"), Color("ff8c5a"))
	_clock(Vector3(1.115, 1.95, 1.1), 90.0)
	_picture(Vector3(1.115, 1.55, 4.7), 90.0, Vector2(0.5, 0.62), Color("fff1cf"), Color("ff5d73"))
	# Interior walls, with a doorway between each pair of rooms.
	_partition(Vector3(X0, 0, 0), Vector3(-4.0, 0, 0))
	_doorway(Vector3(-4.0, 0, 0), Vector3(-2.6, 0, 0))            # office <-> living room
	_partition(Vector3(-2.6, 0, 0), Vector3(5.3, 0, 0))
	_doorway(Vector3(5.3, 0, 0), Vector3(6.6, 0, 0))              # bedroom <-> kitchen
	_partition(Vector3(6.6, 0, 0), Vector3(X1, 0, 0))
	_partition(Vector3(0, 0, Z0), Vector3(0, 0, -2.2))
	_doorway(Vector3(0, 0, -2.2), Vector3(0, 0, -0.9))            # office <-> bedroom
	_partition(Vector3(0, 0, -0.9), Vector3(0, 0, 0))
	_partition(Vector3(1, 0, 0), Vector3(1, 0, 2.2))
	_doorway(Vector3(1, 0, 2.2), Vector3(1, 0, 3.8))              # living room <-> kitchen
	_partition(Vector3(1, 0, 3.8), Vector3(1, 0, Z1))


func _partition(a: Vector3, b: Vector3) -> void:
	var along_x := absf(b.x - a.x) > 0.1
	var length := (b - a).length()
	var size := Vector3(length, WALL_H, WALL_T) if along_x else Vector3(WALL_T, WALL_H, length)
	var mid := (a + b) / 2.0
	Kit.box(self, size, mid + Vector3(0, WALL_H / 2.0, 0), C_WALL)
	# Skirting board on both faces.
	var skirt := Vector3(length, 0.12, WALL_T + 0.05) if along_x else Vector3(WALL_T + 0.05, 0.12, length)
	Kit.box(self, skirt, mid + Vector3(0, 0.06, 0), C_TRIM)
	Kit.solid(self, size, mid + Vector3(0, WALL_H / 2.0, 0))
	_block(Rect2(mid.x - size.x / 2.0, mid.z - size.z / 2.0, size.x, size.z))


func _doorway(a: Vector3, b: Vector3) -> void:
	## An opening in an interior wall: the wall above it, and a frame.
	var along_x := absf(b.x - a.x) > 0.1
	var length := (b - a).length()
	var mid := (a + b) / 2.0
	var top := WALL_H - DOOR_H
	var lintel := Vector3(length, top, WALL_T) if along_x else Vector3(WALL_T, top, length)
	Kit.box(self, lintel, mid + Vector3(0, DOOR_H + top / 2.0, 0), C_WALL)
	Kit.solid(self, lintel, mid + Vector3(0, DOOR_H + top / 2.0, 0))
	var head := Vector3(length + 0.16, 0.09, WALL_T + 0.07) if along_x else Vector3(WALL_T + 0.07, 0.09, length + 0.16)
	Kit.box(self, head, mid + Vector3(0, DOOR_H - 0.045, 0), C_TRIM)
	for end in [a, b]:
		var jamb := Vector3(0.08, DOOR_H, WALL_T + 0.07) if along_x else Vector3(WALL_T + 0.07, DOOR_H, 0.08)
		Kit.box(self, jamb, (end as Vector3) + Vector3(0, DOOR_H / 2.0, 0), C_TRIM)


func _ceiling() -> void:
	var c := Kit.box(self, Vector3(X1 - X0 + 0.4, 0.2, Z1 - Z0 + 0.4), Vector3(0, WALL_H + 0.1, 0), C_TRIM)
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.solid(self, Vector3(X1 - X0 + 0.4, 0.2, Z1 - Z0 + 0.4), Vector3(0, WALL_H + 0.1, 0))


const CURTAINS := {"Home office": Color("5ad1c8"), "Bedroom": Color("ff9ecb"), "Living room": Color("ff9f5a"), "Kitchen": Color("ffd166")}


func _window(parent: Node3D, pos: Vector3, on_x_wall: bool, width: float) -> void:
	## A glowing pane mounted on the inside face of an exterior wall, with curtains.
	var inward := Vector3(signf(-pos.x), 0, 0) if on_x_wall else Vector3(0, 0, signf(-pos.z))
	var n := Kit.node(parent, pos + inward * 0.03)
	var h := 1.15
	var frame := Vector3(0.08, h + 0.16, width + 0.16) if on_x_wall else Vector3(width + 0.16, h + 0.16, 0.08)
	var pane := Vector3(0.05, h, width) if on_x_wall else Vector3(width, h, 0.05)
	var f := Kit.box(n, frame, Vector3.ZERO, C_TRIM)
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := Kit.screen_mat(Color("bfe6ff"), 1.2)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = pane
	mi.mesh = bm
	mi.material_override = m
	mi.position = inward * 0.03
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	window_mats.append(m)
	var bar_a := Vector3(0.07, h, 0.05) if on_x_wall else Vector3(0.05, h, 0.07)
	var bar_b := Vector3(0.07, 0.05, width) if on_x_wall else Vector3(width, 0.05, 0.07)
	Kit.box(n, bar_a, inward * 0.05, C_TRIM)
	Kit.box(n, bar_b, inward * 0.05, C_TRIM)
	var sill := Vector3(0.2, 0.05, width + 0.24) if on_x_wall else Vector3(width + 0.24, 0.05, 0.2)
	Kit.box(n, sill, inward * 0.08 + Vector3(0, -h / 2.0 - 0.1, 0), C_TRIM)
	# Curtains, drawn back, in the colour of the room.
	var cloth: Color = CURTAINS.get(room_at(pos + inward * 0.5), Color("ff9f5a"))
	var along := Vector3(0, 0, 1) if on_x_wall else Vector3(1, 0, 0)
	var rod := Vector3(0.03, 0.03, width + 0.7) if on_x_wall else Vector3(width + 0.7, 0.03, 0.03)
	Kit.box(n, rod, inward * 0.1 + Vector3(0, h / 2.0 + 0.2, 0), C_WOOD_DARK)
	for side in [-1.0, 1.0]:
		for fold in 3:
			var drape := Vector3(0.05, h + 0.42, 0.09) if on_x_wall else Vector3(0.09, h + 0.42, 0.05)
			var off: Vector3 = along * side * (width / 2.0 + 0.1 + 0.085 * float(fold))
			Kit.box(n, drape, inward * (0.09 + 0.012 * float(fold % 2)) + off + Vector3(0, -0.02, 0), cloth.darkened(0.07 * float(fold % 2)))


func _whiteboard(parent: Node3D, pos: Vector3) -> void:
	var n := Kit.node(parent, pos)
	Kit.box(n, Vector3(1.5, 0.95, 0.04), Vector3.ZERO, C_METAL)
	Kit.box(n, Vector3(1.4, 0.85, 0.045), Vector3(0, 0, 0.003), C_WHITE, 0.3)
	# "Q3 strategy": three boxes and some arrows going nowhere.
	for i in 3:
		Kit.box(n, Vector3(0.28, 0.16, 0.05), Vector3(-0.42 + i * 0.42, 0.18, 0.004), [Color("ff5d73"), Color("4fb3ff"), Color("5ad17a")][i])
	Kit.box(n, Vector3(0.9, 0.02, 0.05), Vector3(0, -0.02, 0.004), C_DARK)
	Kit.box(n, Vector3(0.5, 0.02, 0.05), Vector3(-0.2, -0.16, 0.004), C_DARK)
	Kit.box(n, Vector3(0.7, 0.02, 0.05), Vector3(0.1, -0.28, 0.004), Color("ff5d73"))


func _poster(parent: Node3D, pos: Vector3, a: Color, b: Color, on_x_wall: bool = false) -> void:
	var n := Kit.node(parent, pos)
	if on_x_wall:
		n.rotation.y = PI / 2.0
	Kit.box(n, Vector3(0.7, 0.95, 0.03), Vector3.ZERO, C_DARK)
	Kit.box(n, Vector3(0.62, 0.87, 0.035), Vector3(0, 0, 0.002), a)
	Kit.cyl(n, 0.18, 0.04, Vector3(0, 0.12, 0.005), b, 16).rotation.x = PI / 2.0
	Kit.box(n, Vector3(0.4, 0.06, 0.04), Vector3(0, -0.26, 0.004), C_WHITE)


func _picture(pos: Vector3, yaw_deg: float, size: Vector2, sky: Color, land: Color) -> void:
	## A framed picture: a hill, a sun, the kind every house has.
	var n := Kit.node(self, pos)
	n.rotation_degrees.y = yaw_deg
	Kit.box(n, Vector3(size.x + 0.08, size.y + 0.08, 0.03), Vector3.ZERO, C_WOOD_DARK)
	Kit.box(n, Vector3(size.x, size.y, 0.034), Vector3(0, 0, 0.002), C_WHITE)
	Kit.box(n, Vector3(size.x - 0.08, size.y - 0.08, 0.036), Vector3(0, 0, 0.004), sky)
	Kit.box(n, Vector3(size.x - 0.08, (size.y - 0.08) * 0.36, 0.038), Vector3(0, -(size.y - 0.08) * 0.32, 0.005), land)
	var sun_disc := Kit.cyl(n, size.y * 0.11, 0.04, Vector3(size.x * 0.2, size.y * 0.14, 0.006), Color("ffd166"), 12)
	sun_disc.rotation.x = PI / 2.0


func _clock(pos: Vector3, yaw_deg: float) -> void:
	var n := Kit.node(self, pos)
	n.rotation_degrees.y = yaw_deg
	Kit.cyl(n, 0.19, 0.04, Vector3.ZERO, C_DARK, 16).rotation.x = PI / 2.0
	Kit.cyl(n, 0.165, 0.045, Vector3(0, 0, 0.002), C_WHITE, 16).rotation.x = PI / 2.0
	Kit.box(n, Vector3(0.014, 0.11, 0.05), Vector3(0, 0.05, 0.004), C_DARK)
	var hand := Kit.box(n, Vector3(0.012, 0.08, 0.05), Vector3(0.03, -0.02, 0.004), Color("ff5d73"))
	hand.rotation.z = 2.2


func _door(parent: Node3D, pos: Vector3) -> void:
	var n := Kit.node(parent, pos)
	Kit.box(n, Vector3(1.1, 2.15, 0.06), Vector3(0, 1.07, 0), C_TRIM)
	Kit.box(n, Vector3(0.94, 2.0, 0.08), Vector3(0, 1.0, -0.01), Color("6c5ce7"))
	for panel in [Vector3(0, 1.5, -0.055), Vector3(0, 0.52, -0.055)]:
		Kit.box(n, Vector3(0.66, 0.72 if panel.y > 1.0 else 0.66, 0.02), panel, Color("7d6ff0"))
	Kit.ball(n, 0.05, Vector3(0.36, 1.0, -0.07), Color("ffd166"), 8)
	Kit.box(n, Vector3(0.3, 0.035, 0.02), Vector3(0, 1.05, -0.06), Color("ffd166"))               # letterbox
	var peep := Kit.cyl(n, 0.022, 0.02, Vector3(0, 1.6, -0.06), C_DARK, 8)
	peep.rotation.x = PI / 2.0
	Kit.box(self, Vector3(1.0, 0.02, 0.6), Vector3(pos.x, 0.02, pos.z - 0.4), Color("8a5a36"), 1.0)   # doormat
	spots["doormat"] = Vector3(pos.x, 0.035, pos.z - 0.42)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _block(r: Rect2) -> void:
	_blocked.append(r)


func _prop(pos: Vector3, yaw_deg: float, footprint: Vector2 = Vector2.ZERO, height: float = 1.0, node_name: String = "") -> Node3D:
	## A furniture root. `footprint` (width, depth in local space) becomes a
	## collider and blocks navigation.
	var n := Kit.node(self, pos, node_name)
	n.rotation_degrees.y = yaw_deg
	if footprint != Vector2.ZERO:
		var rotated := int(round(absf(yaw_deg) / 90.0)) % 2 == 1
		var fx := footprint.y if rotated else footprint.x
		var fz := footprint.x if rotated else footprint.y
		Kit.solid(self, Vector3(fx, height, fz), Vector3(pos.x, height / 2.0, pos.z))
		_block(Rect2(pos.x - fx / 2.0, pos.z - fz / 2.0, fx, fz))
	return n


func _thing(id: String, parent: Node3D, local_pos: Vector3, pick: Vector3, pick_center: Vector3, use_local: Vector3) -> Interactable:
	var t := Interactable.new()
	parent.add_child(t)
	t.position = local_pos
	t.setup(id, pick, pick_center)
	t.use_local = use_local
	things[id] = t
	return t


func _plant(pos: Vector3, scale_f: float = 1.0) -> void:
	var n := _prop(pos, 0.0, Vector2(0.4, 0.4) * scale_f, 1.0)
	n.scale = Vector3.ONE * scale_f
	Kit.cyl(n, 0.16, 0.3, Vector3(0, 0.15, 0), Color("d98a5f"), 8, 0.2)
	Kit.cyl(n, 0.03, 0.4, Vector3(0, 0.5, 0), Color("5a7a3a"), 6)
	for i in 5:
		var a := TAU * float(i) / 5.0
		var leaf := Kit.ball(n, 0.2, Vector3(cos(a) * 0.17, 0.72 + (i % 2) * 0.14, sin(a) * 0.17), Color("5ad17a").darkened(0.1 * (i % 3)), 6)
		leaf.scale = Vector3(1.0, 0.75, 1.0)
	Kit.ball(n, 0.22, Vector3(0, 0.98, 0), Color("6fe08c"), 6)


func _floor_lamp(pos: Vector3, color: Color = Color("ffd9a0")) -> void:
	var n := _prop(pos, 0.0, Vector2(0.3, 0.3), 1.6)
	Kit.cyl(n, 0.14, 0.04, Vector3(0, 0.02, 0), C_DARK, 10)
	Kit.cyl(n, 0.02, 1.5, Vector3(0, 0.77, 0), C_DARK, 6)
	Kit.cyl(n, 0.24, 0.3, Vector3(0, 1.6, 0), color, 10, 0.15, 0.6)
	lamps.append(Kit.lamp(n, Vector3(0, 1.5, 0), color, 2.2, 5.5))


func _ceiling_light(pos: Vector3, energy: float = 2.6, light_range: float = 7.5) -> void:
	var at := Vector3(pos.x, WALL_H, pos.z)
	Kit.cyl(self, 0.24, 0.05, at - Vector3(0, 0.025, 0), C_TRIM, 16)
	var shade := Kit.dome(self, 0.2, at - Vector3(0, 0.05, 0), Color("fff1cf"), 14)
	shade.rotation.x = PI
	shade.material_override = Kit.mat(Color("fff1cf"), 0.5, 1.4)
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ceiling_lights.append(Kit.lamp(self, at - Vector3(0, 0.45, 0), Color("ffe9c9"), energy, light_range, true))


func _spot(name: String, parent: Node3D, local: Vector3) -> void:
	## A named place where a loose item can sit (in world space, once built).
	spots[name] = parent.to_global(local) if parent.is_inside_tree() else parent.position + local


func _bin_trigger(pos: Vector3, radius: float) -> void:
	## Anything that falls through this is in the bin.
	var area := Area3D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = Holdable.LAYER
	area.monitorable = false
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.3
	cs.shape = shape
	area.add_child(cs)
	add_child(area)
	bins.append(area)


func _chair(parent: Node3D, pos: Vector3, yaw_deg: float, color: Color) -> Node3D:
	var n := Kit.node(parent, pos)
	n.rotation_degrees.y = yaw_deg
	Kit.box(n, Vector3(0.42, 0.05, 0.42), Vector3(0, 0.46, 0), color)
	Kit.box(n, Vector3(0.42, 0.5, 0.05), Vector3(0, 0.72, -0.19), color)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Kit.box(n, Vector3(0.05, 0.46, 0.05), Vector3(0.17 * sx, 0.23, 0.17 * sz), C_WOOD_DARK)
	return n


# ---------------------------------------------------------------------------
# Home office
# ---------------------------------------------------------------------------

func _office() -> void:
	_ceiling_light(Vector3(-3.6, 2.5, -2.8))
	# Main desk on the north wall.
	var desk := _prop(Vector3(-4.2, 0, -4.95), 0.0, Vector2(2.9, 0.8), 0.8, "Desk")
	Kit.box(desk, Vector3(2.9, 0.07, 0.8), Vector3(0, 0.76, 0), C_WOOD_LIGHT)
	for sx in [-1.0, 1.0]:
		Kit.box(desk, Vector3(0.07, 0.74, 0.7), Vector3(1.36 * sx, 0.37, 0), C_WHITE)
	Kit.box(desk, Vector3(0.5, 0.5, 0.6), Vector3(1.05, 0.48, 0), C_WHITE)          # drawers
	for i in 2:
		Kit.box(desk, Vector3(0.2, 0.03, 0.02), Vector3(1.05, 0.36 + i * 0.22, 0.31), C_METAL)
	# Work computer: monitor + tower.
	var ws := _thing("workstation", desk, Vector3(0, 0.8, -0.12), Vector3(1.0, 0.8, 0.5), Vector3(0, 0.35, 0), Vector3(0, -0.8, 1.6))
	Kit.box(ws, Vector3(0.3, 0.03, 0.2), Vector3(0, 0.015, 0), C_DARK)
	Kit.box(ws, Vector3(0.06, 0.2, 0.05), Vector3(0, 0.12, -0.02), C_DARK)
	Kit.box(ws, Vector3(0.9, 0.52, 0.05), Vector3(0, 0.46, 0), C_DARK)
	var scr := Kit.screen_mat(Color("3b5bdb"), 1.3)
	var smi := Kit.box(ws, Vector3(0.82, 0.44, 0.02), Vector3(0, 0.46, 0.03), Color.WHITE)
	smi.material_override = scr
	parts["work_screen"] = scr
	for i in 4:   # fake window chrome on the screen
		Kit.box(ws, Vector3(0.5 - i * 0.08, 0.035, 0.005), Vector3(-0.12, 0.6 - i * 0.08, 0.042), Color(1, 1, 1, 0.55), 0.3, 0.8)
	Kit.box(ws, Vector3(0.2, 0.42, 0.42), Vector3(-0.72, 0.21, 0.02), C_DARK)       # tower
	Kit.ball(ws, 0.02, Vector3(-0.72, 0.36, 0.235), Color("5ad17a"), 6, 3.0)
	var webcam := Kit.box(ws, Vector3(0.1, 0.05, 0.05), Vector3(0, 0.745, 0.01), C_DARK)
	webcam.name = "Webcam"
	Kit.ball(ws, 0.014, Vector3(0.03, 0.745, 0.04), Color("ff5d73"), 6, 3.0)
	# Keyboard & mouse (and the gadgets that live on them).
	var kb := _thing("keyboard", desk, Vector3(0.82, 0.8, 0.12), Vector3(0.75, 0.3, 0.4), Vector3(0, 0.1, 0), Vector3(0.05, -0.8, 0.82))
	Kit.box(kb, Vector3(0.46, 0.025, 0.16), Vector3(-0.08, 0.012, 0), C_DARK)
	for r in 3:
		Kit.box(kb, Vector3(0.42, 0.012, 0.035), Vector3(-0.08, 0.03, -0.05 + r * 0.05), Color("e9edf5"))
	Kit.box(kb, Vector3(0.24, 0.006, 0.2), Vector3(0.3, 0.003, 0), Color("6c5ce7"))  # mouse mat
	var mouse := Kit.box(kb, Vector3(0.06, 0.03, 0.1), Vector3(0.3, 0.02, 0), C_WHITE)
	parts["mouse"] = mouse
	var jig := Kit.node(kb, Vector3(0.3, 0.0, 0.0))
	Kit.box(jig, Vector3(0.14, 0.02, 0.16), Vector3(0, 0.008, 0), Color("ff5d73"))
	Kit.cyl(jig, 0.045, 0.012, Vector3(0, 0.022, 0), Color("ffd166"), 10)
	jig.visible = false
	parts["jiggler"] = jig
	var bird := Kit.node(kb, Vector3(-0.08, 0.0, -0.13))
	Kit.cyl(bird, 0.03, 0.02, Vector3(0, 0.01, 0), C_DARK, 8)
	var bird_tilt := Kit.node(bird, Vector3(0, 0.12, 0))
	Kit.cyl(bird_tilt, 0.008, 0.2, Vector3(0, 0, 0), Color("ff5d73"), 6)
	Kit.ball(bird_tilt, 0.04, Vector3(0, 0.1, 0), Color("ff5d73"), 8)
	Kit.cyl(bird_tilt, 0.012, 0.06, Vector3(0, 0.1, 0.05), Color("ffd166"), 6, 0.002).rotation.x = PI / 2.0
	Kit.cyl(bird_tilt, 0.035, 0.03, Vector3(0, 0.145, 0), C_DARK, 8)
	bird.visible = false
	parts["bird"] = bird
	parts["bird_tilt"] = bird_tilt
	# Coffee mug.
	var mug := _thing("mug", desk, Vector3(-0.95, 0.8, 0.1), Vector3(0.4, 0.4, 0.4), Vector3(0, 0.1, 0), Vector3(-0.02, -0.8, 0.84))
	Kit.cyl(mug, 0.06, 0.12, Vector3(0, 0.06, 0), Color("ff8c5a"), 10)
	Kit.cyl(mug, 0.05, 0.01, Vector3(0, 0.118, 0), Color("4a2c1a"), 10)
	Kit.box(mug, Vector3(0.03, 0.07, 0.02), Vector3(0.075, 0.06, 0), Color("ff8c5a"))
	Kit.box(mug, Vector3(0.2, 0.006, 0.2), Vector3(0, 0.003, 0), C_WOOD_DARK)        # coaster
	# Desk clutter (not interactive).
	Kit.box(desk, Vector3(0.24, 0.02, 0.32), Vector3(-0.42, 0.81, -0.2), C_WHITE)
	Kit.box(desk, Vector3(0.1, 0.1, 0.1), Vector3(0.52, 0.85, -0.26), Color("ffd166"))
	Kit.cyl(desk, 0.05, 0.14, Vector3(1.28, 0.87, -0.22), Color("5ad1c8"), 8)
	_spot("desk", desk, Vector3(-0.52, 0.8, 0.16))
	_spot("desk_left", desk, Vector3(-1.27, 0.8, 0.22))
	_spot("desk_right", desk, Vector3(1.27, 0.8, 0.2))
	# Office chair.
	var chair_root := _prop(Vector3(-4.2, 0, -4.02), 180.0, Vector2(0.55, 0.55), 0.9, "OfficeChair")
	var chair := _thing("chair", chair_root, Vector3.ZERO, Vector3(0.6, 1.1, 0.6), Vector3(0, 0.55, 0), Vector3(-0.85, 0, -0.1))
	Kit.cyl(chair, 0.26, 0.04, Vector3(0, 0.05, 0), C_DARK, 5)
	Kit.cyl(chair, 0.03, 0.34, Vector3(0, 0.24, 0), C_METAL, 6)
	Kit.box(chair, Vector3(0.5, 0.08, 0.5), Vector3(0, 0.46, 0), Color("6c5ce7"))
	Kit.box(chair, Vector3(0.46, 0.56, 0.07), Vector3(0, 0.82, -0.23), Color("6c5ce7"))
	Kit.box(chair, Vector3(0.32, 0.16, 0.07), Vector3(0, 1.18, -0.23), Color("5a4bd1"))
	for sx in [-1.0, 1.0]:
		Kit.box(chair, Vector3(0.05, 0.04, 0.3), Vector3(0.27 * sx, 0.66, 0.0), C_DARK)
	chair.seat = {"pos": Vector3(0, 0.02, 0.0), "yaw": PI, "lie": false}
	ws.seat = {"pos": Vector3(0, 0.02, 0.0), "yaw": PI, "lie": false, "root": chair_root}
	kb.seat = ws.seat
	mug.seat = {}
	# Company laptop on a side desk (west wall).
	var side := _prop(Vector3(-6.52, 0, -3.3), 90.0, Vector2(1.3, 0.7), 0.8, "SideDesk")
	Kit.box(side, Vector3(1.3, 0.06, 0.7), Vector3(0, 0.76, 0), C_WOOD_LIGHT)
	for sx in [-1.0, 1.0]:
		Kit.box(side, Vector3(0.06, 0.74, 0.6), Vector3(0.6 * sx, 0.37, 0), C_WHITE)
	var lap := _thing("laptop", side, Vector3(0, 0.8, 0), Vector3(0.7, 0.5, 0.55), Vector3(0, 0.2, 0), Vector3(0, -0.8, 1.05))
	Kit.box(lap, Vector3(0.46, 0.025, 0.32), Vector3(0, 0.012, 0.06), C_METAL)
	var lid := Kit.node(lap, Vector3(0, 0.02, -0.1))
	lid.rotation_degrees.x = -18
	Kit.box(lid, Vector3(0.46, 0.3, 0.02), Vector3(0, 0.15, 0), C_METAL)
	var lscr := Kit.screen_mat(Color("3b5bdb"), 1.2)
	Kit.box(lid, Vector3(0.4, 0.24, 0.006), Vector3(0, 0.15, 0.012), Color.WHITE).material_override = lscr
	parts["laptop_screen"] = lscr
	Kit.box(lap, Vector3(0.16, 0.012, 0.1), Vector3(0.38, 0.006, 0.08), Color("ff5d73"))       # "PROPERTY OF SYNERCORP" sticker pad
	Kit.cyl(side, 0.07, 0.2, Vector3(-0.48, 0.89, -0.18), Color("5ad17a"), 8)
	# Personal gaming PC (west wall).
	var gdesk := _prop(Vector3(-6.5, 0, -1.25), 90.0, Vector2(1.5, 0.75), 0.8, "GamingDesk")
	Kit.box(gdesk, Vector3(1.5, 0.07, 0.75), Vector3(0, 0.76, 0), C_DARK)
	for sx in [-1.0, 1.0]:
		Kit.box(gdesk, Vector3(0.07, 0.74, 0.65), Vector3(0.68 * sx, 0.37, 0), C_DARK)
	Kit.box(gdesk, Vector3(1.4, 0.02, 0.03), Vector3(0, 0.74, 0.37), Color("ff5d73"), 0.5, 2.5)  # RGB strip
	var gpc := _thing("gaming_pc", gdesk, Vector3(0, 0.8, -0.06), Vector3(1.3, 0.8, 0.6), Vector3(0, 0.35, 0), Vector3(0, -0.8, 1.5))
	Kit.box(gpc, Vector3(0.28, 0.03, 0.18), Vector3(-0.15, 0.015, -0.02), C_DARK)
	Kit.box(gpc, Vector3(0.05, 0.16, 0.05), Vector3(-0.15, 0.1, -0.04), C_DARK)
	var gm := Kit.box(gpc, Vector3(0.86, 0.46, 0.05), Vector3(-0.15, 0.42, -0.02), C_DARK)
	gm.rotation_degrees.y = 4
	var gscr := Kit.screen_mat(Color("b48cff"), 1.6)
	var gsm := Kit.box(gpc, Vector3(0.78, 0.38, 0.02), Vector3(-0.15, 0.42, 0.01), Color.WHITE)
	gsm.rotation_degrees.y = 4
	gsm.material_override = gscr
	parts["game_screen"] = gscr
	Kit.box(gpc, Vector3(0.22, 0.46, 0.44), Vector3(0.5, 0.23, 0.0), C_DARK)                    # tower
	for i in 3:
		Kit.cyl(gpc, 0.06, 0.01, Vector3(0.5, 0.1 + i * 0.13, 0.225), [Color("ff5d73"), Color("5ad17a"), Color("4fb3ff")][i], 10, -1.0, 2.5).rotation.x = PI / 2.0
	Kit.box(gpc, Vector3(0.4, 0.02, 0.14), Vector3(-0.15, 0.01, 0.24), Color("ff5d73"), 0.5, 0.6)
	Kit.ball(gpc, 0.035, Vector3(0.18, 0.02, 0.24), Color("5ad17a"), 8, 1.0)
	var gchair := _chair(self, Vector3(-5.72, 0, -1.25), -90.0, Color("ff5d73"))
	Kit.box(gchair, Vector3(0.36, 0.3, 0.05), Vector3(0, 1.1, -0.19), Color("ff5d73"))          # headrest
	Kit.solid(self, Vector3(0.45, 0.9, 0.45), Vector3(-5.72, 0.45, -1.25))
	_block(Rect2(-5.95, -1.48, 0.46, 0.46))
	gpc.seat = {"pos": Vector3(0, 0.02, 0.0), "yaw": PI, "lie": false, "root": gchair}
	# Printer on a cabinet (north wall).
	var cab := _prop(Vector3(-1.95, 0, -5.08), 0.0, Vector2(0.9, 0.55), 0.7, "PrinterCabinet")
	Kit.box(cab, Vector3(0.9, 0.62, 0.55), Vector3(0, 0.31, 0), C_WHITE)
	Kit.box(cab, Vector3(0.4, 0.5, 0.02), Vector3(-0.22, 0.31, 0.28), C_WALL_ACCENT)
	Kit.box(cab, Vector3(0.4, 0.5, 0.02), Vector3(0.22, 0.31, 0.28), C_WALL_ACCENT)
	var pr := _thing("printer", cab, Vector3(0, 0.62, 0), Vector3(0.8, 0.55, 0.55), Vector3(0, 0.2, 0), Vector3(0, -0.62, 0.95))
	Kit.box(pr, Vector3(0.62, 0.22, 0.44), Vector3(0, 0.11, 0), Color("dfe3ec"))
	Kit.box(pr, Vector3(0.5, 0.05, 0.3), Vector3(0, 0.25, -0.04), C_DARK)
	Kit.box(pr, Vector3(0.4, 0.015, 0.26), Vector3(0, 0.05, 0.3), C_WHITE)
	var paper := Kit.box(pr, Vector3(0.34, 0.01, 0.2), Vector3(0, 0.065, 0.3), Color.WHITE)
	parts["printer_paper"] = paper
	var pled := Kit.screen_mat(Color("5ad17a"), 3.0)
	Kit.box(pr, Vector3(0.05, 0.02, 0.02), Vector3(0.24, 0.17, 0.225), Color.WHITE).material_override = pled
	parts["printer_led"] = pled
	# Router on a wall shelf.
	var shelf := _prop(Vector3(-0.72, 0, -5.12), 0.0, Vector2(0.75, 0.45), 0.9, "RouterShelf")
	Kit.box(shelf, Vector3(0.75, 0.05, 0.42), Vector3(0, 0.86, 0), C_WOOD_LIGHT)
	Kit.box(shelf, Vector3(0.06, 0.86, 0.38), Vector3(-0.32, 0.43, 0), C_WOOD)
	Kit.box(shelf, Vector3(0.06, 0.86, 0.38), Vector3(0.32, 0.43, 0), C_WOOD)
	Kit.box(shelf, Vector3(0.6, 0.04, 0.36), Vector3(0, 0.4, 0), C_WOOD)
	Kit.box(shelf, Vector3(0.3, 0.2, 0.26), Vector3(0, 0.52, 0), Color("ffd166"))              # a box of cables
	var ro := _thing("router", shelf, Vector3(0, 0.89, 0), Vector3(0.6, 0.5, 0.45), Vector3(0, 0.15, 0), Vector3(0, -0.89, 0.92))
	Kit.box(ro, Vector3(0.42, 0.07, 0.26), Vector3(0, 0.035, 0), C_WHITE)
	for sx in [-1.0, 1.0]:
		var ant := Kit.cyl(ro, 0.012, 0.3, Vector3(0.17 * sx, 0.2, -0.1), C_DARK, 6)
		ant.rotation_degrees.z = -12.0 * sx
	var leds: Array = []
	for i in 4:
		var lm := Kit.screen_mat(Color("5ad17a"), 3.0)
		Kit.box(ro, Vector3(0.03, 0.015, 0.01), Vector3(-0.12 + i * 0.08, 0.04, 0.132), Color.WHITE).material_override = lm
		leds.append(lm)
	parts["router_leds"] = leds
	var plug := Kit.box(ro, Vector3(0.06, 0.04, 0.2), Vector3(0.26, 0.03, 0.02), C_DARK)
	parts["router_plug"] = plug
	_plant(Vector3(-0.55, 0, -0.5), 1.1)
	_plant(Vector3(-6.55, 0, -4.95), 0.8)
	# Recycling bin: open-topped, so things can be thrown into it.
	var rb := Kit.node(self, Vector3(-2.75, 0, -5.2))
	for sx in [-1.0, 1.0]:
		Kit.box(rb, Vector3(0.03, 0.42, 0.34), Vector3(0.235 * sx, 0.21, 0), Color("5ad1c8"))
		Kit.box(rb, Vector3(0.5, 0.42, 0.03), Vector3(0, 0.21, 0.155 * sx), Color("5ad1c8"))
	Kit.box(rb, Vector3(0.5, 0.03, 0.34), Vector3(0, 0.015, 0), Color("4ab8b0"))
	Kit.solid(self, Vector3(0.5, 0.2, 0.34), Vector3(-2.75, 0.1, -5.2))
	_bin_trigger(Vector3(-2.75, 0.36, -5.2), 0.2)
	_block(Rect2(-3.0, -5.4, 0.5, 0.4))


# ---------------------------------------------------------------------------
# Bedroom
# ---------------------------------------------------------------------------

func _bedroom() -> void:
	_ceiling_light(Vector3(3.6, 2.5, -2.8))
	# Bed, headboard on the north wall.
	var bed_root := _prop(Vector3(4.4, 0, -4.25), 0.0, Vector2(1.9, 2.3), 0.6, "Bed")
	var bed := _thing("bed", bed_root, Vector3.ZERO, Vector3(1.9, 0.9, 2.3), Vector3(0, 0.45, 0), Vector3(-1.4, 0, 0.5))
	Kit.box(bed, Vector3(1.9, 0.28, 2.3), Vector3(0, 0.14, 0), C_WOOD)
	Kit.box(bed, Vector3(1.8, 0.2, 2.2), Vector3(0, 0.38, 0), C_WHITE)
	Kit.box(bed, Vector3(1.9, 0.9, 0.12), Vector3(0, 0.55, -1.12), C_WOOD_DARK)
	Kit.box(bed, Vector3(1.84, 0.1, 1.4), Vector3(0, 0.5, 0.38), Color("6c5ce7"))                 # duvet
	Kit.box(bed, Vector3(1.84, 0.11, 0.25), Vector3(0, 0.5, -0.42), Color("a29bfe"))
	for sx in [-1.0, 1.0]:
		Kit.box(bed, Vector3(0.62, 0.13, 0.4), Vector3(0.45 * sx, 0.53, -0.82), Color("fff5d6"))
	bed.seat = {"pos": Vector3(-0.42, 0.7, 0.78), "yaw": PI, "lie": true}
	# Nightstand + phone charger.
	var ns := _prop(Vector3(5.85, 0, -5.1), 0.0, Vector2(0.55, 0.5), 0.6, "Nightstand")
	Kit.box(ns, Vector3(0.55, 0.5, 0.48), Vector3(0, 0.25, 0), C_WOOD)
	Kit.box(ns, Vector3(0.45, 0.16, 0.02), Vector3(0, 0.33, 0.245), C_WOOD_LIGHT)
	Kit.ball(ns, 0.02, Vector3(0, 0.33, 0.26), C_METAL, 6)
	var ch := _thing("charger", ns, Vector3(0, 0.5, 0.02), Vector3(0.55, 0.5, 0.5), Vector3(0, 0.15, 0), Vector3(0.1, -0.5, 0.95))
	Kit.cyl(ch, 0.09, 0.025, Vector3(-0.08, 0.012, 0.05), C_WHITE, 12)
	var cled := Kit.screen_mat(Color("5ad17a"), 2.5)
	Kit.cyl(ch, 0.095, 0.006, Vector3(-0.08, 0.004, 0.05), Color.WHITE, 12).material_override = cled
	parts["charger_led"] = cled
	var phone := Kit.node(ch, Vector3(-0.08, 0.03, 0.05))
	Kit.box(phone, Vector3(0.09, 0.012, 0.17), Vector3.ZERO, C_DARK)
	Kit.box(phone, Vector3(0.08, 0.004, 0.155), Vector3(0, 0.008, 0), Color("4fb3ff"), 0.3, 1.2)
	phone.visible = false
	parts["phone"] = phone
	_spot("nightstand", ns, Vector3(0.14, 0.5, 0.14))
	Kit.cyl(ch, 0.05, 0.14, Vector3(0.16, 0.07, -0.1), C_WHITE, 8)                                  # lamp base
	Kit.cyl(ch, 0.1, 0.14, Vector3(0.16, 0.2, -0.1), Color("ffd9a0"), 8, 0.06, 0.8)
	lamps.append(Kit.lamp(ch, Vector3(0.16, 0.3, -0.1), Color("ffd9a0"), 1.2, 3.5))
	# Wardrobe.
	var wr := _prop(Vector3(1.3, 0, -5.12), 0.0, Vector2(1.6, 0.6), 2.0, "Wardrobe")
	var wd := _thing("wardrobe", wr, Vector3.ZERO, Vector3(1.6, 2.0, 0.6), Vector3(0, 1.0, 0), Vector3(0, 0, 1.0))
	Kit.box(wd, Vector3(1.6, 2.0, 0.6), Vector3(0, 1.0, 0), C_WOOD)
	for sx in [-1.0, 1.0]:
		Kit.box(wd, Vector3(0.74, 1.8, 0.03), Vector3(0.39 * sx, 1.0, 0.31), C_WOOD_LIGHT)
		Kit.box(wd, Vector3(0.03, 0.3, 0.03), Vector3(0.07 * sx, 1.05, 0.34), C_METAL)
	Kit.box(wd, Vector3(1.66, 0.06, 0.66), Vector3(0, 2.03, 0), C_WOOD_DARK)
	Kit.box(wd, Vector3(0.5, 0.22, 0.4), Vector3(-0.4, 2.17, 0), Color("ff9ecb"))                  # a box on top
	# Decor.
	_plant(Vector3(0.55, 0, -0.5), 0.9)
	var basket := _prop(Vector3(6.5, 0, -2.2), 0.0, Vector2(0.5, 0.5), 0.5)
	Kit.cyl(basket, 0.22, 0.45, Vector3(0, 0.22, 0), Color("e2bd8c"), 8, 0.26)
	Kit.ball(basket, 0.18, Vector3(0, 0.44, 0), Color("4fb3ff"), 6)
	Kit.box(self, Vector3(0.3, 0.06, 0.2), Vector3(2.5, 0.05, -3.2), Color("ff5d73"))             # stray sock
	Kit.box(self, Vector3(0.26, 0.05, 0.3), Vector3(5.9, 0.04, -3.3), Color("ffd166"))            # slippers


# ---------------------------------------------------------------------------
# Living room
# ---------------------------------------------------------------------------

func _living() -> void:
	_ceiling_light(Vector3(-3.4, 2.5, 2.8), 2.8, 8.0)
	# TV stand + TV on the west wall.
	var stand := _prop(Vector3(-6.62, 0, 2.9), 90.0, Vector2(2.0, 0.5), 0.55, "TVStand")
	Kit.box(stand, Vector3(2.0, 0.45, 0.5), Vector3(0, 0.23, 0), C_WOOD)
	Kit.box(stand, Vector3(0.9, 0.3, 0.02), Vector3(-0.48, 0.22, 0.25), C_WOOD_LIGHT)
	Kit.box(stand, Vector3(0.9, 0.3, 0.02), Vector3(0.48, 0.22, 0.25), C_WOOD_LIGHT)
	var tv := _thing("tv", stand, Vector3(0, 0.46, -0.04), Vector3(1.7, 1.1, 0.5), Vector3(0, 0.55, 0), Vector3(0.9, -0.46, 0.78))
	Kit.box(tv, Vector3(0.5, 0.03, 0.22), Vector3(0, 0.015, 0), C_DARK)
	Kit.box(tv, Vector3(0.08, 0.14, 0.06), Vector3(0, 0.09, 0), C_DARK)
	Kit.box(tv, Vector3(1.6, 0.92, 0.06), Vector3(0, 0.62, 0), C_DARK)
	var tscr := Kit.screen_mat(Color("15131f"), 0.2)
	Kit.box(tv, Vector3(1.5, 0.82, 0.02), Vector3(0, 0.62, 0.035), Color.WHITE).material_override = tscr
	parts["tv_screen"] = tscr
	var tvl := Kit.lamp(tv, Vector3(0, 0.6, 0.8), Color("8fb8ff"), 0.0, 4.5)
	parts["tv_light"] = tvl
	# Coffee table + console.
	var table := _prop(Vector3(-5.2, 0, 2.9), 90.0, Vector2(1.2, 0.6), 0.42, "CoffeeTable")
	Kit.box(table, Vector3(1.2, 0.06, 0.6), Vector3(0, 0.38, 0), C_WOOD_LIGHT)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Kit.box(table, Vector3(0.06, 0.36, 0.06), Vector3(0.52 * sx, 0.18, 0.22 * sz), C_WOOD_DARK)
	var con := _thing("console", table, Vector3(0.25, 0.41, 0), Vector3(0.75, 0.4, 0.55), Vector3(0, 0.1, 0), Vector3(0.15, -0.41, 0.82))
	Kit.box(con, Vector3(0.34, 0.07, 0.26), Vector3(-0.1, 0.035, 0), C_WHITE)
	Kit.box(con, Vector3(0.34, 0.012, 0.03), Vector3(-0.1, 0.045, 0.132), Color("4fb3ff"), 0.4, 2.5)
	var pad := Kit.node(con, Vector3(0.22, 0.02, 0.06))
	pad.rotation_degrees.y = 25
	Kit.box(pad, Vector3(0.16, 0.035, 0.09), Vector3.ZERO, C_DARK)
	Kit.ball(pad, 0.014, Vector3(-0.04, 0.022, 0), Color("ff5d73"), 6)
	Kit.ball(pad, 0.014, Vector3(0.04, 0.022, 0), Color("5ad17a"), 6)
	Kit.box(table, Vector3(0.2, 0.03, 0.14), Vector3(-0.44, 0.425, -0.2), Color("ff5d73"))         # a magazine
	_spot("coffee_table", table, Vector3(-0.3, 0.41, 0.06))
	_spot("tv_stand", stand, Vector3(0.82, 0.455, 0.06))
	# Sofa, facing the TV.
	var sofa_root := _prop(Vector3(-3.4, 0, 2.9), -90.0, Vector2(2.3, 0.95), 0.8, "Sofa")
	var sofa := _thing("sofa", sofa_root, Vector3.ZERO, Vector3(2.3, 0.95, 0.95), Vector3(0, 0.45, 0), Vector3(-0.7, 0, 0.95))
	Kit.box(sofa, Vector3(2.3, 0.3, 0.95), Vector3(0, 0.17, 0), Color("ff8c5a"))
	Kit.box(sofa, Vector3(2.3, 0.6, 0.24), Vector3(0, 0.55, -0.36), Color("ff8c5a"))
	for sx in [-1.0, 1.0]:
		Kit.box(sofa, Vector3(0.22, 0.42, 0.95), Vector3(1.04 * sx, 0.4, 0), Color("f07a48"))
		Kit.box(sofa, Vector3(0.9, 0.14, 0.62), Vector3(0.46 * sx, 0.37, 0.1), Color("ffa477"))
	Kit.box(sofa, Vector3(0.36, 0.34, 0.14), Vector3(-0.72, 0.6, -0.2), Color("5ad1c8")).rotation_degrees.x = -14
	Kit.box(sofa, Vector3(0.36, 0.34, 0.14), Vector3(0.74, 0.6, -0.2), Color("ffd166")).rotation_degrees.x = -14
	sofa.seat = {"pos": Vector3(0.1, 0.0, 0.16), "yaw": PI, "lie": false}
	_spot("sofa", sofa_root, Vector3(-0.72, 0.45, 0.14))
	tv.seat = {"pos": Vector3(-0.4, 0.0, 0.16), "yaw": PI, "lie": false, "root": sofa_root}
	con.seat = {"pos": Vector3(0.5, 0.0, 0.16), "yaw": PI, "lie": false, "root": sofa_root}
	# Bookshelf on the west wall.
	var bs_root := _prop(Vector3(-6.68, 0, 0.9), 90.0, Vector2(1.25, 0.42), 1.9, "Bookshelf")
	var bs := _thing("bookshelf", bs_root, Vector3.ZERO, Vector3(1.25, 1.9, 0.42), Vector3(0, 0.95, 0), Vector3(0, 0, 0.9))
	Kit.box(bs, Vector3(1.25, 1.9, 0.06), Vector3(0, 0.95, -0.18), C_WOOD_DARK)
	for sx in [-1.0, 1.0]:
		Kit.box(bs, Vector3(0.06, 1.9, 0.42), Vector3(0.6 * sx, 0.95, 0), C_WOOD)
	var book_cols := [Color("ff5d73"), Color("4fb3ff"), Color("5ad17a"), Color("ffd166"), Color("b48cff"), Color("ff8c5a"), Color("5ad1c8")]
	for row in 5:
		Kit.box(bs, Vector3(1.2, 0.05, 0.4), Vector3(0, 0.03 + row * 0.45, 0), C_WOOD)
		var x := -0.52
		var i := row * 3
		while x < 0.48 and row < 4:
			var w := 0.06 + 0.03 * float((i * 7) % 3)
			var h := 0.26 + 0.04 * float((i * 5) % 4)
			if (i * 11) % 9 != 0:
				Kit.box(bs, Vector3(w, h, 0.26), Vector3(x + w / 2.0, 0.06 + row * 0.45 + h / 2.0, 0.02), book_cols[i % book_cols.size()])
			x += w + 0.012
			i += 1
	Kit.box(bs, Vector3(1.25, 0.05, 0.42), Vector3(0, 1.9, 0), C_WOOD)
	_plant(Vector3(-6.55, 0, 1.95), 0.7)
	# Exercise bike.
	var bike_root := _prop(Vector3(-0.75, 0, 4.45), 90.0, Vector2(0.6, 1.3), 1.0, "Bike")
	var bike := _thing("exercise", bike_root, Vector3.ZERO, Vector3(0.7, 1.3, 1.3), Vector3(0, 0.65, 0), Vector3(-0.85, 0, 0.0))
	Kit.box(bike, Vector3(0.5, 0.06, 0.12), Vector3(0, 0.03, 0.5), C_DARK)
	Kit.box(bike, Vector3(0.5, 0.06, 0.12), Vector3(0, 0.03, -0.5), C_DARK)
	Kit.box(bike, Vector3(0.08, 0.08, 1.0), Vector3(0, 0.1, 0), C_DARK)
	var wheel := Kit.cyl(bike, 0.26, 0.07, Vector3(0, 0.36, -0.36), Color("ff5d73"), 14)
	wheel.rotation.z = PI / 2.0
	parts["bike_wheel"] = wheel
	Kit.box(bike, Vector3(0.07, 0.75, 0.07), Vector3(0, 0.5, 0.26), C_METAL).rotation_degrees.x = 10
	Kit.box(bike, Vector3(0.26, 0.07, 0.32), Vector3(0, 0.9, 0.32), C_DARK)                        # saddle
	Kit.box(bike, Vector3(0.07, 0.95, 0.07), Vector3(0, 0.6, -0.34), C_METAL).rotation_degrees.x = -12
	Kit.box(bike, Vector3(0.5, 0.05, 0.05), Vector3(0, 1.08, -0.44), C_DARK)                       # handlebar
	Kit.box(bike, Vector3(0.16, 0.12, 0.03), Vector3(0, 1.16, -0.42), Color("5ad17a"), 0.4, 1.5)
	bike.seat = {"pos": Vector3(0, 0.4, 0.3), "yaw": 0.0, "lie": false}
	# Decor.
	_floor_lamp(Vector3(-6.5, 0, 4.95))
	_plant(Vector3(0.45, 0, 0.55), 1.2)
	var rack := _prop(Vector3(-2.6, 0, 5.15), 0.0, Vector2(0.9, 0.4), 0.5)
	Kit.box(rack, Vector3(0.9, 0.04, 0.34), Vector3(0, 0.2, 0), C_WOOD)
	Kit.box(rack, Vector3(0.9, 0.04, 0.34), Vector3(0, 0.42, 0), C_WOOD)
	for sx in [-1.0, 1.0]:
		Kit.box(rack, Vector3(0.04, 0.44, 0.34), Vector3(0.43 * sx, 0.22, 0), C_WOOD_DARK)
	Kit.box(rack, Vector3(0.2, 0.1, 0.26), Vector3(-0.2, 0.27, 0), Color("4fb3ff"))
	Kit.box(rack, Vector3(0.2, 0.1, 0.26), Vector3(0.14, 0.27, 0), C_WHITE)


# ---------------------------------------------------------------------------
# Kitchen
# ---------------------------------------------------------------------------

func _kitchen() -> void:
	_ceiling_light(Vector3(4.0, 2.5, 2.8))
	# Refrigerator.
	var fr_root := _prop(Vector3(1.62, 0, 0.5), 0.0, Vector2(0.85, 0.78), 1.95, "Fridge")
	var fr := _thing("fridge", fr_root, Vector3.ZERO, Vector3(0.85, 1.95, 0.78), Vector3(0, 0.97, 0), Vector3(0, 0, 1.02))
	Kit.box(fr, Vector3(0.85, 1.95, 0.75), Vector3(0, 0.975, 0), Color("dfe7f2"), 0.35)
	Kit.box(fr, Vector3(0.8, 0.02, 0.02), Vector3(0, 1.28, 0.38), Color("9aa6ba"))
	Kit.box(fr, Vector3(0.04, 0.4, 0.04), Vector3(-0.32, 1.58, 0.4), C_METAL)
	Kit.box(fr, Vector3(0.04, 0.6, 0.04), Vector3(-0.32, 0.86, 0.4), C_METAL)
	for i in 4:   # fridge magnets
		Kit.box(fr, Vector3(0.09, 0.09, 0.01), Vector3(0.05 + (i % 2) * 0.16, 1.5 + int(i / 2.0) * 0.16, 0.381), [Color("ff5d73"), Color("ffd166"), Color("5ad17a"), Color("4fb3ff")][i])
	# Counter run along the north partition.
	var ct := _prop(Vector3(3.6, 0, 0.44), 0.0, Vector2(3.0, 0.64), 0.92, "Counter")
	Kit.box(ct, Vector3(3.0, 0.86, 0.6), Vector3(0, 0.43, 0), Color("5ad1c8"))
	Kit.box(ct, Vector3(3.06, 0.06, 0.66), Vector3(0, 0.89, 0), C_WHITE, 0.3)
	for i in 5:
		Kit.box(ct, Vector3(0.52, 0.66, 0.02), Vector3(-1.2 + i * 0.6, 0.45, 0.31), Color("7fe0d8"))
		Kit.box(ct, Vector3(0.14, 0.03, 0.03), Vector3(-1.2 + i * 0.6, 0.72, 0.33), C_METAL)
	Kit.box(ct, Vector3(0.62, 0.02, 0.42), Vector3(0.1, 0.925, 0), C_METAL, 0.3)                    # sink
	Kit.cyl(ct, 0.02, 0.26, Vector3(0.1, 1.05, -0.2), C_METAL, 6)
	Kit.box(ct, Vector3(0.03, 0.03, 0.16), Vector3(0.1, 1.17, -0.13), C_METAL)
	# Coffee machine.
	var cf := _thing("coffee", ct, Vector3(-0.85, 0.92, -0.02), Vector3(0.55, 0.6, 0.6), Vector3(0, 0.25, 0), Vector3(0, -0.92, 0.9))
	Kit.box(cf, Vector3(0.34, 0.08, 0.34), Vector3(0, 0.04, 0), C_DARK)
	Kit.box(cf, Vector3(0.34, 0.44, 0.14), Vector3(0, 0.26, -0.1), Color("ff5d73"))
	Kit.box(cf, Vector3(0.34, 0.1, 0.34), Vector3(0, 0.46, 0), Color("ff5d73"))
	Kit.cyl(cf, 0.09, 0.16, Vector3(0, 0.17, 0.06), Color(0.8, 0.9, 1.0, 0.5), 10)
	Kit.cyl(cf, 0.08, 0.1, Vector3(0, 0.14, 0.06), Color("4a2c1a"), 10)
	var cled := Kit.screen_mat(Color("ffd166"), 2.5)
	Kit.ball(cf, 0.022, Vector3(0.11, 0.46, 0.175), Color.WHITE, 6).material_override = cled
	parts["coffee_led"] = cled
	var steam := Kit.node(cf, Vector3(0, 0.3, 0.06))
	for i in 3:
		Kit.ball(steam, 0.035, Vector3(0.03 * (i - 1), 0.07 * i, 0), Color(1, 1, 1, 0.5), 6)
	steam.visible = false
	parts["steam"] = steam
	# Microwave.
	var mw := _thing("microwave", ct, Vector3(1.0, 0.92, -0.02), Vector3(0.7, 0.5, 0.6), Vector3(0, 0.2, 0), Vector3(0, -0.92, 0.9))
	Kit.box(mw, Vector3(0.6, 0.34, 0.42), Vector3(0, 0.17, 0), C_WHITE)
	var mwm := Kit.screen_mat(Color("2f2c3e"), 0.05)
	Kit.box(mw, Vector3(0.38, 0.24, 0.02), Vector3(-0.08, 0.17, 0.212), Color.WHITE).material_override = mwm
	parts["microwave_door"] = mwm
	Kit.box(mw, Vector3(0.12, 0.26, 0.02), Vector3(0.22, 0.17, 0.212), C_DARK)
	Kit.box(mw, Vector3(0.08, 0.04, 0.01), Vector3(0.22, 0.25, 0.224), Color("5ad17a"), 0.4, 2.0)
	# Counter clutter.
	Kit.cyl(ct, 0.14, 0.07, Vector3(-0.35, 0.955, 0.02), Color("ffd166"), 10, 0.18)                 # fruit bowl
	Kit.ball(ct, 0.06, Vector3(-0.38, 1.0, 0.02), Color("ff5d73"), 8)
	Kit.ball(ct, 0.06, Vector3(-0.3, 1.0, 0.05), Color("5ad17a"), 8)
	Kit.box(ct, Vector3(0.16, 0.22, 0.12), Vector3(1.36, 1.03, -0.14), C_WOOD)                      # knife block
	_spot("counter_a", ct, Vector3(-1.32, 0.92, 0.08))
	_spot("counter_b", ct, Vector3(0.55, 0.92, 0.14))
	# Kitchen table + chairs.
	var tb_root := _prop(Vector3(4.2, 0, 3.55), 0.0, Vector2(1.4, 0.9), 0.78, "KitchenTable")
	var tb := _thing("table", tb_root, Vector3.ZERO, Vector3(1.4, 0.9, 0.9), Vector3(0, 0.45, 0), Vector3(0, 0, -0.98))
	Kit.box(tb, Vector3(1.4, 0.06, 0.9), Vector3(0, 0.75, 0), C_WOOD_LIGHT)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Kit.box(tb, Vector3(0.07, 0.72, 0.07), Vector3(0.6 * sx, 0.36, 0.36 * sz), C_WOOD)
	Kit.cyl(tb, 0.14, 0.02, Vector3(-0.3, 0.79, 0.0), C_WHITE, 12)
	_spot("kitchen_table", tb, Vector3(-0.3, 0.8, 0.0))
	Kit.cyl(tb, 0.05, 0.11, Vector3(0.05, 0.835, 0.12), Color("4fb3ff"), 8)
	Kit.cyl(tb, 0.06, 0.22, Vector3(0.38, 0.89, -0.1), Color("5ad17a"), 8)                          # vase
	Kit.ball(tb, 0.08, Vector3(0.38, 1.06, -0.1), Color("ff9ecb"), 6)
	var c1 := _chair(self, Vector3(3.2, 0, 3.55), 90.0, Color("ffd166"))
	_chair(self, Vector3(5.2, 0, 3.55), -90.0, Color("ffd166"))
	_block(Rect2(2.95, 3.3, 0.5, 0.5))
	_block(Rect2(4.95, 3.3, 0.5, 0.5))
	Kit.solid(self, Vector3(0.45, 0.9, 0.45), Vector3(3.2, 0.45, 3.55))
	Kit.solid(self, Vector3(0.45, 0.9, 0.45), Vector3(5.2, 0.45, 3.55))
	tb.seat = {"pos": Vector3(0, 0.02, 0.0), "yaw": PI, "lie": false, "root": c1}
	# Decor.
	# Kitchen bin: lid flipped back, open on top.
	var bin_root := _prop(Vector3(6.45, 0, 0.62), 0.0, Vector2(0.46, 0.46), 0.3)
	var bin := _thing("bin", bin_root, Vector3.ZERO, Vector3(0.5, 0.7, 0.5), Vector3(0, 0.35, 0), Vector3(-0.75, 0, 0.35))
	for i in 10:
		var a := TAU * float(i) / 10.0
		var slat := Kit.box(bin, Vector3(0.135, 0.56, 0.02), Vector3(cos(a) * 0.2, 0.28, sin(a) * 0.2), C_METAL)
		slat.rotation.y = -a + PI / 2.0
	Kit.cyl(bin, 0.2, 0.03, Vector3(0, 0.015, 0), C_DARK, 10)
	Kit.torus(bin, 0.205, 0.016, Vector3(0, 0.56, 0), C_DARK, 14, 6)
	var lid := Kit.cyl(bin, 0.21, 0.03, Vector3(0, 0.66, -0.2), C_DARK, 12)
	lid.rotation.x = -1.25
	Kit.box(bin, Vector3(0.14, 0.03, 0.1), Vector3(0, 0.03, 0.24), C_DARK)                           # pedal
	_bin_trigger(Vector3(6.45, 0.42, 0.62), 0.2)
	_plant(Vector3(6.5, 0, 5.0), 1.1)
	var wallshelf := Kit.node(self, Vector3(1.12, 1.45, 4.6))
	Kit.box(wallshelf, Vector3(0.02, 0.02, 0.02), Vector3.ZERO, C_WOOD)


# ---------------------------------------------------------------------------
# Navigation grid
# ---------------------------------------------------------------------------

func _build_nav() -> void:
	var cols := int((X1 - X0) / CELL)
	var rows := int((Z1 - Z0) / CELL)
	nav.region = Rect2i(0, 0, cols, rows)
	nav.cell_size = Vector2(CELL, CELL)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nav.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nav.update()
	var pad := 0.3            # body radius (0.22) plus a little air
	for ix in cols:
		for iz in rows:
			var p := Vector2(X0 + (ix + 0.5) * CELL, Z0 + (iz + 0.5) * CELL)
			var solid := p.x < X0 + pad or p.x > X1 - pad or p.y < Z0 + pad or p.y > Z1 - pad
			if not solid:
				for r in _blocked:
					if (r as Rect2).grow(pad).has_point(p):
						solid = true
						break
			if solid:
				nav.set_point_solid(Vector2i(ix, iz), true)


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(
		clampi(int(floor((p.x - X0) / CELL)), 0, nav.region.size.x - 1),
		clampi(int(floor((p.z - Z0) / CELL)), 0, nav.region.size.y - 1))


func point_of(c: Vector2i) -> Vector3:
	return Vector3(X0 + (c.x + 0.5) * CELL, 0.0, Z0 + (c.y + 0.5) * CELL)


func nearest_free(c: Vector2i) -> Vector2i:
	if not nav.is_point_solid(c):
		return c
	for radius in range(1, 10):
		var best := Vector2i(-1, -1)
		var best_d := 1e9
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var q := c + Vector2i(dx, dz)
				if not nav.region.has_point(q) or nav.is_point_solid(q):
					continue
				var dist := float(dx * dx + dz * dz)
				if dist < best_d:
					best_d = dist
					best = q
		if best.x >= 0:
			return best
	return c


func walkable(p: Vector3) -> bool:
	if p.x < X0 or p.x > X1 or p.z < Z0 or p.z > Z1:
		return false
	return not nav.is_point_solid(cell_of(p))


func _clear_line(a: Vector3, b: Vector3) -> bool:
	## True if a body-wide corridor from a to b is free (not just the centre line).
	var d := b - a
	d.y = 0.0
	var steps := int(ceil(d.length() / (CELL * 0.5)))
	var side := Vector3(-d.z, 0, d.x).normalized() * 0.14 if d.length() > 0.001 else Vector3.ZERO
	for i in range(steps + 1):
		var p := a.lerp(b, float(i) / float(maxi(steps, 1)))
		if not walkable(p) or not walkable(p + side) or not walkable(p - side):
			return false
	return true


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	## Walkable route across the flat, smoothed so the player cuts corners.
	var a := nearest_free(cell_of(from))
	var b := nearest_free(cell_of(to))
	var cells := nav.get_id_path(a, b)
	var pts: Array = []
	for c in cells:
		pts.append(point_of(c))
	if pts.is_empty():
		return PackedVector3Array()
	if walkable(to):
		pts[pts.size() - 1] = Vector3(to.x, 0, to.z)
	var out := PackedVector3Array()
	var anchor := Vector3(from.x, 0, from.z)
	var i := 0
	while i < pts.size():
		var j := pts.size() - 1
		while j > i and not _clear_line(anchor, pts[j]):
			j -= 1
		out.append(pts[j])
		anchor = pts[j]
		i = j + 1
	return out


func room_at(p: Vector3) -> String:
	if p.z < 0.0:
		return "Home office" if p.x < 0.0 else "Bedroom"
	return "Living room" if p.x < 1.0 else "Kitchen"
