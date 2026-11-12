extends Node
## Prefs — player settings (audio, display), persisted to user://settings.cfg.

signal changed()

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"master": 0.9, "music": 0.55, "sfx": 0.85, "ambience": 0.6,
	"fullscreen": false, "vsync": true, "shake": true, "hints": true,
}

var data: Dictionary = DEFAULTS.duplicate()
var persist := true


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in DEFAULTS:
			data[k] = cf.get_value("settings", k, DEFAULTS[k])
	apply.call_deferred()


func get_v(key: String) -> Variant:
	return data.get(key, DEFAULTS.get(key))


func set_v(key: String, value: Variant) -> void:
	data[key] = value
	apply()
	save()
	changed.emit()


func save() -> void:
	if not persist:
		return
	var cf := ConfigFile.new()
	for k in data:
		cf.set_value("settings", k, data[k])
	cf.save(PATH)


func apply() -> void:
	Sfx.set_volume("Master", float(data.master))
	Sfx.set_volume("Music", float(data.music))
	Sfx.set_volume("SFX", float(data.sfx))
	Sfx.set_volume("Ambience", float(data.ambience))
	if DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(data.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want and not (want == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
		DisplayServer.window_set_mode(want)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(data.vsync) else DisplayServer.VSYNC_DISABLED)
