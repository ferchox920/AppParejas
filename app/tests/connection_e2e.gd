extends SceneTree

var settings: Dictionary

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(75.0).timeout.connect(func() -> void: _check(false, "Tiempo agotado en la prueba bilateral"))
	settings = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	var sol := _client("Sol", settings.emails[0])
	if not settings.has("fresh"):
		if await _reject_otp(sol, settings.expired, "OTP correcto pero vencido"):
			quit(0)
		return

	var luna := _client("Luna", settings.emails[1])
	for test: Array in [
		["", "OTP vacío"],
		["12A456", "OTP con un carácter inválido"],
		["12345", "OTP demasiado corto"],
		[_alter_otp(), "OTP alterado"],
		[settings.other, "OTP válido de la otra cuenta"],
		[settings.expired, "OTP anterior tras generar su reemplazo"],
	]:
		if not await _reject_otp(sol, test[0], test[1]): return
		if not _press(sol, "RetryAccessCode"): return
	if not await _verify(sol, settings.fresh): return
	if not await _verify(luna, settings.other): return
	var sol_flow: FirstOpenFlow = sol.first_open
	var luna_flow: FirstOpenFlow = luna.first_open
	if not _check(sol_flow.state.session.id != luna_flow.state.session.id, "Sesiones de dos cuentas distintas"): return
	var replay := _client("Reintento", settings.emails[0])
	if not await _reject_otp(replay, settings.fresh, "OTP ya consumido desde una sesión nueva"): return
	replay.queue_free()

	if not _press(luna, "ChooseJoin"): return

	var cancelled := await _create_qr(sol)
	if cancelled.is_empty() or not await _cancel(sol): return
	await _scan(luna, cancelled)
	if not _check(luna_flow.error == "invalid_pin" and not luna_flow.state.has_pair(), "QR cancelado rechazado"): return

	var expired := await _create_qr(sol)
	if expired.is_empty(): return
	await _scan(luna, expired)
	if not _check(luna_flow.screen == "review", "La invitación se puede revisar antes de vencer"): return
	if not await _expire_invitation(): return
	if not _press(luna, "AcceptInvitation"): return
	await _settle(luna_flow)
	if not _check(luna_flow.error == "invalid_pin" and not luna_flow.state.has_pair(),
			"Si la invitación vence durante la revisión, no se puede aceptar"): return
	await _scan(luna, expired)
	if not _check(luna_flow.error == "invalid_pin" and not luna_flow.state.has_pair(), "QR vencido rechazado al escanear"): return
	if not await _cancel(sol): return

	var decoded := await _create_qr(sol)
	if decoded.is_empty(): return
	await _scan(sol, decoded)
	if not _check(sol_flow.error == "self_invitation" and not sol_flow.state.has_pair(), "QR propio rechazado"): return
	await _scan(luna, "")
	if not _check(luna_flow.error == "invalid_pin" and not luna_flow.state.has_pair(), "Lectura vacía rechazada"): return
	await _scan(luna, _alter(decoded))
	if not _check(luna_flow.error == "invalid_pin" and not luna_flow.state.has_pair(), "Contenido QR alterado rechazado"): return
	await _scan(luna, decoded)
	if not _check(luna_flow.screen == "review" and luna_flow.invitation_view.get("inviter_name") == "Sol"
			and not luna_flow.state.has_pair(), "El QR correcto abre la revisión de Sol sin aceptar"): return
	if not _press(luna, "AcceptInvitation"): return
	await _settle(luna_flow)
	if not _check(luna_flow.screen == "confirmed" and luna_flow.state.has_pair(), "Luna confirma con aceptación explícita"): return
	# La prueba del QR propio dejó una referencia pendiente en Sol. Volver desde
	# el error la limpia antes de consultar el estado como parte invitante.
	sol_flow.return_from_error()
	sol_flow.navigate("waiting")
	if not _press(sol, "RefreshInvitation"): return
	await _settle(sol_flow)
	if not _check(sol_flow.screen == "confirmed" and sol_flow.state.pair.get("id") == luna_flow.state.pair.id,
			"Sol confirma el mismo vínculo al consultar el estado"): return
	await _scan(luna, decoded)
	if not _check(luna_flow.error == "invalid_pin", "QR ya utilizado rechazado al volver a resolverlo"): return
	quit(0)

