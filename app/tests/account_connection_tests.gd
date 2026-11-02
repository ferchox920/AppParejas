extends SceneTree

var checks: int = 0
var failures: Array[String] = []

class RecordingService extends SupabaseInvitationService:
	var responses: Array[Dictionary] = []
	var sent: Array[Dictionary] = []
	func _send(path: String, body: Dictionary, authenticated: bool) -> Dictionary:
		sent.append({"path": path, "body": body.duplicate(true), "authenticated": authenticated})
		await get_tree().process_frame
		return responses.pop_front() if not responses.is_empty() else {"ok": false, "error": "offline"}

class DelayedLogoutService extends RecordingService:
	signal release_logout
	func _send(path: String, body: Dictionary, authenticated: bool) -> Dictionary:
		if path.begins_with("/auth/v1/logout"):
			await release_logout
			return {"ok": true, "data": {}}
		return await super._send(path, body, authenticated)

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func invoke(service: InvitationService, operation: String, payload: Dictionary) -> Dictionary:
	service.request.call_deferred(operation, payload, checks + 1)
	var response: Array = await service.completed
	return response[1]

func _run() -> void:
	var store := AccountPreferencesStore.new()
	store.path = "user://account_store_test_%d.json" % Time.get_ticks_usec()
	var state := FirstOpenState.new()
	state.introduction = "completed"
	state.session = {"id": "account", "name": "Sol", "demo": false, "access_token": "never-write"}
	state.pair = {"id": "pair", "status": "confirmed", "demo": false}
	state.invitation.pending_reference = "private-invitation"
	state.selection = ["afe_carino", "sos_respeto", "con_escucha"]
	check(store.save_state(state), "Preferencias reales se guardan")
	var contents := FileAccess.get_file_as_string(store.path)
	check(not "never-write" in contents and not "private-invitation" in contents and not "afe_carino" in contents, "No persistir credenciales, invitaciones ni selecciones")
	var loaded := store.load_state()
	check(loaded.ok and loaded.state.session.is_empty() and loaded.state.pair.is_empty(), "Reapertura no inventa sesión ni vínculo")
	check(loaded.state.introduction == "completed", "Preferencias conservan introducción")
	var service := RecordingService.new()
	service.base_url = "https://development.example.test"
	service.public_key = "sb_publishable_test"
	root.add_child(service)
	var result := await invoke(service, "bootstrap", {})
	check(result.ok and service.sent.is_empty(), "Sin sesión no consultar contenido compartido")
	result = await invoke(service, "send_code", {"name": "Sol", "email": "test@example.test", "consent": false})
	check(result.error == "consent" and service.sent.is_empty(), "No enviar correo sin consentimiento")
	service.responses.append({"ok": true, "data": {}})
	result = await invoke(service, "send_code", {"name": "Sol", "email": "TEST@example.test", "consent": true})
	check(result.ok and service.sent[-1].path == "/auth/v1/otp", "Solicitud OTP usa API Auth")
	check(service.sent[-1].body.email == "test@example.test", "Correo normalizado")
	service.responses.append({"ok": true, "data": {"access_token": "test-access", "refresh_token": "test-refresh", "expires_in": 3600, "user": {"id": "account"}}})
	service.responses.append({"ok": true, "data": {"ok": true}})
	result = await invoke(service, "verify_code", {"code": "123456"})
	check(result.ok and result.session.demo == false and not result.session.has("access_token"), "Sesión pública no contiene tokens")
	check(service.sent[-2].body.type == "email" and service.sent[-1].authenticated, "Verificación seguida de perfil autenticado")
	check(service.verification_payload("00123456").get("token") == "00123456", "OTP conserva ceros iniciales")
	check(service.verification_payload("-123456").is_empty(), "OTP rechaza signos")
	check(service.verification_payload(service.base_url + "/auth/v1/verify?token=hash&type=signup").is_empty(), "Acceso solicita un código, no enlaces")
	service.responses.append({"ok": false, "error": "offline"})
	result = await invoke(service, "create", {"user_id": "spoofed"})
	var create_body: Dictionary = service.sent[-1].body.duplicate(true)
	service.responses.append({"ok": true, "data": {"ok": true, "invitation": {"id": "invitation", "pin": create_body.p_token, "link": create_body.p_token}}})
	result = await invoke(service, "create", {"user_id": "spoofed"})
	check(result.ok and service.sent[-1].body == create_body, "Respuesta perdida conserva token y operación")
	check(not create_body.has("user_id") and create_body.p_token.length() == 32, "Actor procede de JWT y código tiene 128 bits")
	service.responses.append({"ok": true, "data": {"ok": true, "pair": {"id": "pair", "status": "confirmed", "demo": false}}})
	result = await invoke(service, "accept", {"reference": create_body.p_token, "invitation_id": "forged", "user_id": "forged"})
	check(result.ok and service.sent[-1].body.p_token == create_body.p_token and not service.sent[-1].body.has("user_id"), "Aceptar envía secreto y operación sin confiar en actor del cliente")
	var before := service.sent.size()
	result = await invoke(service, "simulate_accept", {})
	check(not result.ok and service.sent.size() == before, "Servicio real no permite simulación")
	service.responses.append({"ok": false, "error": "offline"})
	result = await invoke(service, "logout", {})
	check(result.ok and service._access_token.is_empty() and service._session.is_empty(), "Cerrar sesión borra credenciales aun sin red")
	service.queue_free()
	await process_frame
	await _real_ui_tests()
	await _recovery_regressions()
	print("CUENTAS: %d verificaciones, %d fallos" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _real_ui_tests() -> void:
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.auto_start = false
	app.first_open.service = RecordingService.new()
	app.first_open.store = AccountPreferencesStore.new()
	app.first_open.store.path = "user://ui_account_%d.json" % Time.get_ticks_usec()
	root.add_child(app)
	app.first_open.invitation_view = {"id": "invitation", "pin": "a".repeat(32), "link": "a".repeat(32), "inviter_name": "Sol"}
	for width: int in [360, 390]:
		root.size = Vector2i(width, 844)
		root.content_scale_size = Vector2i(width, 844)
		for scale: float in [1.0, 1.5, 2.0]:
			app._set_text_scale(scale)
			for screen: String in ["access", "verify", "invite", "join", "review", "waiting", "confirmed"]:
				app.show_screen(screen)
				await process_frame
				await process_frame
				var view: Control = app.find_child("FirstOpenView", true, false)
				check(view.size.x <= width - 47, "Cuenta adaptable %s %d %.1f" % [screen, width, scale])
				if screen == "access":
					check(app.find_child("AccountEmail", true, false) != null and app.find_child("SendAccessCode", true, false).disabled, "Correo y consentimiento explícito")
				if screen == "verify":
					var field: LineEdit = app.find_child("AccessCode", true, false)
					check(field.max_length == 10 and field.virtual_keyboard_type == LineEdit.KEYBOARD_TYPE_NUMBER, "Acceso por OTP usa campo numérico")
				if screen == "waiting": check(app.find_child("SimulateAcceptance", true, false) == null, "No mostrar simulación en cuenta real")
				if screen == "confirmed": check(app.find_child("ContinueQualities", true, false) == null, "No fingir recorrido posterior aún no implementado")
	app.first_open.state.pair = {"id": "real-pair", "status": "confirmed", "demo": false}
	app.show_screen("access")
	app.find_child("DisplayName", true, false).text = "Prueba"
	app.find_child("DisplayName", true, false).text_changed.emit("Prueba")
	app.find_child("AccountEmail", true, false).text = "test@example.test"
	app.find_child("AccountEmail", true, false).text_changed.emit("test@example.test")
	app.find_child("AccountConsent", true, false).button_pressed = true
	app._set_text_scale(1.5)
	await process_frame
	check(app.find_child("DisplayName", true, false).text == "Prueba" and app.find_child("AccountEmail", true, false).text == "test@example.test", "Cambiar texto aumentado conserva borrador del formulario en memoria")
	check(app.find_child("AccountConsent", true, false).button_pressed and not app.find_child("SendAccessCode", true, false).disabled, "Consentimiento explícito conserva su estado al reconstruir el formulario")
	app.first_open._fail("email", "access")
	app.first_open.navigate("access")
	check(app.find_child("AccountEmail", true, false).text == "test@example.test", "Corregir un error no obliga a volver a escribir todo el formulario")
	var parsed := FirstOpenState.parse({"version": 1, "introduction": "completed", "session": {}, "pair": {}, "invitation": {"action": "", "outgoing_id": "", "pending_reference": ""}, "selection": [], "preferences": {"text_scale": 2.0, "reduced_motion": true}})
	check(parsed != null and parsed.preferences.text_scale == 2.0, "Preferencia al 200% se conserva al reabrir demostración")
	app.show_screen("confirmed")
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	check(app.screen == "confirmed", "Volver desde vínculo real no conduce a la demostración")
	app.show_screen("connect")
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	check(app.screen == "confirmed", "Volver desde conexión recupera vínculo real sin jardín ficticio")
	app.first_open._fail("offline", "confirmed")
	app.first_open.return_from_error()
	check(app.screen == "confirmed", "Recuperar error con vínculo real no abre jardín ficticio")
	app.first_open.continue_to_qualities()
	check(app.screen == "confirmed" and not app.first_open.state.pair.get("continued", false), "El flujo real tampoco permite continuar a cualidades demo mediante una llamada directa")
	app.first_open.state.selection.assign(["afe_carino", "sos_respeto", "con_escucha"])
	app.first_open.state.invitation.outgoing_id = "old-invitation"
	app.first_open._fail("auth", "waiting")
	check(app.first_open.state.selection.is_empty() and app.first_open.state.invitation.outgoing_id.is_empty(), "Pérdida de acceso limpia selección y referencia saliente anteriores")
	app.queue_free()
	await process_frame

func _recovery_regressions() -> void:
	var service := RecordingService.new()
	service.base_url = "https://development.example.test"
	service.public_key = "sb_publishable_test"
	root.add_child(service)
	var credentials := {"access_token": "old-access", "refresh_token": "old-refresh", "expires_in": 3600, "user": {"id": "account"}}
	check(service._set_session(credentials), "Preparar sesión para recuperación aislada")
	for invalid: Variant in [null, [], "wrong",
		{"access_token": "replacement", "refresh_token": "refresh", "user": {"id": ""}},
		{"access_token": 123, "refresh_token": "refresh", "user": {"id": "account"}},
		{"access_token": "replacement", "refresh_token": "", "user": {"id": "account"}},
		{"access_token": "replacement", "refresh_token": "refresh", "user": {"id": "account"}, "expires_in": "wrong"},
		{"access_token": "replacement", "refresh_token": "refresh", "user": {"id": "account"}, "expires_in": -1},
	]:
		check(not service._set_session(invalid) and service._access_token == "old-access", "Sesión malformada rechazada sin modificar credenciales vigentes")
	service.responses.append({"ok": true, "data": {"ok": true, "invitation": {"id": "first"}}})
	var result := await invoke(service, "create", {})
	var first_token: String = service._create_token
	var first_operation: String = service._operation_ids.create
	service.responses.append({"ok": true, "data": {"ok": true, "invitation": {"id": "first"}}})
	result = await invoke(service, "status", {})
	check(result.invitation.get("pin") == first_token, "Estado de invitación propia conserva el código correspondiente")
	service.responses.append({"ok": true, "data": {"ok": true, "invitation": {"id": "created-on-another-client"}}})
	result = await invoke(service, "status", {})
	check(not result.invitation.has("pin") and not result.invitation.has("link"), "No asociar un código anterior a una invitación creada desde otro cliente")
	service.responses.append({"ok": false, "error": "offline"})
	result = await invoke(service, "status", {})
	check(service._create_token == first_token and service._operation_ids.create == first_operation, "Fallo de red no descarta la operación idempotente")
	service.responses.append({"ok": true, "data": {"ok": true}})
	result = await invoke(service, "status", {})
	check(service._create_token.is_empty() and not service._operation_ids.has("create"), "Ausencia confirmada por servidor libera creación vencida o cancelada")
	service.responses.append({"ok": true, "data": {"ok": true, "invitation": {"id": "new"}}})
	result = await invoke(service, "create", {})
	check(result.ok and service._create_token != first_token and service._operation_ids.create != first_operation, "Crear después del vencimiento usa una nueva operación y código")
	service.queue_free()
	await process_frame
	var delayed := DelayedLogoutService.new()
	delayed.base_url = "https://development.example.test"
	delayed.public_key = "sb_publishable_test"
	root.add_child(delayed)
	delayed._set_session(credentials)
	delayed.request("logout", {}, 999)
	await process_frame
	delayed.cancel_pending()
	credentials.access_token = "new-access"
	delayed._set_session(credentials)
	delayed.release_logout.emit()
	await process_frame
	check(delayed._access_token == "new-access", "Respuesta de logout cancelado no borra una sesión posterior")
	delayed.queue_free()
	await process_frame
