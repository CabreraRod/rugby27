class_name JsonLoader
extends RefCounted
## Small helper for reading JSON data files with clear error reporting.


static func load_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("JsonLoader: file not found: %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("JsonLoader: %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("JsonLoader: %s root is not an object" % path)
		return {}
	return json.data
