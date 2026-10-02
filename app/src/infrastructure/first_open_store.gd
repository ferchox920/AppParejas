class_name FirstOpenStore
extends RefCounted

var path: String

func _init(file_path: String = "user://first_open.json") -> void:
	path = file_path

func load_state() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "state": FirstOpenState.new()}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 32768:
		return {"ok": false, "error": "storage"}
	var value: Variant = JSON.parse_string(file.get_as_text())
	if not value is Dictionary:
		return {"ok": false, "error": "storage"}
	var state := FirstOpenState.parse(value)
	if state == null:
		return {"ok": false, "error": "storage"}
	return {"ok": true, "state": state}

func save_state(state: FirstOpenState) -> bool:
	return write_json(path, state.serialize())

static func write_json(file_path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(file_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	return DirAccess.rename_absolute(file_path + ".tmp", file_path) == OK
