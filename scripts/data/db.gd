class_name Db
extends RefCounted
## Db — the static content database. Loads every DataDef under
## res://resources once and exposes it as dictionaries keyed by id.
## Content is authored as Resources; nothing here is mutable game state.

const ROOT := "res://resources"
const KINDS := {
	"npcs": "npcs", "claims": "deception", "gadgets": "gadgets", "combos": "gadgets/combos",
	"events": "events", "dialogues": "dialogue", "tasks": "tasks", "difficulties": "balancing", "texts": "text",
}

static var npcs: Dictionary = {}
static var claims: Dictionary = {}
static var gadgets: Dictionary = {}
static var combos: Dictionary = {}
static var events: Dictionary = {}
static var dialogues: Dictionary = {}
static var tasks: Dictionary = {}
static var difficulties: Dictionary = {}
static var texts: Dictionary = {}
static var errors: Array = []
static var _loaded := false


static func load_all(force: bool = false) -> void:
	if _loaded and not force:
		return
	_loaded = true
	errors = []
	npcs = _load("npcs")
	claims = _load("claims")
	gadgets = _load("gadgets")
	combos = _load("combos")
	events = _load("events")
	dialogues = _load("dialogues")
	tasks = _load("tasks")
	difficulties = _load("difficulties")
	texts = _load("texts")


static func _load(kind: String) -> Dictionary:
	var out := {}
	var dir := "%s/%s" % [ROOT, KINDS[kind]]
	var names := ResourceLoader.list_directory(dir)
	if names.is_empty():
		errors.append("No resources found in %s" % dir)
	for file in names:
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var res: Resource = load("%s/%s" % [dir, file])
		var def := res as DataDef
		if def == null or def.id == "":
			errors.append("Not a valid DataDef: %s/%s" % [dir, file])
			continue
		if out.has(def.id):
			errors.append("Duplicate id '%s' in %s" % [def.id, dir])
		out[def.id] = def.to_dict()
	return out


static func lines(key: String) -> Array:
	## Flavour lines for a key, from any text bank.
	for bank in texts.values():
		if bank.lines.has(key):
			return bank.lines[key]
	return []


static func gadget_order() -> Array:
	## Gadget ids in shop order: by unlock day, then price.
	var ids: Array = gadgets.keys()
	ids.sort_custom(func(a, b):
		var da: Dictionary = gadgets[a]
		var db: Dictionary = gadgets[b]
		if int(da.unlock_day) != int(db.unlock_day):
			return int(da.unlock_day) < int(db.unlock_day)
		return int(da.levels[0].price) < int(db.levels[0].price))
	return ids
