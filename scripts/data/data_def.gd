class_name DataDef
extends Resource
## Base class for static, authored content. Every definition has an id and
## can be flattened to a Dictionary, which is what the simulation works with.

@export var id := ""


func to_dict() -> Dictionary:
	var d := {}
	for p in get_property_list():
		var usage := int(p.usage)
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			var v: Variant = get(str(p.name))
			if v is Array or v is Dictionary:
				v = v.duplicate(true)
			d[str(p.name)] = v
	if d.has("display_name"):
		d["name"] = d["display_name"]
	return d
