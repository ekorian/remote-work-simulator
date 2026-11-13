class_name UIIcon
extends Control
## Small vector icons drawn in code (no image assets, crisp at any size).

var icon := "dot":
	set(v):
		icon = v
		queue_redraw()
var tint := Color.WHITE:
	set(v):
		tint = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _pts(arr: Array, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(Vector2(p[0], p[1]) * s)
	return out


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := tint
	var w := maxf(1.5, s * 0.1)
	match icon:
		"heart":
			draw_circle(Vector2(0.31, 0.34) * s, 0.21 * s, c)
			draw_circle(Vector2(0.69, 0.34) * s, 0.21 * s, c)
			draw_colored_polygon(_pts([[0.1, 0.42], [0.9, 0.42], [0.5, 0.9]], s), c)
		"bolt":
			draw_colored_polygon(_pts([[0.6, 0.04], [0.2, 0.56], [0.46, 0.56], [0.38, 0.96], [0.8, 0.42], [0.54, 0.42]], s), c)
		"eye":
			draw_colored_polygon(_pts([[0.04, 0.5], [0.3, 0.24], [0.5, 0.18], [0.7, 0.24], [0.96, 0.5], [0.7, 0.76], [0.5, 0.82], [0.3, 0.76]], s), c)
			draw_circle(Vector2(0.5, 0.5) * s, 0.17 * s, Color(0, 0, 0, 0.75))
			draw_circle(Vector2(0.56, 0.44) * s, 0.06 * s, c)
		"spark":
			draw_colored_polygon(_pts([[0.5, 0.02], [0.61, 0.39], [0.98, 0.5], [0.61, 0.61], [0.5, 0.98], [0.39, 0.61], [0.02, 0.5], [0.39, 0.39]], s), c)
		"coin":
			draw_circle(Vector2(0.5, 0.5) * s, 0.44 * s, c)
			draw_circle(Vector2(0.5, 0.5) * s, 0.31 * s, Color(0, 0, 0, 0.22))
			draw_rect(Rect2(Vector2(0.45, 0.28) * s, Vector2(0.1, 0.44) * s), c)
		"clock":
			draw_arc(Vector2(0.5, 0.5) * s, 0.4 * s, 0, TAU, 28, c, w, true)
			draw_line(Vector2(0.5, 0.5) * s, Vector2(0.5, 0.24) * s, c, w, true)
			draw_line(Vector2(0.5, 0.5) * s, Vector2(0.68, 0.58) * s, c, w, true)
		"phone":
			draw_rect(Rect2(Vector2(0.27, 0.05) * s, Vector2(0.46, 0.9) * s), c, false, w)
			draw_rect(Rect2(Vector2(0.42, 0.78) * s, Vector2(0.16, 0.05) * s), c)
		"chat":
			draw_rect(Rect2(Vector2(0.08, 0.14) * s, Vector2(0.84, 0.52) * s), c)
			draw_colored_polygon(_pts([[0.24, 0.6], [0.24, 0.9], [0.5, 0.6]], s), c)
		"task":
			draw_rect(Rect2(Vector2(0.14, 0.1) * s, Vector2(0.72, 0.8) * s), c, false, w)
			draw_polyline(_pts([[0.3, 0.52], [0.44, 0.67], [0.72, 0.35]], s), c, w, true)
		"cal":
			draw_rect(Rect2(Vector2(0.1, 0.18) * s, Vector2(0.8, 0.72) * s), c, false, w)
			draw_rect(Rect2(Vector2(0.1, 0.18) * s, Vector2(0.8, 0.2) * s), c)
			draw_rect(Rect2(Vector2(0.28, 0.52) * s, Vector2(0.16, 0.16) * s), c)
		"mail":
			draw_rect(Rect2(Vector2(0.08, 0.2) * s, Vector2(0.84, 0.6) * s), c, false, w)
			draw_polyline(_pts([[0.08, 0.22], [0.5, 0.56], [0.92, 0.22]], s), c, w, true)
		"gear":
			for i in 8:
				var a := TAU * float(i) / 8.0
				draw_line(Vector2(0.5, 0.5) * s + Vector2.from_angle(a) * 0.26 * s, Vector2(0.5, 0.5) * s + Vector2.from_angle(a) * 0.46 * s, c, w * 1.5)
			draw_arc(Vector2(0.5, 0.5) * s, 0.25 * s, 0, TAU, 24, c, w * 1.4, true)
		"warn":
			draw_colored_polygon(_pts([[0.5, 0.06], [0.96, 0.9], [0.04, 0.9]], s), c)
			draw_rect(Rect2(Vector2(0.46, 0.36) * s, Vector2(0.08, 0.28) * s), Color(0, 0, 0, 0.7))
			draw_circle(Vector2(0.5, 0.76) * s, 0.05 * s, Color(0, 0, 0, 0.7))
		"wifi":
			for i in 3:
				draw_arc(Vector2(0.5, 0.82) * s, (0.22 + 0.2 * float(i)) * s, -PI * 0.78, -PI * 0.22, 16, c, w, true)
			draw_circle(Vector2(0.5, 0.82) * s, 0.07 * s, c)
		"check":
			draw_polyline(_pts([[0.14, 0.54], [0.4, 0.78], [0.86, 0.24]], s), c, w * 1.4, true)
		"cross":
			draw_line(Vector2(0.2, 0.2) * s, Vector2(0.8, 0.8) * s, c, w * 1.4, true)
			draw_line(Vector2(0.8, 0.2) * s, Vector2(0.2, 0.8) * s, c, w * 1.4, true)
		"fast":
			draw_colored_polygon(_pts([[0.06, 0.2], [0.48, 0.5], [0.06, 0.8]], s), c)
			draw_colored_polygon(_pts([[0.5, 0.2], [0.92, 0.5], [0.5, 0.8]], s), c)
		"call":
			draw_arc(Vector2(0.5, 0.5) * s, 0.4 * s, 0, TAU, 28, c, w, true)
			draw_colored_polygon(_pts([[0.36, 0.3], [0.72, 0.5], [0.36, 0.7]], s), c)
		"favor":
			draw_circle(Vector2(0.35, 0.36) * s, 0.16 * s, c)
			draw_circle(Vector2(0.67, 0.36) * s, 0.16 * s, c)
			draw_rect(Rect2(Vector2(0.14, 0.58) * s, Vector2(0.74, 0.28) * s), c)
		"moon":
			draw_circle(Vector2(0.5, 0.5) * s, 0.4 * s, c)
			draw_circle(Vector2(0.64, 0.4) * s, 0.32 * s, Color(0.08, 0.094, 0.1))
		_:
			draw_circle(Vector2(0.5, 0.5) * s, 0.3 * s, c)
