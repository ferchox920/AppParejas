extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var directory: String = ProjectSettings.globalize_path("res://../.artifacts/init/captures")
	DirAccess.make_dir_recursive_absolute(directory)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var app: Control = scene.instantiate()
	app.auto_start = false
	app.first_open.store = FirstOpenStore.new("user://capture_preview_state.json")
	root.add_child(app)
	await _save(app, "welcome", "seed", 390, directory + "/01_bienvenida.png")
	await _save(app, "garden", "seed", 390, directory + "/02_semilla.png")
	await _save(app, "garden", "sprout", 390, directory + "/03_brote.png")
	await _save(app, "selection", "seed", 390, directory + "/04_cualidades.png")
	app._set_text_scale(1.5)
	await _save(app, "selection", "seed", 360, directory + "/05_texto_grande_360.png")
	await _save(app, "garden", "sprout", 430, directory + "/06_jardin_430.png")
	print("CAPTURAS: seis vistas renderizadas por Godot")
	quit()

func _save(app: Control, screen: String, stage: String, width: int, path: String) -> void:
	root.size = Vector2i(width, 844)
	root.content_scale_size = Vector2i(width, 844)
	app.stage = stage
	app.show_screen(screen)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("No se pudo guardar la captura: " + path)
		quit(1)
