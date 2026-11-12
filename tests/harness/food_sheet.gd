extends Node3D
## Dev-only: renders every FoodKit model on one sheet.
##   xvfb-run -a .tools/godot --path . --rendering-driver vulkan res://tests/harness/food_sheet.tscn -- --out=/tmp/food.png [--only=a,b] [--cols=8]

const TINTS := {
	"donut": Color("ff7eb6"), "choc_bar": Color("7a3df0"), "candy_bar": Color("ff5d73"), "lollipop": Color("ff5d73"), "gummies": Color("5ad17a"),
	"cupcake": Color("ff9ecb"), "cake_slice": Color("ff9ecb"), "pop_tart": Color("ff7eb6"), "cone": Color("ff9ecb"), "ice_tub": Color("9ad0ff"),
	"popsicle": Color("ff8c5a"), "pudding": Color("7a4a2a"), "chips": Color("ffb000"), "cereal": Color("4fb3ff"), "noodles": Color("ff5d73"),
	"soda_can": Color("e63946"), "energy_can": Color("3ddc84"), "soda_cup": Color("e63946"), "milkshake": Color("ffb3d1"), "choc_milk": Color("7a4a2a"),
	"trash_wrapper": Color("7a3df0"), "trash_can": Color("e63946"), "trash_cup": Color("e63946"), "trash_bag": Color("ffb000"), "stress_ball": Color("5ad1c8"),
}


func _ready() -> void:
	var out := "/tmp/food_sheet.png"
	var only: Array = []
	var cols := 8
	var eaten := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(","))
		elif a.begins_with("--cols="):
			cols = int(a.trim_prefix("--cols="))
		elif a.begins_with("--eaten="):
			eaten = float(a.trim_prefix("--eaten="))
	var ids: Array = (FoodKit.MODELS + FoodKit.TRASH + FoodKit.TOYS) if only.is_empty() else only
	var rows := int(ceil(float(ids.size()) / float(cols)))
	var step := 0.46
	var row_step := 0.62
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("6f66b0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e6eeff")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 0.85
	add_child(sun)
	Kit.box(self, Vector3(cols * step + 2.0, 0.02, rows * row_step + 2.0), Vector3(0, -0.01, 0), Color("8a80c8"))
	for i in ids.size():
		var id: String = ids[i]
		var cx := (float(i % cols) - float(cols - 1) / 2.0) * step
		var cz := (float(int(i / float(cols))) - float(rows - 1) / 2.0) * row_step
		var holder := Kit.node(self, Vector3(cx, 0, cz))
		holder.rotation.y = -0.5
		var built := FoodKit.build(id, holder, TINTS.get(id, Color.WHITE))
		var size: Vector3 = built.size
		var s := minf(0.3 / maxf(size.x, size.z), 0.3 / size.y)
		holder.scale = Vector3.ONE * minf(s, 2.6)
		if eaten > 0.0:
			var pieces: Array = built.pieces
			for k in int(round(pieces.size() * eaten)):
				(pieces[pieces.size() - 1 - k] as Node3D).visible = false
			if built.body != null and pieces.is_empty():
				(built.body as Node3D).scale = Vector3.ONE * (1.0 - 0.55 * eaten)
		var label := Label3D.new()
		label.text = id
		label.font_size = 26
		label.pixel_size = 0.0011
		label.modulate = Color("ffffff")
		label.outline_size = 0
		label.position = Vector3(cx, 0.002, cz + 0.2)
		label.rotation.x = -PI / 2.0
		add_child(label)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(rows * row_step * 0.82, cols * step * 0.6)
	add_child(cam)
	cam.position = Vector3(0, 6.0, 5.2)
	cam.look_at(Vector3(0, 0.05, 0.02))
	cam.current = true
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("sheet: ", out, " (", ids.size(), " models)")
	get_tree().quit()