func _create_qr(app: Control) -> String:
	if not _press(app, "ChooseInvite"): return ""
	var flow: FirstOpenFlow = app.first_open
	await _settle(flow)
	if not _check(flow.screen == "invite" and not flow.invitation_view.is_empty(), "Sol crea la invitación"): return ""
	var decoded := _decode(app)
	if not _check(not decoded.is_empty() and decoded == flow.invitation_view.link, "ZXing lee el QR generado por la app"): return ""
	return decoded

func _cancel(app: Control) -> bool:
	if not _press(app, "InvitationStatus") or not _press(app, "CancelInvitation"): return false
	var flow: FirstOpenFlow = app.first_open
	await _settle(flow)
	return _check(flow.screen == "connect", "Sol cancela la invitación")

func _expire_invitation() -> bool:
	var request := HTTPRequest.new()
	request.timeout = 5.0
	root.add_child(request)
	var started := request.request(settings.url + "/fixture/expire-invitation", [], HTTPClient.METHOD_POST)
	if not _check(started == OK, "Solicitud para envejecer la invitación", false):
		request.queue_free()
		return false
	var response: Array = await request.request_completed
	request.queue_free()
	return _check(response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 204,
		"El entorno de prueba adelanta el vencimiento de la invitación", false)

func _client(display_name: String, email: String) -> Control:
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.auto_start = false
	var service := SupabaseInvitationService.new()
	service.base_url = settings.url
	service.public_key = "isolated-test"
	# Estado que normalmente deja send_code tras la solicitud de correo.
	service._pending_email = email
	service._pending_name = display_name
	service._pending_consent = true
	app.first_open.service = service
	app.first_open.store = AccountPreferencesStore.new()
	app.first_open.store.path = "user://connection-e2e-%s.json" % display_name
	app.first_open.state.introduction = "skipped"
	root.add_child(app)
	app.first_open.navigate("verify")
	return app

func _reject_otp(app: Control, code: String, label: String) -> bool:
	if not _submit_otp(app, code): return false
	var flow: FirstOpenFlow = app.first_open
	await _settle(flow)
	return _check(flow.screen == "error" and flow.error == "invalid_code" and not flow.state.has_session(),
		"%s rechazado sin iniciar sesión (pantalla=%s, error=%s)" % [label, flow.screen, flow.error])

func _verify(app: Control, code: String) -> bool:
	if not _submit_otp(app, code): return false
	var flow: FirstOpenFlow = app.first_open
	await _settle(flow)
	return _check(flow.screen == "connect" and flow.state.has_session(),
		"OTP vigente inicia sesión y registra el perfil (pantalla=%s, error=%s)" % [flow.screen, flow.error])

func _submit_otp(app: Control, code: String) -> bool:
	var field := app.find_child("AccessCode", true, false) as LineEdit
	if not _check(field != null, "Campo OTP disponible", false): return false
	field.text = code
	return _press(app, "VerifyAccessCode")

func _scan(app: Control, reference: String) -> void:
	var flow: FirstOpenFlow = app.first_open
	flow.navigate("scan")
	# El puente nativo llama al mismo método cuando devuelve el texto leído.
	app.platform._finish_scan({"ok": true, "reference": reference})
	await _settle(flow)

func _decode(app: Control) -> String:
	var qr := app.find_child("InvitationQR", true, false) as TextureRect
	if qr == null: return ""
	var image := qr.texture.get_image()
	var path := str(settings.work).path_join("invitation.png")
	if image == null or image.is_empty() or image.save_png(path) != OK: return ""
	var output: Array = []
	var decoder := ProjectSettings.globalize_path("res://tests/decode_connection_qr.py")
	if OS.execute(settings.decoder, [decoder, path], output) != 0: return ""
	return str(output[0]).strip_edges()

func _settle(flow: FirstOpenFlow) -> void:
	while flow.busy:
		await flow.changed
	await process_frame

func _press(app: Control, name: String) -> bool:
	var button := app.find_child(name, true, false) as Button
	if not _check(button != null and not button.disabled, "Botón disponible: " + name, false): return false
	button.pressed.emit()
	return true

func _alter_otp() -> String:
	var fresh := str(settings.fresh)
	for digit: String in "0123456789":
		var candidate := digit + fresh.substr(1)
		if candidate not in [fresh, settings.other, settings.expired]: return candidate
	return ""

func _alter(value: String) -> String:
	return ("1" if value.begins_with("0") else "0") + value.substr(1)

func _check(condition: bool, label: String, report: bool = true) -> bool:
	if not condition:
		push_error(label)
		quit(1)
	elif report:
		print("OK · " + label)
	return condition
