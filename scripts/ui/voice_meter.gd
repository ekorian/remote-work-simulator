class_name VoiceMeter
extends Control
## A row of bars that dances while someone is talking. It follows a clock,
## not the audio, so it reads the same with the sound off.

var color := Color.WHITE
var active := false
var wild := 0.0            ## 0 = a normal line, 1 = a voice that should not sound like that
var _t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(64, 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	var n := 11
	var w := size.x / float(n)
	for i in n:
		var h := 0.1
		if active:
			var a := 0.5 + 0.5 * sin(_t * (7.0 + 1.7 * float(i)) + float(i) * 1.3)
			var b := 0.5 + 0.5 * sin(_t * 12.0 + float(i) * 2.1)
			h = 0.18 + 0.82 * a * b
			if wild > 0.0:
				# Bad lines clip, drop out and spike.
				h = clampf(h + wild * 0.7 * sin(_t * 37.0 + float(i) * 5.0), 0.0, 1.0)
				if sin(_t * 3.1 + float(i) * 0.9) > 0.86:
					h = 0.04
		var bh := maxf(2.0, h * size.y)
		draw_rect(Rect2(float(i) * w + 1.0, (size.y - bh) * 0.5, maxf(1.0, w - 2.0), bh), Color(color, 0.95 if active else 0.3))
