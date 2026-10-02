extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var catalog: Dictionary = QualityCatalog.load_catalog()
	var known: Dictionary = QualityCatalog.index(catalog)
	_check(known.size() == 20, "Catálogo de 20 IDs únicos")
	_check(catalog["families"].size() == 5, "Cinco familias")
	var a: Array[String] = ["afe_carino", "sos_respeto", "con_escucha"]
	var b: Array[String] = ["sos_respeto", "sos_paciencia", "vit_juego", "afe_calidez", "cui_gratitud"]
	var recipe: Dictionary = RecipePreview.build(a, b, catalog)
	_check(recipe["selected_union"].size() == 7, "La unión conserva diferencias")
	_check(is_equal_approx(recipe["weights"]["sos_respeto"], 4.0 / 15.0), "Aporte coincidente con cantidades 3 y 5")
	_check(recipe["identity"] == RecipePreview.build(b, a, catalog)["identity"], "Simetría entre integrantes")
	a.reverse()
	b.reverse()
	_check(recipe["identity"] == RecipePreview.build(a, b, catalog)["identity"], "Orden de selección irrelevante")
	var invalid: Array[String] = ["afe_carino", "afe_carino", "sos_respeto"]
	_check(RecipePreview.build(invalid, b, catalog).is_empty(), "Rechazo de duplicados")
	invalid = ["afe_carino", "sos_respeto", "desconocida"]
	_check(RecipePreview.build(invalid, b, catalog).is_empty(), "Rechazo de IDs desconocidos")
	invalid = ["afe_carino", "sos_respeto"]
	_check(RecipePreview.build(invalid, b, catalog).is_empty(), "Rechazo de menos de 3")
	invalid = ["afe_carino", "afe_ternura", "afe_calidez", "afe_amabilidad", "sos_respeto", "sos_paciencia"]
	_check(RecipePreview.build(invalid, b, catalog).is_empty(), "Rechazo de más de 5")
	var ids: Array[String] = []
	for id: String in known:
		ids.append(id)
	var random := RandomNumberGenerator.new()
	random.seed = 20261002
	for iteration: int in range(100):
		var first: Array[String] = _sample(ids, random.randi_range(3, 5), random)
		var second: Array[String] = _sample(ids, random.randi_range(3, 5), random)
		var sample: Dictionary = RecipePreview.build(first, second, catalog)
		var total: float = 0.0
		for weight: float in sample["weights"].values():
			total += weight
		_check(is_equal_approx(total, 1.0), "Los pesos suman 1 en caso %d" % iteration)
		_check(sample["identity"] == RecipePreview.build(second, first, catalog)["identity"], "Simetría en caso %d" % iteration)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var app: Control = scene.instantiate()
	app.auto_start = false
	app.first_open.store = FirstOpenStore.new("user://legacy_test_state.json")
	root.add_child(app)
	app.show_screen("welcome")
	await process_frame
	_check(app.screen == "welcome", "Inicio en bienvenida")
	app.show_screen("garden")
	await process_frame
	_check(is_instance_valid(app.garden), "Jardín instanciado")
	app.set_stage("sprout")
	_check(app.garden.stage == "sprout", "Etapa brote")
	app.garden.turn(1000)
	_check(is_equal_approx(app.garden._yaw, 55.0), "Rotación acotada")
	app.garden.zoom(-1000)
	_check(is_equal_approx(app.garden._distance, 2.3), "Zoom acotado")
	app.garden.reset_camera()
	_check(is_equal_approx(app.garden._yaw, 0.0), "Restablecer cámara")
	app.show_screen("selection")
	await process_frame
	_check(not app._apply.disabled, "Selección válida habilita la vista previa")
	var checkbox: CheckBox = app.find_child("afe_carino", true, false)
	_check(checkbox != null, "Ficha de cariño presente")
	checkbox.button_pressed = false
	_check(app.selection.size() == 3, "Desmarcar actualiza la selección")
	checkbox.button_pressed = true
	_check(app.selection.size() == 4, "Volver a marcar conserva un ID único")
	var tenderness: CheckBox = app.find_child("afe_ternura", true, false)
	tenderness.button_pressed = true
	_check(app.selection.size() == 5, "Quinta cualidad permitida")
	var kindness: CheckBox = app.find_child("afe_amabilidad", true, false)
	kindness.button_pressed = true
	_check(app.selection.size() == 5 and not kindness.button_pressed, "Sexta cualidad rechazada sin desincronizar el control")
	for child: Node in app._body.get_children():
		if child is HFlowContainer:
			for tab: Button in child.get_children():
				_check(tab.size.x > 60 and tab.size.y < 120, "Etiqueta de familia legible")
	checkbox.button_pressed = false
	tenderness.button_pressed = false
	app.active_family = "sos"
	app.show_screen("selection")
	await process_frame
	var respect: CheckBox = app.find_child("sos_respeto", true, false)
	respect.button_pressed = false
	_check(app.selection.size() == 2 and app._apply.disabled, "Menos de tres deshabilita la vista previa")
	respect.button_pressed = true
	app._set_text_scale(1.5)
	await process_frame
	_check(is_equal_approx(app.text_scale, 1.5), "Texto aumentado sin error de escena")
	app.show_screen("garden")
	await process_frame
	_check(app.stage == "sprout" and app.garden.stage == "sprout", "El brote se conserva al regresar")
	app.queue_free()
	await process_frame
	print("RESULTADO: %d verificaciones, %d fallos" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _sample(ids: Array[String], count: int, random: RandomNumberGenerator) -> Array[String]:
	var pool: Array[String] = ids.duplicate()
	var result: Array[String] = []
	for i: int in range(count):
		var chosen: int = random.randi_range(0, pool.size() - 1)
		result.append(pool[chosen])
		pool.remove_at(chosen)
	return result
