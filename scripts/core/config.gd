class_name Cfg
extends RefCounted
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
const DIFF_ORDER := ["intern", "survivor", "senior", "unemployed"]   ## definitions: resources/balancing

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
	"interact": [KEY_E, KEY_F],
	"throw": [KEY_Q],
	"stow": [KEY_R],
	"sprint": [KEY_SHIFT],
	"phone": [KEY_TAB],
	"pause": [KEY_ESCAPE],
}


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
	Db.load_all()
	return Db.difficulties.get(id, Db.difficulties.get("survivor", {}))
