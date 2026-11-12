class_name SaveManager
extends Node
## SaveManager — save slots. Every system serialises its own state through
## Game.save_state(); the result is written with Godot's binary Variant format
## (objects disabled), so types survive the round trip. Saves carry a version
## and anything else is rejected rather than half-loaded.

signal saved(slot: String)
signal about_to_save()          ## the world writes the player's position into Game.player_pos

const SLOTS := ["auto", "slot1", "slot2", "slot3"]
const SLOT_NAMES := {"auto": "Autosave", "slot1": "Slot 1", "slot2": "Slot 2", "slot3": "Slot 3"}
const FORMAT := 2

var enabled := true             ## tests switch this off so they never touch real saves
var dir := "user://saves"       ## tests point this at a scratch folder


func _path(slot: String) -> String:
	return "%s/%s.sav" % [dir, slot]


func can_save() -> bool:
	return Game.time.running() and not Game.comms.in_call()


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
			"name": Game.player_name(), "diff": Game.difficulty_id, "day": Game.time.day,
			"t": int(Game.time.minute), "phase": Game.time.phase, "money": Game.economy.money,
			"susp": int(Game.stats.get_value("susp")), "stamp": int(Time.get_unix_time_from_system()),
		},
		"state": Game.save_state(),
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
	return Game.load_state(data.state)


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
