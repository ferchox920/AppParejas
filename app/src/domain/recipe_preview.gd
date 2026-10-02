class_name RecipePreview
extends RefCounted

# Esta receta es una vista previa local. La receta autorizada vendrá del servidor.
static func build(first: Array[String], second: Array[String], catalog: Dictionary) -> Dictionary:
	if QualityCatalog.validate_selection(first, catalog) != "" or QualityCatalog.validate_selection(second, catalog) != "":
		return {}
	var qualities: Dictionary = QualityCatalog.index(catalog)
	var union: Array[String] = first.duplicate()
	for id: String in second:
		if not union.has(id):
			union.append(id)
	union.sort()
	var weights: Dictionary = {}
	var families: Dictionary = {"afe": 0.0, "sos": 0.0, "con": 0.0, "vit": 0.0, "cui": 0.0}
	var canonical: PackedStringArray = []
	for id: String in union:
		var weight: float = (0.5 / first.size() if first.has(id) else 0.0) + (0.5 / second.size() if second.has(id) else 0.0)
		weights[id] = weight
		var family: String = qualities[id]["family_id"]
		families[family] += weight
		canonical.append("%s:%.8f" % [id, weight])
	return {
		"selected_union": union,
		"weights": weights,
		"family_weights": families,
		"catalog_version": catalog["catalog_version"],
		"recipe_version": "preview-1",
		"asset_version": "primitive-1",
		"identity": ("preview-1|primitive-1|%s|%s" % [catalog["catalog_version"], ";".join(canonical)]).sha256_text()
	}
