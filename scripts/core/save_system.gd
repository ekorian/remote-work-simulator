extends Node
## SaveSys — save/load of the whole run. The run state is one Dictionary
## (Game.s), stored with Godot's binary Variant format (objects disabled).

signal saved(slot: String)
signal about_to_save()          ## the world writes transient bits (player position) into Game.s

const SLOTS := ["auto", "slot1", "slot2", "slot3"]
const SLOT_NAMES := {"auto": "Autosave", "slot1": "Slot 1", "slot2": "Slot 2", "slot3": "Slot 3"}
const FORMAT := 1

var enabled := true             ## tests switch this off so they never touch real saves
var dir := "user://saves"       ## tests point this at a scratch folder


func _path(slot: String) -> String:
	return "%s/%s.sav" % [dir, slot]


func can_save() -> bool:
	return Game.active and Game.s.get("phase", "over") != "over" and not Corp.in_call()


func autosave() -> void:
	if enabled and can_save():
		save("auto")


func save(slot: String) -> bool:
	if not enabled or not can_save() or not slot in SLOTS:
		return false
	about_to_save.emit()
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(_path(slot), FileAccess.WRITE)
	if f == null:
		push_warning("SaveSys: cannot write %s (%s)" % [_path(slot), error_string(FileAccess.get_open_error())])
		return false
	var data := {
		"format": FORMAT,
		"version": Cfg.VERSION,
		"meta": {
			"name": Game.player_name(), "diff": str(Game.s.diff), "day": int(Game.s.day),
			"t": int(Game.s.t), "phase": str(Game.s.phase), "money": int(Game.s.money),
			"susp": int(Game.s.susp), "stamp": int(Time.get_unix_time_from_system()),
		},
		"state": Game.s,
	}
	f.store_var(data, false)
	f.close()
	saved.emit(slot)
	return true


func _read(slot: String) -> Dictionary:
	if not FileAccess.file_exists(_path(slot)):
		return {}
	var f := FileAccess.open(_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = f.get_var(false)
	f.close()
	if typeof(data) != TYPE_DICTIONARY or int(data.get("format", -1)) != FORMAT:
		return {}
	if typeof(data.get("state")) != TYPE_DICTIONARY or typeof(data.get("meta")) != TYPE_DICTIONARY:
		return {}
	return data


func meta(slot: String) -> Dictionary:
	return _read(slot).get("meta", {})


func list() -> Array:
	## [{slot, name, meta}] for every slot that holds a valid save, newest first.
	var out: Array = []
	for slot in SLOTS:
		var m := meta(slot)
		if not m.is_empty():
			out.append({"slot": slot, "name": SLOT_NAMES[slot], "meta": m})
	out.sort_custom(func(a, b): return int(a.meta.stamp) > int(b.meta.stamp))
	return out


func latest() -> String:
	var l := list()
	return "" if l.is_empty() else str(l[0].slot)


func load_game(slot: String) -> bool:
	var data := _read(slot)
	if data.is_empty():
		return false
	var st: Dictionary = data.state
	for key in ["diff", "day", "t", "phase", "health", "energy", "susp", "ill", "pres", "things", "gadgets", "threads", "tasks", "meetings", "today", "week"]:
		if not st.has(key):
			push_warning("SaveSys: save '%s' is missing '%s'" % [slot, key])
			return false
	Game.s = st
	Game.active = true
	Game.paused = false
	Game._acc = 0.0
	Game.s.call = {}
	Game.s.pres.in_call = false
	Game.set_speed(float(Game.s.act.get("speed", 1.0)) if Game.busy() else 1.0)
	Game._update_presence()
	Bus.state_loaded.emit()
	return true


func delete(slot: String) -> void:
	if FileAccess.file_exists(_path(slot)):
		DirAccess.remove_absolute(_path(slot))


func describe(m: Dictionary) -> String:
	if m.is_empty():
		return "Empty"
	var when := "evening" if str(m.get("phase", "work")) == "evening" else Cfg.fmt_time(float(m.t))
	return "%s - %s, %s %s - $%d - %d%% suspicion" % [
		str(m.name), str(Cfg.diff(str(m.diff)).name), Cfg.DAYS[clampi(int(m.day), 0, 4)], when, int(m.money), int(m.susp),
	]
