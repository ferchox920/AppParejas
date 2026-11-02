class_name BackendConfig
extends RefCounted

const PATH := "res://data/connection.local.json"

static func load_settings() -> Dictionary:
	if not FileAccess.file_exists(PATH): return {"mode": "demo"}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not value is Dictionary: return {"mode": "invalid"}
	if value.get("mode") == "demo": return {"mode": "demo"}
	var url := str(value.get("url", "")).trim_suffix("/")
	var key := str(value.get("public_key", ""))
	if value.get("mode") != "supabase" or not url.begins_with("https://") or key.is_empty():
		return {"mode": "invalid"}
	# No aceptar claves administrativas aunque alguien copie la equivocada.
	if key.begins_with("sb_secret_"): return {"mode": "invalid"}
	var parts := key.split(".")
	if parts.size() == 3:
		var claims: Variant = JSON.parse_string(Marshalls.base64_to_utf8(parts[1].replace("-", "+").replace("_", "/")))
		if not claims is Dictionary or claims.get("role") != "anon": return {"mode": "invalid"}
	elif not key.begins_with("sb_publishable_"): return {"mode": "invalid"}
	return {"mode": "supabase", "url": url, "public_key": key}
