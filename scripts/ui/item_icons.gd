class_name ItemIcons
extends Node
## ItemIcons — small pictures of the things you carry, rendered once from the
## same models as the real things and kept. Until a picture is ready (or when
## there is no renderer at all) `icon` returns null and the caller shows text.

const SIZE := 112

var _port: SubViewport
var _stage: Node3D
var _cam: Camera3D
var _done: Dictionary = {}       ## key -> Texture2D
var _queue: Array = []
var _working := false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_port = SubViewport.new()
	_port.size = Vector2i(SIZE, SIZE)
	_port.transparent_bg = true
	_port.own_world_3d = true
	_port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_port.msaa_3d = Viewport.MSAA_4X
	add_child(_port)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("eef2ff")
	env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	_port.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 0.9
	_port.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_port.add_child(_cam)
	_stage = Node3D.new()
	_port.add_child(_stage)


func icon(model: String, tint: Color) -> Texture2D:
	var key := "%s|%s" % [model, tint.to_html()]
	if _done.has(key):
		return _done[key]
	if _port == null or model == "":
		return null
	_done[key] = null
	_queue.append([key, model, tint])
	if not _working:
		_work()
	return null


func _work() -> void:
	_working = true
	while not _queue.is_empty():
		var job: Array = _queue.pop_front()
		for c in _stage.get_children():
			c.queue_free()
		var built := FoodKit.build(str(job[1]), _stage, job[2])
		var size: Vector3 = built.size
		(built.root as Node3D).rotation.y = -0.6
		var span := maxf(maxf(size.x, size.z) * 1.25, size.y * 1.15)
		_cam.size = span * 1.12
		_cam.position = Vector3(0, size.y * 0.5 + span * 1.2, span * 1.6)
		_cam.look_at(Vector3(0, size.y * 0.5, 0))
		_port.render_target_update_mode = SubViewport.UPDATE_ONCE
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := _port.get_texture().get_image()
		if img != null and not img.is_empty():
			_done[str(job[0])] = ImageTexture.create_from_image(img)
	_working = false
