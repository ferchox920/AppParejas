extends SceneTree

# Cliente manual de escritorio para completar un correo ya solicitado.
# No envía otro correo ni sustituye la verificación real de Supabase.
func _initialize() -> void:
	_open.call_deferred()

func _open() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not "@" in args[0]:
		push_error("Indicar correo de prueba y nombre; no pasar enlaces ni credenciales.")
		quit(1)
		return
	var config := BackendConfig.load_settings()
	if config.mode != "supabase":
		push_error("Falta configuración publicable del proyecto de desarrollo.")
		quit(1)
		return
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.auto_start = false
	var service := SupabaseInvitationService.new()
	service.base_url = config.url
	service.public_key = config.public_key
	service._pending_email = args[0]
	service._pending_name = args[1]
	service._pending_consent = true
	app.first_open.service = service
	app.first_open.store = AccountPreferencesStore.new()
	app.first_open.store.path = "user://desktop_connection_preferences.json"
	app.first_open.state.introduction = "skipped"
	app.first_open.state.invitation.action = "join"
	root.add_child(app)
	app.first_open.navigate("verify")
	root.title = "AppParejas · segunda cuenta de prueba"
	app.first_open.changed.connect(func() -> void:
		print("CLIENTE REAL: pantalla=%s error=%s" % [app.first_open.screen, app.first_open.error])
		if app.first_open.screen in ["join", "review", "confirmed"]:
			_capture.call_deferred(app.first_open.screen)
	)
	# OTP proporcionado por el titular; sólo en memoria del proceso de prueba.
	var code := OS.get_environment("APPPAREJAS_TEST_OTP")
	OS.unset_environment("APPPAREJAS_TEST_OTP")
	if not code.is_empty(): app.first_open.verify_access_code(code)

func _capture(screen: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://../.artifacts/backend/desktop_%s.png" % screen)
