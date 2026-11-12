class_name Dim
extends Control
## Full-screen dimmer that swallows clicks behind a modal.
var bg: ColorRect

func setup(alpha: float = 0.6) -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	bg = ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.11, alpha)
	UI.full(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _notification(what: int) -> void:
	# Every modal fades in instead of popping.
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.16)


func center(child: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	UI.full(cc)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(child)
	add_child(cc)
	return cc


# ---------------------------------------------------------------------------
# Incoming call / meeting starting
# ---------------------------------------------------------------------------
