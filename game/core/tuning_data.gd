class_name TuningData
extends RefCounted
## Base for JSON-backed tuning objects. Subclasses declare `var name := value`
## defaults (which must mirror the shipped JSON); apply_dict overrides them.


## Applies known keys; warns about unknown keys so typos are caught early.
func apply_dict(d: Dictionary) -> void:
	var known := property_names()
	for key in d.keys():
		if String(key).begins_with("_"):
			continue
		if known.has(key):
			set(key, float(d[key]))
		else:
			push_warning("%s: unknown key '%s'" % [get_script().resource_path.get_file(), key])


func property_names() -> Dictionary:
	var known := {}
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			known[p.name] = true
	return known
