class_name ResultsScreen
extends Dim

signal again()
signal to_menu()

const TEXT := {
	"win": ["YOU SURVIVED THE WEEK", "Five days. Forty paid hours. Management still believes you work here.", "5ad17a"],
	"fired": ["YOU'RE FIRED", "\"We've decided to go in a different direction. The direction is: without you.\"", "ff5d73"],
	"burnout": ["BURNOUT", "You worked. It broke you. The doctor's note this time is real.", "ff8c5a"],
	"worked": ["DISQUALIFIED: YOU DID WORK", "A Professional Unemployed never, ever does the job.", "ff5d73"],
}

var _body: VBoxContainer

func _ready() -> void:
	setup(0.86)
	visible = false
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.shadowed(UI.sb(UI.PANEL, 22, 0, Color.TRANSPARENT, 34, 28), 34, 0.55))
	p.custom_minimum_size = Vector2(900, 0)
	center(p)
	_body = UI.vbox(10)
	p.add_child(_body)

func _stat(label_text: String, value: String, color: Color = UI.TEXT) -> Control:
	var p := UI.panel(UI.PANEL2, 12, 12)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(0)
	var t := UI.title(value, 26, color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var l := UI.label(label_text, 12, UI.DIM, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	p.add_child(v)
	return p

func show_result(res: Dictionary) -> void:
	visible = true
	UI.clear(_body)
	var kind: String = str(res.kind)
	var info: Array = TEXT.get(kind, TEXT["fired"])
	var col := Color(str(info[2]))
	var wk: Dictionary = res.week
	var head := UI.hbox(18)
	_body.add_child(head)
	var hv := UI.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UI.pill("%s  -  %s%s" % [str(Cfg.diff(str(res.diff)).name).to_upper(), Cfg.DAYS[clampi(int(res.day), 0, 4)], "" if bool(res.won) else " %s" % Cfg.fmt_time(fposmod(float(res.time), 1440.0))], col, 12, true))
	hv.add_child(UI.title(str(info[0]), 46, col))
	var sub: String = str(info[1])
	if kind == "worked" and str(res.action) != "":
		sub += "\nYour mistake: \"%s\"." % str(res.action)
	elif not bool(res.won) and str(res.reason) != "":
		sub += "\nThe final straw: %s." % str(res.reason)
	hv.add_child(UI.wrap(sub, 16, Color("e6dcff")))
	head.add_child(hv)
	var gp := UI.panel(Color(col, 0.16), 20, 14, 3, col)
	gp.custom_minimum_size = Vector2(130, 130)
	var gv := UI.vbox(0)
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	var gl := UI.title(str(res.grade), 74, col)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(gl)
	var gs := UI.label("GRADE", 12, UI.DIM, true)
	gs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(gs)
	gp.add_child(gv)
	head.add_child(gp)
	var worked := int(wk.worked_min)
	if str(res.get("rating", "")) != "":
		var rp := UI.panel(Color(UI.ACCENT, 0.16), 12, 10, 2, UI.ACCENT)
		var rl := UI.title("* %s *" % str(res.rating), 20, UI.ACCENT)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rp.add_child(rl)
		_body.add_child(rp)
	var eff := float(res.get("auto_eff", -1.0))
	var g1 := UI.hbox(8)
	g1.add_child(_stat("WORK AVOIDANCE", "%d%%" % int(floor(float(res.get("avoidance", 0.0)))), UI.GREEN if worked == 0 else UI.ACCENT))
	g1.add_child(_stat("SALARY EARNED", "$%d" % int(res.get("salary", wk.salary)), UI.ACCENT))
	g1.add_child(_stat("ACTUAL WORK TIME", Cfg.fmt_dur(float(worked)), UI.GREEN if worked == 0 else UI.RED))
	g1.add_child(_stat("SUCCESSFUL DECEPTIONS", str(int(res.get("deceptions", 0))), UI.PURPLE))
	_body.add_child(g1)
	var g2 := UI.hbox(8)
	g2.add_child(_stat("FINAL SUSPICION", "%d%%" % int(round(float(res.susp))), UI.ORANGE))
	g2.add_child(_stat("FINAL HEALTH", "%d%%" % int(round(float(res.health))), UI.RED))
	g2.add_child(_stat("AUTOMATION EFFICIENCY", "n/a" if eff < 0.0 else "%d%%" % int(round(eff)), UI.TEAL))
	g2.add_child(_stat("PAID HOURS SLACKED", Cfg.fmt_dur(float(wk.get("slack_min", 0))), UI.TEAL))
	_body.add_child(g2)
	var extra := "Score %d  -  %d meetings avoided  -  %d stories told, %d caught  -  %d tickets faked, %d delegated\n%d of %d colleagues befriended  -  %d favours called in  -  told on %d times" % [
		int(res.score), int(wk.meetings_avoided), int(res.get("claims", 0)), int(res.get("caught", 0)), int(wk.tasks_faked), int(wk.tasks_delegated),
		int(res.get("friends", 0)), int(res.get("colleagues", 0)), int(res.get("favours_called", 0)), int(res.get("snitched", 0))]
	var el := UI.label(extra, 12, UI.DIM, true)
	el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(el)
	if bool(res.won):
		var line := "Not one minute of real work." if worked == 0 else "You survived, but you WORKED %d minutes to do it. We don't talk about that." % worked
		var slack := int(wk.get("slack_min", 0))
		if worked == 0 and slack < Cfg.SLACK_S:
			line += " Slack %s on company time for an %s." % [Cfg.fmt_dur(float(Cfg.SLACK_A if slack < Cfg.SLACK_A else Cfg.SLACK_S)), "A" if slack < Cfg.SLACK_A else "S"]
		elif worked == 0:
			line += " And over a third of your paid hours on the sofa. Perfection."
		var review := str(Game.flags.get("review", ""))
		if review == "exceeds":
			line += " Your review said EXCEEDS EXPECTATIONS."
		elif review == "pip":
			line += " You are on a Performance Improvement Plan, which you will also ignore."
		_body.add_child(UI.wrap(line, 15, UI.GREEN if worked == 0 else UI.ACCENT))
	# Day strip
	var days := UI.hbox(8)
	for rep in res.reports:
		var dp := UI.panel(Color(0, 0, 0, 0.25), 10, 10)
		dp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var dv := UI.vbox(1)
		dv.add_child(UI.title(Cfg.DAYS_SHORT[int(rep.day)], 15, UI.ACCENT))
		dv.add_child(UI.wrap(str(rep.title), 12, UI.TEXT))
		dv.add_child(UI.label("$%d  -  %d%% susp" % [int(rep.salary), int(round(float(rep.get("susp_end", rep.susp))))], 11, UI.DIM))
		dp.add_child(dv)
		days.add_child(dp)
	if not res.reports.is_empty():
		_body.add_child(days)
	_body.add_child(UI.gap(1, 4))
	var foot := UI.hbox(10)
	var b1 := UI.button("Main Menu", func(): to_menu.emit(), "ghost", 20)
	b1.custom_minimum_size = Vector2(220, 52)
	foot.add_child(b1)
	foot.add_child(UI.spacer())
	var b2 := UI.button("Try another week", func(): again.emit(), "primary", 20)
	b2.custom_minimum_size = Vector2(280, 52)
	foot.add_child(b2)
	_body.add_child(foot)
	Bus.sfx.emit("win" if bool(res.won) else "fired")
