class_name DayReport
extends Dim

signal done()

var _body: VBoxContainer

func _ready() -> void:
	setup(0.8)
	visible = false
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.shadowed(UI.sb(Color("fbf6ea"), 14, 0, Color.TRANSPARENT, 34, 28), 34, 0.55))
	p.custom_minimum_size = Vector2(760, 0)
	center(p)
	_body = UI.vbox(8)
	p.add_child(_body)

func _row(label_text: String, value: String, color: Color = UI.INK, note: String = "") -> Control:
	var h := UI.hbox(10)
	var l := UI.label(label_text, 16, Color("4a4270"))
	l.custom_minimum_size = Vector2(290, 0)
	h.add_child(l)
	var v := UI.title(value, 19, color)
	v.custom_minimum_size = Vector2(110, 0)
	h.add_child(v)
	if note != "":
		var n := UI.wrap(note, 12, Color("8a86a8"))
		h.add_child(n)
	h.modulate.a = 0.0
	return h

func show_report(rep: Dictionary) -> void:
	visible = true
	UI.clear(_body)
	var ink := UI.INK
	var head := UI.hbox(10)
	var hv := UI.vbox(0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UI.label("SYNERCORP  -  DAILY PERFORMANCE SUMMARY", 12, Color("8a86a8"), true))
	hv.add_child(UI.title("%s" % Cfg.DAYS[int(rep.day)], 40, ink))
	head.add_child(hv)
	var stamp := UI.panel(Color.TRANSPARENT, 8, 10, 3, Color("d6455b"))
	var st := UI.title(str(rep.title).to_upper(), 15, Color("d6455b"))
	st.custom_minimum_size = Vector2(190, 0)
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.add_child(st)
	stamp.rotation_degrees = -4.0
	head.add_child(stamp)
	_body.add_child(head)
	var sep := ColorRect.new()
	sep.color = Color("d9d2c0")
	sep.custom_minimum_size = Vector2(0, 2)
	_body.add_child(sep)
	var worked := int(rep.worked_min)
	var rows: Array = [
		_row("Hours employed", "%.1f h" % float(rep.hours_employed), ink),
		_row("Minutes actually worked", "%d min" % worked, Color("1f8f4a") if worked == 0 else Color("d6455b"), "Flawless." if worked == 0 else "Every one of them hurt."),
		_row("Time spent pretending to work", Cfg.fmt_dur(float(rep.pretend_min)), ink, "Sitting at the desk, or in meetings."),
		_row("Paid time spent slacking", Cfg.fmt_dur(float(rep.get("slack_min", 0))), Color("1f8f4a") if int(rep.get("slack_min", 0)) >= 90 else ink, "Sofa, TV, console, naps and snacks on company time."),
		_row("Excuses used", str(int(rep.excuses)), ink),
		_row("Meetings avoided", "%d of %d" % [int(rep.meetings_avoided), int(rep.meetings_avoided) + int(rep.meetings_attended) + int(rep.meetings_missed)], ink, "%d missed without a story" % int(rep.meetings_missed) if int(rep.meetings_missed) > 0 else ""),
		_row("Suspicion generated", "+%d" % int(round(float(rep.susp_gained))), Color("d6455b") if float(rep.susp_gained) >= 30.0 else ink, "and -%d talked back down" % int(round(float(rep.susp_lost)))),
		_row("Health remaining", "%d%%" % int(round(float(rep.health))), Color("d6455b") if float(rep.health) < 40.0 else ink),
		_row("Automation efficiency", "n/a" if float(rep.auto_eff) < 0.0 else "%d%%" % int(round(float(rep.auto_eff))), ink, "no gadgets ran" if float(rep.auto_eff) < 0.0 else "%d gadget cycles" % int(rep.auto_runs)),
	]
	for r in rows:
		_body.add_child(r)
	var sep2 := ColorRect.new()
	sep2.color = Color("d9d2c0")
	sep2.custom_minimum_size = Vector2(0, 2)
	_body.add_child(sep2)
	var pay := UI.vbox(2)
	for line in rep.salary_lines:
		var ph := UI.hbox(10)
		var pl := UI.label(str(line[0]), 14, Color("4a4270"))
		pl.custom_minimum_size = Vector2(290, 0)
		ph.add_child(pl)
		ph.add_child(UI.label("%s$%d" % ["+" if int(line[1]) >= 0 else "-", absi(int(line[1]))], 15, Color("1f8f4a") if int(line[1]) >= 0 else Color("d6455b"), true))
		pay.add_child(ph)
	_body.add_child(pay)
	var total := _row("Salary earned today", "$%d" % int(rep.salary), Color("1f8f4a"))
	_body.add_child(total)
	rows.append(total)
	var verdict := UI.wrap(str(rep.verdict), 15, Color("4a4270"))
	_body.add_child(verdict)
	_body.add_child(UI.gap(1, 4))
	var last: bool = int(rep.day) >= 4
	var b := UI.button("See how the week went" if last else "Clock out", func():
		visible = false
		done.emit()
	, "primary", 22)
	b.custom_minimum_size = Vector2(0, 54)
	_body.add_child(b)
	var tw := create_tween()
	for r in rows:
		tw.tween_property(r, "modulate:a", 1.0, 0.11)
		tw.tween_callback(func(): Bus.sfx.emit("tick"))
	Bus.sfx.emit("payday")


# ---------------------------------------------------------------------------
# End-of-run results
# ---------------------------------------------------------------------------
