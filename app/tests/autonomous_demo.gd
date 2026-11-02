extends Node

# Recorrido sin cuentas reales ni intervención humana. Sólo se exporta en la
# copia de exploración; tests/ permanece excluido del APK habitual.
var app: Control
var checks: int = 0
var failures: Array[String] = []
var state_path: String
var invitations_path: String

func _ready() -> void:
	var run_id := str(Time.get_ticks_usec())
	state_path = "user://exploration_state_%s.json" % run_id
	invitations_path = "user://exploration_invitations_%s.json" % run_id
	_run.call_deferred()

func _check(value: bool, description: String) -> void:
	checks += 1
	if not value: failures.append(description)
	print("EXPLORACION: %s %s" % ["OK" if value else "FALLO", description])

func _settle() -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while app.first_open.busy or app.screen == "loading":
		if Time.get_ticks_msec() >= deadline:
			_check(false, "Tiempo límite del recorrido")
			break
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _open() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.auto_start = false
	app.first_open.store = FirstOpenStore.new(state_path)
	var service := LocalInvitationService.new()
	service.path = invitations_path
	app.first_open.service = service
	get_tree().root.add_child(app)
	app.first_open.start()
	await _settle()

func _press(control_name: String) -> void:
	var button := app.find_child(control_name, true, false) as Button
	_check(button != null and not button.disabled, "Acción disponible: " + control_name)
	if button != null and not button.disabled: button.pressed.emit()
	await _settle()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var background := image.get_pixel(0, 0)
	var visible_samples := 0
	for y: int in range(0, image.get_height(), maxi(1, image.get_height() / 64)):
		for x: int in range(0, image.get_width(), maxi(1, image.get_width() / 64)):
			var pixel := image.get_pixel(x, y)
			if absf(pixel.r - background.r) + absf(pixel.g - background.g) + absf(pixel.b - background.b) > 0.1:
				visible_samples += 1
	_check(visible_samples > 20, "Captura contiene interfaz visible: " + label)
	image.save_png("user://exploration_%s.png" % label)

func _reopen() -> void:
	get_tree().root.remove_child(app)
	app.queue_free()
	await get_tree().process_frame
	await _open()

func _run() -> void:
	await _open()
	_check(app.screen == "welcome", "Primera apertura aislada")
	await _press("MeetSpace")
	await _press("IntroSkip")
	await _press("ChooseInvite")
	var name_field := app.find_child("DisplayName", true, false) as LineEdit
	if name_field != null: name_field.text = "Exploración demo"
	await _press("DemoAccess")
	_check(app.screen == "invite", "Crear invitación de demostración")
	await _press("InvitationStatus")
	await _reopen()
	_check(app.screen == "waiting" and not app.first_open.state.has_pair(), "Reabrir conserva espera sin confirmar falsamente")
	await _capture("waiting")
	app.first_open.service.online = false
	await _press("RefreshInvitation")
	_check(app.screen == "error" and app.first_open.error == "offline", "Desconexión explícita y recuperable")
	app.first_open.service.online = true
	await _press("RetryOperation")
	_check(app.screen == "waiting", "Reintentar después de recuperar conexión")
	await _press("CancelInvitation")
	_check(app.screen == "connect" and app.first_open.state.invitation.outgoing_id.is_empty(), "Cancelación limpia invitación saliente")
	await _press("ChooseJoin")
	await _press("CreateFixture")
	await _press("UseFixture")
	_check(app.screen == "review" and not app.first_open.state.has_pair(), "Resolver nunca acepta automáticamente")
	await _capture("review")
	await _press("DeclineInvitation")
	_check(not app.first_open.state.has_pair(), "Rechazar no crea vínculo")
	await _press("ChooseJoin")
	await _press("CreateFixture")
	await _press("UseFixture")
	await _press("AcceptInvitation")
	_check(app.screen == "confirmed" and app.first_open.state.pair.get("demo", false), "Aceptación explícita sólo confirma vínculo demo")
	await _capture("confirmed")
	await _press("ContinueQualities")
	_check(app.screen == "selection", "Continuar al selector de demostración")
	app._apply.pressed.emit()
	await _settle()
	_check(app.screen == "garden", "Selección válida muestra jardín de demostración")
	app._set_text_scale(2.0)
	await _reopen()
	_check(app.screen == "garden" and app.text_scale == 2.0, "Jardín y texto al 200% se recuperan desde archivos")
	await _capture("garden_200")
	FirstOpenStore.write_json("user://exploration_report.json", {"checks": checks, "failures": failures, "platform": OS.get_name(), "engine": Engine.get_version_info().string, "demo": true})
	print("EXPLORACION FINAL: %d verificaciones, %d fallos" % [checks, failures.size()])
	# Mantener el jardín abierto para comprobar después el gesto físico del sistema.
