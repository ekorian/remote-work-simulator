extends Node
## Loads every script in the project so parse errors surface in one pass.

func _ready() -> void:
	var bad := 0
	var n := 0
	for path in _scan("res://scripts") + _scan("res://tests"):
		n += 1
		var s: Variant = load(path)
		if s == null or not (s as GDScript).can_instantiate():
			bad += 1
			print("BAD: ", path)
	print("scripts: %d, failed: %d" % [n, bad])
	get_tree().quit(1 if bad > 0 else 0)


func _scan(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_scan(dir + "/" + sub))
	return out
