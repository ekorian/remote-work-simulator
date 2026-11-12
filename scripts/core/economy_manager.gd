class_name EconomyManager
extends GameSystem
## EconomyManager — cash, the daily salary and its bonuses, shop prices,
## and favours (the social currency colleagues owe you).

signal money_changed(value: int, delta: int, reason: String)
signal favors_changed(value: int)

var money := Cfg.START_MONEY
var favors := 0
var earned := 0              ## total salary paid this week


func setup_run() -> void:
	money = Cfg.START_MONEY
	favors = 0
	earned = 0


func save_state() -> Dictionary:
	return {"money": money, "favors": favors, "earned": earned}


func load_state(d: Dictionary) -> void:
	money = int(d.get("money", Cfg.START_MONEY))
	favors = int(d.get("favors", 0))
	earned = int(d.get("earned", 0))


func add_money(delta: int, reason: String = "") -> void:
	money += delta
	if delta < 0:
		Game.bump("spent", -delta)
	money_changed.emit(money, delta, reason)


func can_afford(cost: int) -> bool:
	return money >= cost


func add_favor(delta: int) -> void:
	favors = maxi(0, favors + delta)
	favors_changed.emit(favors)


func price(base: int) -> int:
	## Shop price on the current difficulty, rounded to $5.
	return int(round(float(base) * float(Game.diff().cost) / 5.0)) * 5


func day_salary(worked_min: int, illusion: float, suspicion: float) -> Dictionary:
	## {total, lines:[[label, amount]]} for the end-of-day payslip.
	var total := Cfg.SALARY_BASE
	var lines: Array = [["Base salary", Cfg.SALARY_BASE]]
	if worked_min == 0:
		total += Cfg.BONUS_ZERO_WORK
		lines.append(["Zero-effort efficiency bonus", Cfg.BONUS_ZERO_WORK])
	if illusion >= 70.0:
		total += Cfg.BONUS_ILLUSION
		lines.append(["Perceived-impact bonus", Cfg.BONUS_ILLUSION])
	if suspicion >= 75.0:
		total -= 60
		lines.append(["Docked: 'attendance concerns'", -60])
	return {"total": total, "lines": lines}


func pay_salary(amount: int) -> void:
	earned += amount
	add_money(amount, "Salary")
