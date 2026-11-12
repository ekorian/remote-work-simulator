extends Node
## Cfg — static tuning tables and helpers. No state lives here.

const VERSION := "0.1.0"

# --- Clock -----------------------------------------------------------------
const DAY_START := 539          # 08:59
const WORK_START := 540         # 09:00
const WORK_END := 1020          # 17:00
const MIN_PER_SEC := 1.25       # game minutes per real second at 1x (workday = 6.4 real minutes)
const DAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
const DAYS_SHORT := ["MON", "TUE", "WED", "THU", "FRI"]

# --- Presence ---------------------------------------------------------------
const IDLE_LIMIT := 6           # minutes away from the keyboard before "Away"
const UNCOVERED_ALERT := 45     # minutes of unexplained absence before the boss asks

# --- Passive per-minute rates (before difficulty multipliers) ---------------
const SUSP_ABSENT := 0.13       # away/offline with no cover story
const SUSP_LOW_ILL := 0.05      # illusion below 25
const SUSP_RELIEF_ILL := 0.02   # illusion above 60 (doubled above 85)
const SUSP_FLOOR := 12.0       # looking busy never earns more trust than this
const ILL_DECAY := 0.075       # away from the keyboard
const ILL_DECAY_DESK := 0.035  # visibly at the desk
const DESK_DRAIN := 0.05       # health per minute spent staring at SynerOS
const BEAT_HP := 2.0           # health per meeting question you sit through
const WINDOW_SCALE := 1.25     # global multiplier on reaction windows
const EN_DECAY := 0.02
const MOVE_EN_PER_M := 0.11     # energy per metre walked

# --- Economy ----------------------------------------------------------------
const START_MONEY := 120
const SALARY_BASE := 240
const BONUS_ZERO_WORK := 80
const BONUS_ILLUSION := 40

# --- Grades: paid hours spent slacking over the week (minutes) ---------------
const SLACK_S := 840           # 14 of your 40 paid hours
const SLACK_A := 480           # one full paid day

# --- Difficulty -------------------------------------------------------------
# susp        multiplier on every suspicion gain
# work_hp     health lost per legitimate work action
# lethal      any legitimate work action ends the run
# recover     multiplier on health/energy restoration
# window      multiplier on every reaction window / response deadline
# gadget_fail multiplier on gadget failure chances
# event_rate  multiplier on how often colleagues / filler events fire
# boss_check  multiplier on how often the boss checks on you
# cost        multiplier on shop prices
# cred        flat bonus/penalty to excuse and bluff chances
# stress      multiplier on meeting fatigue and desk "soul drain"
const DIFF_ORDER := ["intern", "survivor", "senior", "unemployed"]
const DIFFS := {
	"intern": {
		"name": "Intern", "tag": "RELAXED", "color": Color("5ad17a"),
		"susp": 0.6, "work_hp": 2.0, "lethal": false, "recover": 1.4, "window": 1.6,
		"gadget_fail": 0.6, "event_rate": 0.8, "boss_check": 0.7, "cost": 0.85, "cred": 10, "stress": 0.5,
		"score": 1.0,
		"desc": "Nobody expects anything from you. Low suspicion, generous recovery, a forgiving boss and long reaction windows. Work stings a little: 2 HP per action.",
	},
	"survivor": {
		"name": "Corporate Survivor", "tag": "STANDARD", "color": Color("4fb3ff"),
		"susp": 1.0, "work_hp": 8.0, "lethal": false, "recover": 1.0, "window": 1.0,
		"gadget_fail": 1.0, "event_rate": 1.0, "boss_check": 1.0, "cost": 1.0, "cred": 0, "stress": 1.0,
		"score": 1.6,
		"desc": "The intended experience. Normal suspicion, regular interruptions, moderate automation costs. Work hurts: 8 HP per action.",
	},
	"senior": {
		"name": "Senior Bullshitter", "tag": "HARD", "color": Color("ffb347"),
		"susp": 1.7, "work_hp": 20.0, "lethal": false, "recover": 0.85, "window": 0.8,
		"gadget_fail": 1.5, "event_rate": 1.25, "boss_check": 1.5, "cost": 1.15, "cred": -8, "stress": 1.4,
		"score": 2.6,
		"desc": "Suspicion x1.7. Frequent manager checks. Gadgets break when you need them most. Work is agony: 20 HP per action.",
	},
	"unemployed": {
		"name": "Professional Unemployed", "tag": "EXTREME", "color": Color("ff5d73"),
		"susp": 1.5, "work_hp": 999.0, "lethal": true, "recover": 0.85, "window": 0.8,
		"gadget_fail": 1.3, "event_rate": 1.2, "boss_check": 1.4, "cost": 1.1, "cred": -5, "stress": 1.3,
		"score": 4.0,
		"desc": "ANY legitimate work action ends the run instantly. Survive the whole week on avoidance, delegation, deception and automation alone.",
	},
}

# --- Presence display -------------------------------------------------------
const PRESENCE := {
	"online": {"label": "Available", "color": Color("5ad17a")},
	"busy": {"label": "Focusing", "color": Color("ff5d73")},
	"meeting": {"label": "In a meeting", "color": Color("ff5d73")},
	"lunch": {"label": "At lunch", "color": Color("ffb347")},
	"updating": {"label": "Updating...", "color": Color("b48cff")},
	"away": {"label": "Away", "color": Color("ffd166")},
	"offline": {"label": "Offline", "color": Color("8a86a8")},
}


# --- Input -------------------------------------------------------------------
const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"interact": [KEY_F, KEY_SPACE, KEY_ENTER],
	"cam_left": [KEY_Q],
	"cam_right": [KEY_E],
	"phone": [KEY_TAB],
	"pause": [KEY_ESCAPE],
}


func _init() -> void:
	# Input actions are defined in code so the project file stays minimal.
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


static func fmt_time(t: float) -> String:
	var m := int(floor(t))
	return "%02d:%02d" % [int(m / 60.0), m % 60]


static func fmt_dur(mins: float) -> String:
	var m := int(round(mins))
	if m < 60:
		return "%d min" % m
	if m % 60 == 0:
		return "%dh" % int(m / 60.0)
	return "%dh %02dm" % [int(m / 60.0), m % 60]


static func diff(id: String) -> Dictionary:
	return DIFFS.get(id, DIFFS["survivor"])
