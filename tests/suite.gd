class_name TestSuite
extends RefCounted
## Minimal test helper: named checks, a failure list, and run setup.

var checks := 0
var fails := 0
var verbose := false
var failures: Array = []
var _section := ""


func section(title: String) -> void:
	_section = title
	print("== ", title)


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		failures.append("%s: %s" % [_section, what])
		print("  FAIL: ", what)
	elif verbose:
		print("  ok: ", what)


func near(a: float, b: float, what: String, eps: float = 0.01) -> void:
	check(absf(a - b) <= eps, "%s (got %.2f, expected %.2f)" % [what, a, b])


func run(difficulty: String = "survivor", seed_v: int = 1, quiet: bool = true) -> void:
	## A fresh run, clock under test control, no tutorial. `quiet` removes
	## everything the director planned, so only what the test triggers happens.
	Game.time.manual = true
	Game.new_run(difficulty, {"name": "Tester"}, false, seed_v)
	if quiet:
		Game.time.timers.clear()
		Game.comms.meetings.clear()
		Game.comms.prompts.clear()


func at_work(minute: int = 600) -> void:
	## Jump the clock to a minute of the current day without simulating.
	Game.time.minute = float(minute)
	Game.presence.update()


func boss() -> String:
	return Game.npcs.boss_id()
