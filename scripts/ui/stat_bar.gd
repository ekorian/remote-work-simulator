class_name StatBar
extends Control
## Smoothly animated bar with optional threshold ticks.
var value := 0.0
var shown := 0.0
var max_value := 100.0
var color := Color.WHITE
var ticks: Array = []
var pulse := false
var _t := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(40, 12)

func _process(delta: float) -> void:
	_t += delta
	if not is_equal_approx(shown, value) or pulse:
		shown = lerpf(shown, value, minf(1.0, delta * 9.0))
		if absf(shown - value) < 0.05:
			shown = value
		queue_redraw()

func _draw() -> void:
	var r := size.y / 2.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.38)
	bg.set_corner_radius_all(int(r))
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	var f := clampf(shown / max_value, 0.0, 1.0)
	if f > 0.005:
		var fill := StyleBoxFlat.new()
		var c := color
		if pulse:
			c = c.lerp(Color.WHITE, 0.25 + 0.25 * sin(_t * 9.0))
		fill.bg_color = c
		fill.set_corner_radius_all(int(r))
		draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(maxf(size.y, size.x * f), size.y)))
	for tk in ticks:
		var x := size.x * float(tk) / max_value
		draw_line(Vector2(x, 1), Vector2(x, size.y - 1), Color(1, 1, 1, 0.55), 1.5)
