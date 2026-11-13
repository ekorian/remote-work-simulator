class_name Kit
extends RefCounted
## Kit — low-poly building blocks. Every prop in the game is assembled from
## these primitives; materials and meshes are cached and shared.
##
## The look of the whole game is set here: flat, matt, single-colour surfaces
## in a drab palette (see `tone`), and a few chunky procedural textures for
## the big floors.

## Every colour that reaches a surface is pulled towards this grey-green.
const DRAB := Color(0.40, 0.44, 0.40)
const TONE_SAT := 0.58
const TONE_VALUE := 0.84
const TONE_DRAB := 0.14

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}
static var _textures: Dictionary = {}


static func tone(c: Color, keep: float = 0.0) -> Color:
	## The grade: less colour, less light, a little of the room's grey in
	## everything. `keep` (0..1) holds some of the original back, for things
	## that glow.
	var g := Color.from_hsv(c.h, c.s * TONE_SAT, pow(c.v, 1.12) * TONE_VALUE, c.a)
	g = g.lerp(Color(DRAB, c.a), TONE_DRAB)
	return g.lerp(c, clampf(keep, 0.0, 1.0))


static func mat(color: Color, rough: float = 0.85, emit: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), rough, emit, metal]
	if _mats.has(key):
		return _mats[key]
	var shown := tone(color, 0.5 if emit > 0.0 else 0.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = shown
	m.roughness = maxf(rough, 0.7)
	m.metallic = metal * 0.4
	m.metallic_specular = 0.12
	if color.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = shown
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


static func texture(kind: String) -> ImageTexture:
	## Small grey-scale textures, drawn here rather than imported, and shown
	## unfiltered so every texel is a visible square: "wood_x" and "wood_z"
	## (boards running along that axis), "tiles", "carpet", "slabs", "grit".
	if _textures.has(kind):
		return _textures[kind]
	var img: Image
	match kind:
		"wood_x":
			img = _wood_image()
		"wood_z":
			img = _wood_image()
			img.rotate_90(CLOCKWISE)
		"tiles":
			img = _tile_image(2, 0.80, 2)
		"slabs":
			img = _tile_image(2, 0.95, 1)
		"carpet":
			img = _noise_image(0.86, 11)
		_:
			img = _noise_image(0.90, 23)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_textures[kind] = t
	return t


static func _wood_image() -> Image:
	## Floorboards running along U, seams at constant V. Tiles in both directions.
	var n := 128
	var boards := 6
	var bw := n / boards
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for b in boards:
		var shade := rng.randf_range(0.70, 0.98)
		var joint := rng.randi_range(0, n - 1)
		var phase := rng.randf_range(0.0, TAU)
		var grain := PackedFloat32Array()
		for i in bw:
			grain.append(rng.randf_range(-0.13, 0.10))
		for v in bw:
			for u in n:
				# The grain runs along the board and wanders a texel or two across it.
				var wander := int(round(1.6 * sin(TAU * 2.0 * u / n + phase)))
				var g := shade + grain[posmod(v + wander, bw)] + rng.randf_range(-0.025, 0.025)
				if v == 0:
					g *= 0.52                      # the gap between two boards
				elif posmod(u - joint, n) == 0:
					g *= 0.6                       # where one board ends and the next begins
				g = clampf(g, 0.0, 1.0)
				img.set_pixel(u, b * bw + v, Color(g, g, g))
	for v in range(boards * bw, n):
		for u in n:
			img.set_pixel(u, v, img.get_pixel(u, v - boards * bw))
	return img


static func _tile_image(per_side: int, dark: float, grout: int) -> Image:
	## A chequer of `per_side` x `per_side` tiles with a grout line round each.
	var n := 64
	var tw := n / per_side
	var rng := RandomNumberGenerator.new()
	rng.seed = 31 + per_side + grout
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var odd := (x / tw + y / tw) % 2 == 1
			var g := (dark if odd else 1.0) + rng.randf_range(-0.02, 0.02)
			if x % tw < grout or y % tw < grout:
				g = dark * 0.72
			g = clampf(g, 0.0, 1.0)
			img.set_pixel(x, y, Color(g, g, g))
	return img


static func _noise_image(low: float, seed_v: int) -> Image:
	var n := 64
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var g := rng.randf_range(low, 1.0)
			img.set_pixel(x, y, Color(g, g, g))
	return img


static func surface(kind: String, tint: Color, tile_m: float = 1.8) -> StandardMaterial3D:
	## A textured, toned material laid out in world space: one copy of the
	## texture every `tile_m` metres whatever the size of the mesh.
	var key := "tex|%s|%s|%.2f" % [kind, tint.to_html(), tile_m]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tone(tint)
	m.albedo_texture = texture(kind)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / maxf(0.05, tile_m)
	m.roughness = 0.95
	m.metallic_specular = 0.08
	_mats[key] = m
	return m


static func slab(parent: Node3D, size: Vector3, pos: Vector3, kind: String, tint: Color, tile_m: float = 1.8) -> MeshInstance3D:
	## A box with a textured surface: floors, pavements, lawns.
	return _inst(_box_mesh(size), surface(kind, tint, tile_m), pos, parent)


static func screen_mat(color: Color, energy: float = 1.6) -> StandardMaterial3D:
	## A private (uncached) emissive material whose colour can be animated.
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.4
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func _faceted(src: PrimitiveMesh) -> ArrayMesh:
	## Flat-shaded copy of a primitive: one normal per triangle.
	var arr := src.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	for i in range(0, idx.size(), 3):
		var a := idx[i]
		var b := idx[i + 1]
		var c := idx[i + 2]
		var fn := (norms[a] + norms[b] + norms[c]).normalized()
		v.append(verts[a])
		v.append(verts[b])
		v.append(verts[c])
		n.append(fn)
		n.append(fn)
		n.append(fn)
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = v
	out[Mesh.ARRAY_NORMAL] = n
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return m


static func _box_mesh(size: Vector3) -> Mesh:
	var key := "b%.3f,%.3f,%.3f" % [size.x, size.y, size.z]
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


static func _cyl_mesh(r_bottom: float, r_top: float, h: float, segs: int) -> Mesh:
	var key := "c%.3f,%.3f,%.3f,%d" % [r_bottom, r_top, h, segs]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.bottom_radius = r_bottom
		m.top_radius = r_top
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		_meshes[key] = _faceted(m) if segs <= 10 else m
	return _meshes[key]


static func _ball_mesh(r: float, segs: int, hemi: bool) -> Mesh:
	var key := "s%.3f,%d,%s" % [r, segs, hemi]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r if hemi else r * 2.0
		m.is_hemisphere = hemi
		m.radial_segments = segs
		m.rings = maxi(3, int(segs / 2.0))
		_meshes[key] = _faceted(m) if segs <= 12 else m
	return _meshes[key]


static func _inst(mesh: Mesh, material: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	if parent != null:
		parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rough: float = 0.85, emit: float = 0.0) -> MeshInstance3D:
	return _inst(_box_mesh(size), mat(color, rough, emit), pos, parent)


static func cyl(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, segs: int = 10, top_radius: float = -1.0, emit: float = 0.0) -> MeshInstance3D:
	return _inst(_cyl_mesh(radius, radius if top_radius < 0.0 else top_radius, height, segs), mat(color, 0.85, emit), pos, parent)


static func ball(parent: Node3D, radius: float, pos: Vector3, color: Color, segs: int = 10, emit: float = 0.0) -> MeshInstance3D:
	return _inst(_ball_mesh(radius, segs, false), mat(color, 0.85, emit), pos, parent)


static func dome(parent: Node3D, radius: float, pos: Vector3, color: Color, segs: int = 10) -> MeshInstance3D:
	return _inst(_ball_mesh(radius, segs, true), mat(color), pos, parent)


static func torus(parent: Node3D, ring: float, tube: float, pos: Vector3, color: Color, segs: int = 14, tube_segs: int = 8) -> MeshInstance3D:
	## A ring lying flat (axis up). `ring` is the radius to the centre of the tube.
	var key := "t%.3f,%.3f,%d,%d" % [ring, tube, segs, tube_segs]
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.inner_radius = maxf(0.001, ring - tube)
		m.outer_radius = ring + tube
		m.rings = segs
		m.ring_segments = tube_segs
		_meshes[key] = m
	return _inst(_meshes[key], mat(color), pos, parent)


static func wedge(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	## A triangular slab lying flat: `size.x` wide at the back (-Z), coming to
	## a point at +Z, `size.z` long and `size.y` thick. Pizza, cake, toasties.
	var key := "w%.3f,%.3f,%.3f" % [size.x, size.y, size.z]
	if not _meshes.has(key):
		var m := PrismMesh.new()
		m.size = Vector3(size.x, size.z, size.y)
		_meshes[key] = m
	var mi := _inst(_meshes[key], mat(color), pos, parent)
	mi.rotation.x = PI / 2.0
	return mi


static func capsule(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color, segs: int = 10) -> MeshInstance3D:
	## A pill standing upright; `length` includes the round ends.
	var key := "p%.3f,%.3f,%d" % [radius, length, segs]
	if not _meshes.has(key):
		var m := CapsuleMesh.new()
		m.radius = radius
		m.height = maxf(length, radius * 2.0)
		m.radial_segments = segs
		m.rings = 4
		_meshes[key] = m
	return _inst(_meshes[key], mat(color), pos, parent)


static func cone(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, segs: int = 10) -> MeshInstance3D:
	## Point up. Rotate it for an ice-cream cone.
	return _inst(_cyl_mesh(radius, 0.001, height, segs), mat(color), pos, parent)


static func node(parent: Node3D, pos: Vector3 = Vector3.ZERO, node_name: String = "") -> Node3D:
	var n := Node3D.new()
	n.position = pos
	if node_name != "":
		n.name = node_name
	if parent != null:
		parent.add_child(n)
	return n


static func solid(parent: Node3D, size: Vector3, pos: Vector3, layer: int = 1) -> StaticBody3D:
	## An invisible collision box.
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	body.add_child(shape)
	parent.add_child(body)
	return body


static func lamp(parent: Node3D, pos: Vector3, color: Color, energy: float, light_range: float, shadows: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadows
	parent.add_child(l)
	return l


static func meshes_in(n: Node, out: Array = []) -> Array:
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		meshes_in(c, out)
	return out
