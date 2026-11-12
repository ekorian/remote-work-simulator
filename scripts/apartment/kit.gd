class_name Kit
extends RefCounted
## Kit — low-poly building blocks. Every prop in the game is assembled from
## these primitives; materials and meshes are cached and shared.

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}


static func mat(color: Color, rough: float = 0.85, emit: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), rough, emit, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if color.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


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
