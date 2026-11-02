class_name AccountPreferencesStore
extends FirstOpenStore

func _init() -> void:
	super("user://account_preferences.json")

func load_state() -> Dictionary:
	var state := FirstOpenState.new()
	if not FileAccess.file_exists(path): return {"ok": true, "state": state}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 4096: return {"ok": false, "error": "storage"}
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("version") != 1: return {"ok": false, "error": "storage"}
	if data.get("introduction") not in ["new", "completed", "skipped"]: return {"ok": false, "error": "storage"}
	if not data.get("preferences") is Dictionary: return {"ok": false, "error": "storage"}
	var scale: Variant = data.preferences.get("text_scale")
	if not scale is float and not scale is int: return {"ok": false, "error": "storage"}
	if not data.preferences.get("reduced_motion") is bool: return {"ok": false, "error": "storage"}
	state.introduction = data.introduction
	state.preferences = {"text_scale": clampf(float(scale), 1.0, 2.0), "reduced_motion": data.preferences.reduced_motion}
	return {"ok": true, "state": state}

func save_state(state: FirstOpenState) -> bool:
	# Sesión, tokens, referencias y contenido del vínculo permanecen en memoria.
	return write_json(path, {"version": 1, "introduction": state.introduction, "preferences": state.preferences})
