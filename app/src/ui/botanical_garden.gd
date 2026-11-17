extends RefCounted

const SOIL_HEIGHT := 0.23
static var _matte: StandardMaterial3D

static func build_terrain(parent: Node3D) -> void:
	var grain := FastNoiseLite.new()
	grain.seed = 1820
	grain.frequency = 1.0
	var profile := PackedVector2Array([
		Vector2(0.64, 0.015), Vector2(0.69, 0.025), Vector2(0.74, 0.08),
		Vector2(0.78, 0.19), Vector2(0.78, 0.22), Vector2(0.765, 0.24),
		Vector2(0.73, 0.24), Vector2(0.715, 0.21)
	])
	_surface(parent, 64, profile.size() - 1, func(u: float, v: float) -> Vector3:
		var p := profile[roundi(v * (profile.size() - 1))]
		return Vector3(cos(u * TAU) * p.x, p.y, sin(u * TAU) * p.x),
	func(u: float, v: float) -> Color:
		var shade := Color("a76c52").lerp(Color("e2ae88"), smoothstep(0.13, 0.80, v))
		return shade.darkened(0.035 * (1.0 + sin(u * TAU * 17.0)))
	)
	_surface(parent, 64, 18, func(u: float, v: float) -> Vector3:
		var radial := Vector2.from_angle(u * TAU) * v
		var height := grain.get_noise_2dv(radial * 16.0) * smoothstep(0.05, 0.26, v)
		return Vector3(radial.x * 0.73, SOIL_HEIGHT - v * 0.012 + height * 0.009, radial.y * 0.73),
	func(u: float, v: float) -> Color:
		var radial := Vector2.from_angle(u * TAU) * v
		var flecks := grain.get_noise_2dv(radial * 42.0)
		var warmth := smoothstep(0.12, 0.58, v) * 0.72 + flecks * 0.36
		return Color("604128").lerp(Color("a77854"), clampf(warmth, 0.0, 1.0)),
		true
	)

static func build_plant(parent: Node3D, recipe: Dictionary, stage: String) -> void:
	var families: Dictionary = recipe.get("family_weights", {})
	var affection: float = families.get("afe", 0.0)
	var support: float = families.get("sos", 0.0)
	var connection: float = families.get("con", 0.0)
	var vitality: float = families.get("vit", 0.0)
	if stage == "seed":
		var ids: Array = recipe.get("selected_union", [])
		var coat := Color("9a5837").lerp(Color("bb7750"), affection)
		var width := lerpf(0.235, 0.285, support)
		_surface(parent, 64, 32, func(u: float, v: float) -> Vector3:
			var angle := (u - 0.25) * TAU
			var silhouette := pow(maxf(sin(PI * v), 0.0001), 0.72) * lerpf(1.22, 0.70, v)
			var ridge := pow(maxf(sin(angle), 0.0), 80.0) * 0.025
			return Vector3(
				(v - 0.38) * 0.31 + cos(angle) * width * silhouette,
				SOIL_HEIGHT - 0.045 + v * 0.82,
				sin(angle) * (0.19 + ridge) * silhouette
			),
		func(u: float, v: float) -> Color:
			var angle := (u - 0.25) * TAU
			var seam := pow(maxf(sin(angle), 0.0), 255.0) * sin(PI * v)
			var fiber := 0.5 + 0.5 * sin(angle * 17.0 + v * 8.0) * cos(angle * 9.0 - v * 13.0)
			var tone := coat.darkened(0.22 * (1.0 - v)).lightened(0.12 * fiber)
			for i: int in ids.size():
				var column := float(i % 3)
				var row := floorf(float(i) / 3.0)
				var spot := Vector2(0.42 + column * 0.08, 0.30 + row * 0.15 + column * 0.03)
				var fleck := 1.0 - smoothstep(0.004, 0.023, Vector2(u, v).distance_to(spot))
				tone = tone.lerp(Color("efc78f"), fleck * (0.58 + 0.3 * vitality))
			return tone.lerp(Color("e3b174"), seam * 0.85)
		)
		return

	_surface(parent, 20, 22, func(u: float, v: float) -> Vector3:
		var radius := lerpf(0.042, 0.018, v) * (1.0 + support * 0.22)
		return _stem(v) + Vector3(cos(u * TAU) * radius, 0.0, sin(u * TAU) * radius),
	func(u: float, v: float) -> Color:
		return Color("3d6142").lerp(Color("9db361"), v * 0.66 + (0.5 + 0.5 * cos(u * TAU)) * 0.19)
	)
	_leaf(parent, -1.0, 0.67, affection, connection, vitality)
	_leaf(parent, 1.0, 0.93, affection, connection, vitality)

static func _stem(t: float) -> Vector3:
	return Vector3(sin(t * 2.45 - 0.38) * 0.18 + 0.065, SOIL_HEIGHT - 0.012 + t * 0.69, -t * t * 0.065)

static func _leaf(parent: Node3D, side: float, stem_t: float, affection: float, connection: float, vitality: float) -> void:
	var base := _stem(stem_t)
	var reach := 0.50 + 0.10 * vitality + (0.08 if side < 0.0 else 0.0)
	var green := Color("558259").lerp(Color("99ab60"), affection * 0.65 + (0.25 if side > 0.0 else 0.0))
	_surface(parent, 24, 24, func(u: float, v: float) -> Vector3:
		var cross_section := v * 2.0 - 1.0
		var half_width := pow(maxf(sin(PI * u), 0.0001), 0.81) * (0.135 + 0.057 * connection)
		var curl := half_width * absf(cross_section) * (0.27 + 0.32 * connection)
		return base + Vector3(
			side * (reach * u - cross_section * half_width * 0.32),
			u * (0.28 if side < 0.0 else 0.37) + sin(PI * u) * 0.10 + cross_section * half_width * 0.76,
			u * (0.10 if side < 0.0 else -0.025) + cross_section * half_width * 0.64 - curl
		),
	func(u: float, v: float) -> Color:
		var cross_section := absf(2.0 * v - 1.0)
		var midrib := 1.0 - smoothstep(0.008, 0.12, cross_section)
		var veins := pow(0.5 + 0.5 * sin((u - 0.17 * cross_section) * TAU * 6.0), 12.0)
		var edge := smoothstep(0.70, 1.0, cross_section)
		var tone := green.darkened(v * 0.20).lightened(u * 0.14 + edge * 0.11)
		return tone.lerp(Color("b7c881"), (midrib * 0.53 + veins * cross_section * 0.32) * sin(PI * u)),
		side < 0.0
	)

static func _surface(parent: Node3D, columns: int, rows: int, position: Callable, tint: Callable, flip: bool = false) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in range(rows + 1):
		for column: int in range(columns + 1):
			var u := float(column) / columns
			var v := float(row) / rows
			surface.set_color(tint.call(u, v))
			surface.add_vertex(position.call(u, v))
	for row: int in rows:
		for column: int in columns:
			var a := row * (columns + 1) + column
			var b := a + 1
			var c := a + columns + 1
			var d := c + 1
			for index: int in ([a, c, b, b, c, d] if flip else [a, b, c, b, d, c]):
				surface.add_index(index)
	surface.generate_normals()
	if _matte == null:
		_matte = StandardMaterial3D.new()
		_matte.vertex_color_use_as_albedo = true
		_matte.cull_mode = BaseMaterial3D.CULL_DISABLED
		_matte.roughness = 0.88
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = _matte
	parent.add_child(instance)
