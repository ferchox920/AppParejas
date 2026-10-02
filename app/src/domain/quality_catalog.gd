class_name QualityCatalog
extends RefCounted

const PATH := "res://data/catalogo_v1.json"

static func load_catalog() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_error("No se pudo cargar el catálogo de cualidades.")
		return {}
	var catalog: Dictionary = parsed
	return catalog

static func index(catalog: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for quality: Dictionary in catalog.get("qualities", []):
		result[quality["id"]] = quality
	return result

static func validate_selection(ids: Array[String], catalog: Dictionary) -> String:
	if ids.size() < 3 or ids.size() > 5:
		return "Elegí entre 3 y 5 cualidades."
	var known: Dictionary = index(catalog)
	var unique: Dictionary = {}
	for id: String in ids:
		if not known.has(id):
			return "La selección contiene una cualidad desconocida."
		if unique.has(id):
			return "Cada cualidad se elige una sola vez."
		unique[id] = true
	return ""
